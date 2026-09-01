data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

data "aws_region" "current" {}

# 1. EC2 NAT Instance + Servidor Minecraft (Subred Pública)
resource "aws_instance" "nat_minecraft" {
  ami                  = data.aws_ssm_parameter.al2023_ami.value
  instance_type        = var.instance_type
  subnet_id            = var.public_subnet_id
  iam_instance_profile = var.instance_profile_name
  source_dest_check    = false

  vpc_security_group_ids = [var.nat_minecraft_sg_id]

  user_data = <<-EOF
    #!/bin/bash
    set -e

    # 1. Configurar Swap (2 GB)
    if [ ! -f /swapfile ]; then
      fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048
      chmod 600 /swapfile
      mkswap /swapfile
      swapon /swapfile
      echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi

    # 2. Configurar reenvio IPv4
    echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-nat.conf
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    sysctl -p /etc/sysctl.d/99-nat.conf || sysctl -p

    # 3. Configurar iptables NAT y Firewall
    dnf install -y iptables-services iptables
    systemctl enable iptables
    systemctl start iptables

    PRIMARY_IFACE=$(ip route show default | awk '{print $5}' | head -n1)
    [ -z "$PRIMARY_IFACE" ] && PRIMARY_IFACE=eth0

    iptables -F
    iptables -t nat -F
    iptables -t nat -A POSTROUTING -o "$PRIMARY_IFACE" -j MASQUERADE
    iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    iptables -A FORWARD -j ACCEPT

    iptables -A INPUT -i lo -j ACCEPT
    iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    iptables -A INPUT -p tcp --dport 25565 -j ACCEPT
    iptables -A INPUT -p udp --dport 25565 -j ACCEPT
    iptables -A INPUT -p tcp --dport 25575 -j ACCEPT
    iptables -A INPUT -s 10.0.0.0/16 -j ACCEPT
    iptables-save > /etc/sysconfig/iptables

    # 4. Instalar Java 21, SSM Agent y CloudWatch Agent
    dnf install -y java-21-amazon-corretto-headless jq curl amazon-ssm-agent amazon-cloudwatch-agent tar gzip
    systemctl enable --now amazon-ssm-agent

    # 5. Instalar PurpurMC 1.21.4 y ViaVersion
    mkdir -p /opt/minecraft/plugins
    cd /opt/minecraft

    curl -s -L -A "Mozilla/5.0" -o /opt/minecraft/server.jar "https://api.purpurmc.org/v2/purpur/1.21.4/latest/download"
    curl -s -L -A "Mozilla/5.0" -o /opt/minecraft/plugins/ViaVersion.jar "https://github.com/ViaVersion/ViaVersion/releases/download/5.11.0/ViaVersion-5.11.0.jar"

    echo "eula=true" > /opt/minecraft/eula.txt

    cat << 'EOF_PROP' > /opt/minecraft/server.properties
    server-port=25565
    motd=\u00a7bDuoc UC Cloud Native \u00a7aMinecraft Enterprise
    max-players=10
    view-distance=6
    simulation-distance=4
    online-mode=false
    enable-command-block=true
    spawn-protection=0
    enable-rcon=true
    rcon.port=25575
    rcon.password=${var.rcon_password}
    broadcast-rcon-to-ops=false
    EOF_PROP

    # 6. Servicio Systemd Minecraft
    cat << 'EOF_SVC' > /etc/systemd/system/minecraft.service
    [Unit]
    Description=Minecraft Server Purpur 1.21.4
    After=network.target

    [Service]
    Type=simple
    User=root
    WorkingDirectory=/opt/minecraft
    ExecStart=/usr/bin/java -Xms512M -Xmx850M -XX:+UseG1GC -jar /opt/minecraft/server.jar nogui
    Restart=always
    RestartSec=5

    [Install]
    WantedBy=multi-user.target
    EOF_SVC

    systemctl daemon-reload
    systemctl enable --now minecraft

    # 7. Respaldo automatizado a S3 versionado
    cat << 'EOF_BACKUP' > /opt/minecraft/backup-to-s3.sh
    #!/bin/bash
    BACKUP_NAME="world_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    cd /opt/minecraft
    if [ -d "world" ]; then
      tar -czf "/tmp/$BACKUP_NAME" world world_nether world_the_end 2>/dev/null || tar -czf "/tmp/$BACKUP_NAME" world
      aws s3 cp "/tmp/$BACKUP_NAME" "s3://${var.backups_bucket_name}/$BACKUP_NAME" --region ${data.aws_region.current.name} || true
      rm -f "/tmp/$BACKUP_NAME"
    fi
    EOF_BACKUP
    chmod +x /opt/minecraft/backup-to-s3.sh
    echo "0 */6 * * * root /opt/minecraft/backup-to-s3.sh >/dev/null 2>&1" > /etc/cron.d/minecraft-backup
  EOF

  tags = {
    Name = "${var.environment}-${var.project_name}-nat-minecraft"
    Role = "NAT-and-GameServer"
  }
}

# 2. Ruta 0.0.0.0/0 en Tabla Privada -> NAT Instance
resource "aws_route" "private_nat" {
  route_table_id         = var.private_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.nat_minecraft.primary_network_interface_id
}

# 3. EC2 Backend Flask con Docker y DynamoDB (Subred Privada 1)
resource "aws_instance" "backend" {
  ami                  = data.aws_ssm_parameter.al2023_ami.value
  instance_type        = var.instance_type
  subnet_id            = var.private_subnet_1_id
  iam_instance_profile = var.instance_profile_name

  vpc_security_group_ids = [var.backend_sg_id]
  depends_on             = [aws_route.private_nat]

  user_data = <<-EOF
    #!/bin/bash
    set -e

    # 1. Swap 1GB
    if [ ! -f /swapfile ]; then
      fallocate -l 1G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=1024
      chmod 600 /swapfile
      mkswap /swapfile
      swapon /swapfile
      echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi

    # 2. Instalar dependencias y Docker
    dnf update -y
    dnf install -y python3 python3-pip amazon-ssm-agent sqlite docker
    systemctl enable --now amazon-ssm-agent
    systemctl enable --now docker

    pip3 install flask flask-cors mcrcon requests boto3 PyJWT gunicorn

    # 3. Desplegar aplicacion Flask
    mkdir -p /opt/backend
    cat << 'EOF_PY' > /opt/backend/app.py
    from flask import Flask, jsonify, request
    from flask_cors import CORS
    from functools import wraps
    import sqlite3
    import datetime
    import os
    try:
        import jwt
    except ImportError:
        jwt = None
    try:
        import boto3
    except ImportError:
        boto3 = None
    try:
        from mcrcon import MCRcon
    except ImportError:
        MCRcon = None

    app = Flask(__name__)
    CORS(app)

    JWT_SECRET = "DuocCloudNativeSecretKey2026!"
    ADMIN_USER = "admin"
    ADMIN_PASS = "DuocAdmin2026!"
    AWS_REGION = "${data.aws_region.current.name}"
    DYNAMODB_TABLE = "UsuariosMinecraft"
    MINECRAFT_HOST = "${aws_instance.nat_minecraft.private_ip}"
    RCON_PORT = 25575
    RCON_PASSWORD = "${var.rcon_password}"

    USE_DYNAMODB = False
    dynamo_table = None

    if boto3:
        try:
            dynamodb = boto3.resource("dynamodb", region_name=AWS_REGION)
            dynamo_table = dynamodb.Table(DYNAMODB_TABLE)
            dynamo_table.load()
            USE_DYNAMODB = True
        except Exception:
            USE_DYNAMODB = False

    def execute_rcon(command):
        if not MCRcon:
            return "MCRcon no disponible"
        try:
            with MCRcon(MINECRAFT_HOST, RCON_PASSWORD, port=RCON_PORT, timeout=5) as mcr:
                return mcr.command(command)
        except Exception as e:
            return f"Error RCON: {str(e)}"

    def admin_required(f):
        @wraps(f)
        def decorated(*args, **kwargs):
            auth_header = request.headers.get("Authorization")
            if not auth_header:
                return jsonify({"error": "Token requerido"}), 401
            try:
                token = auth_header.split(" ")[1] if " " in auth_header else auth_header
                if jwt:
                    jwt.decode(token, JWT_SECRET, algorithms=["HS256"])
            except Exception:
                return jsonify({"error": "Token invalido"}), 401
            return f(*args, **kwargs)
        return decorated

    @app.route("/api/auth/login", methods=["POST"])
    def login():
        data = request.get_json() or {}
        if data.get("username") == ADMIN_USER and data.get("password") == ADMIN_PASS:
            token = jwt.encode({"user": ADMIN_USER, "exp": datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(hours=8)}, JWT_SECRET, algorithm="HS256") if jwt else "demo-token"
            return jsonify({"mensaje": "OK", "token": token, "user": ADMIN_USER})
        return jsonify({"error": "Credenciales invalidas"}), 401

    @app.route("/api/saludo", methods=["GET"])
    def saludo():
        return jsonify({"mensaje": "Backend Enterprise", "persistencia": "DynamoDB" if USE_DYNAMODB else "SQLite", "host": MINECRAFT_HOST})

    @app.route("/api/usuarios", methods=["GET"])
    def get_usuarios():
        if USE_DYNAMODB and dynamo_table:
            try:
                return jsonify(dynamo_table.scan().get("Items", []))
            except Exception:
                pass
        return jsonify([])

    @app.route("/api/usuarios", methods=["POST"])
    def create_usuario():
        data = request.get_json() or {}
        nombre = data.get("nombre", "").strip()
        email = data.get("email", "").strip()
        gamertag = data.get("gamertag", "").strip() or nombre

        if not nombre or not email:
            return jsonify({"error": "Requerido nombre y email"}), 400

        item = {"email": email, "id": int(datetime.datetime.now().timestamp()), "nombre": nombre, "gamertag": gamertag, "fecha_registro": datetime.datetime.now(datetime.timezone.utc).isoformat()}
        if USE_DYNAMODB and dynamo_table:
            dynamo_table.put_item(Item=item)

        rcon_res = execute_rcon(f"whitelist add {gamertag}")
        return jsonify({"usuario": item, "minecraft_whitelist": rcon_res, "storage": "DynamoDB"}), 201

    @app.route("/api/minecraft/status", methods=["GET"])
    def mc_status():
        return jsonify({"minecraft_ip": "${aws_instance.nat_minecraft.private_ip}", "jugadores": execute_rcon("list"), "tps": execute_rcon("tps"), "status": "Online"})

    @app.route("/api/minecraft/command", methods=["POST"])
    @admin_required
    def mc_cmd():
        cmd = (request.get_json() or {}).get("comando", "")
        if cmd.startswith("/"): cmd = cmd[1:]
        return jsonify({"comando": f"/{cmd}", "salida": execute_rcon(cmd), "timestamp": datetime.datetime.now().strftime("%H:%M:%S")})

    @app.route("/api/minecraft/quick-command/<accion>", methods=["POST"])
    @admin_required
    def mc_quick(accion):
        accs = {"day":"time set day","night":"time set night","sun":"weather clear","rain":"weather rain","creative":"gamemode creative @a","survival":"gamemode survival @a","tps":"tps","whitelist-list":"whitelist list","save":"save-all"}
        cmd = accs.get(accion.lower(), "list")
        return jsonify({"accion": accion, "salida": execute_rcon(cmd), "timestamp": datetime.datetime.now().strftime("%H:%M:%S")})

    if __name__ == "__main__":
        app.run(host="0.0.0.0", port=8081)
    EOF_PY

    # 4. Servicio Systemd
    cat << 'EOF_BACKEND_SVC' > /etc/systemd/system/flask-backend.service
    [Unit]
    Description=Flask Backend API Enterprise
    After=network.target

    [Service]
    Type=simple
    User=root
    WorkingDirectory=/opt/backend
    ExecStart=/usr/bin/python3 /opt/backend/app.py
    Restart=always
    RestartSec=5

    [Install]
    WantedBy=multi-user.target
    EOF_BACKEND_SVC

    systemctl daemon-reload
    systemctl enable --now flask-backend
  EOF

  tags = {
    Name = "${var.environment}-${var.project_name}-backend-private"
    Role = "BackendAPI"
  }
}

# 4. CloudWatch Metric Alarm: CPU / Memoria
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.environment}-${var.project_name}-minecraft-high-cpu"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 90
  alarm_description   = "Alarma de alto consumo de CPU en el Servidor de Minecraft"

  dimensions = {
    InstanceId = aws_instance.nat_minecraft.id
  }
}
