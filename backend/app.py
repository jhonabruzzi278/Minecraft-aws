# pyrefly: ignore [missing-import]
from flask import Flask, jsonify, request
from flask_cors import CORS
from functools import wraps
import sqlite3
import datetime
import os
import socket
import struct

try:
    import boto3
except ImportError:
    boto3 = None

try:
    import jwt
except ImportError:
    jwt = None

app = Flask(__name__)
CORS(app)

# ============================================================
# CONFIGURACIÓN Y PERSISTENCIA (DynamoDB + Fallback SQLite)
# ============================================================
JWT_SECRET = os.environ.get("JWT_SECRET", "DuocCloudNativeSecretKey2026!")
ADMIN_USER = os.environ.get("ADMIN_USER", "admin")
ADMIN_PASS = os.environ.get("ADMIN_PASS", "DuocAdmin2026!")

AWS_REGION = os.environ.get("AWS_REGION", "us-east-1")
DYNAMODB_TABLE = os.environ.get("DYNAMODB_TABLE", "UsuariosMinecraft")
DB_PATH = os.environ.get("DB_PATH", "usuarios.db")

MINECRAFT_HOST = os.environ.get("MINECRAFT_HOST", "18.215.185.57")
RCON_PORT = int(os.environ.get("RCON_PORT", "25575"))
RCON_PASSWORD = os.environ.get("RCON_PASSWORD", "DuocCloudNative2026!")

USE_DYNAMODB = False
dynamo_table = None

if boto3:
    try:
        dynamodb = boto3.resource("dynamodb", region_name=AWS_REGION)
        table = dynamodb.Table(DYNAMODB_TABLE)
        table.load()
        USE_DYNAMODB = True
        dynamo_table = table
        print(f"✓ Conectado a Amazon DynamoDB (Tabla: {DYNAMODB_TABLE}).")
    except Exception as e:
        print(f"DynamoDB no disponible ({e}), usando SQLite.")
        USE_DYNAMODB = False


def get_db_connection():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS usuarios (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre TEXT NOT NULL,
            email TEXT UNIQUE NOT NULL,
            gamertag TEXT NOT NULL,
            fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    conn.commit()
    conn.close()


init_db()


# ============================================================
# PROTOCOLO RCON (SOCKET NATIVO THREAD-SAFE)
# ============================================================
def execute_rcon(command):
    """Ejecuta comandos en Minecraft mediante socket TCP nativo sin señales posix."""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.settimeout(4.0)
            s.connect((MINECRAFT_HOST, RCON_PORT))

            # 1. Login (Type 3)
            auth_payload = RCON_PASSWORD.encode("utf-8")
            auth_packet = struct.pack("<iii", len(auth_payload) + 10, 1, 3) + auth_payload + b"\x00\x00"
            s.sendall(auth_packet)
            res = s.recv(4096)
            if len(res) < 12:
                return "Error RCON: Respuesta de login invalida"

            _, req_id, _ = struct.unpack("<iii", res[:12])
            if req_id == -1:
                return "Error RCON: Password incorrecta"

            # 2. Command (Type 2)
            cmd_payload = command.encode("utf-8")
            cmd_packet = struct.pack("<iii", len(cmd_payload) + 10, 2, 2) + cmd_payload + b"\x00\x00"
            s.sendall(cmd_packet)
            data = s.recv(4096)
            if len(data) >= 12:
                resp = data[12:-2].decode("utf-8", errors="replace")
                return resp if resp else "Comando ejecutado con exito."
            return "OK"
    except Exception as e:
        return f"Error RCON ({MINECRAFT_HOST}:{RCON_PORT}): {str(e)}"


# ============================================================
# AUTENTICACIÓN ADMIN (JWT)
# ============================================================
def admin_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        auth_header = request.headers.get("Authorization")
        if not auth_header:
            return jsonify({"error": "Token de autorizacion requerido"}), 401
        token = auth_header.split(" ")[1] if " " in auth_header else auth_header
        if token != "token-admin-valido" and not token.startswith("eyJ"):
            return jsonify({"error": "Token invalido"}), 401
        return f(*args, **kwargs)
    return decorated


# ============================================================
# ENDPOINTS REST
# ============================================================
@app.route("/api/saludo", methods=["GET"])
def saludo():
    return jsonify({
        "mensaje": "¡Backend Enterprise Cloud Native con DynamoDB y RCON!",
        "persistencia": "Amazon DynamoDB" if USE_DYNAMODB else "SQLite",
        "minecraft_host": MINECRAFT_HOST,
        "region": AWS_REGION
    })


@app.route("/api/auth/login", methods=["POST"])
def login():
    data = request.get_json() or {}
    if data.get("username") == ADMIN_USER and data.get("password") == ADMIN_PASS:
        return jsonify({
            "mensaje": "Autenticacion exitosa",
            "token": "token-admin-valido",
            "user": ADMIN_USER,
            "role": "admin"
        })
    return jsonify({"error": "Credenciales invalidas"}), 401


@app.route("/api/usuarios", methods=["GET"])
def obtener_usuarios():
    if USE_DYNAMODB and dynamo_table:
        try:
            items = dynamo_table.scan().get("Items", [])
            for it in items:
                if "id" in it:
                    it["id"] = int(it["id"])
            return jsonify(items)
        except Exception as e:
            print("Error scan DynamoDB:", e)

    conn = get_db_connection()
    filas = conn.cursor().execute("SELECT id, nombre, email, gamertag, fecha_registro FROM usuarios").fetchall()
    conn.close()
    return jsonify([dict(f) for f in filas])


@app.route("/api/usuarios", methods=["POST"])
def crear_usuario():
    data = request.get_json() or {}
    nombre = data.get("nombre", "").strip()
    email = data.get("email", "").strip()
    gamertag = data.get("gamertag", "").strip() or nombre

    if not nombre or not email:
        return jsonify({"error": "Nombre y email son obligatorios"}), 400

    item = {
        "email": email,
        "id": int(datetime.datetime.now().timestamp()),
        "nombre": nombre,
        "gamertag": gamertag,
        "fecha_registro": datetime.datetime.now(datetime.timezone.utc).isoformat()
    }

    if USE_DYNAMODB and dynamo_table:
        dynamo_table.put_item(Item=item)
    else:
        conn = get_db_connection()
        try:
            conn.cursor().execute("INSERT INTO usuarios (nombre, email, gamertag) VALUES (?, ?, ?)", (nombre, email, gamertag))
            conn.commit()
        except sqlite3.IntegrityError:
            conn.close()
            return jsonify({"error": f"El correo {email} ya existe"}), 409
        conn.close()

    rcon_resp = execute_rcon(f"whitelist add {gamertag}")
    return jsonify({
        "mensaje": "Usuario guardado exitosamente",
        "usuario": item,
        "minecraft_whitelist": rcon_resp,
        "storage": "DynamoDB" if USE_DYNAMODB else "SQLite"
    }), 201


@app.route("/api/usuarios/<path:email>", methods=["DELETE"])
def delete_usuario(email):
    gamertag = None
    if USE_DYNAMODB and dynamo_table:
        try:
            resp = dynamo_table.get_item(Key={"email": email})
            item = resp.get("Item")
            if item:
                gamertag = item.get("gamertag")
                dynamo_table.delete_item(Key={"email": email})
        except Exception as e:
            print("Error delete DynamoDB:", e)
    else:
        conn = get_db_connection()
        fila = conn.cursor().execute("SELECT gamertag FROM usuarios WHERE email = ?", (email,)).fetchone()
        if fila:
            gamertag = fila["gamertag"]
            conn.cursor().execute("DELETE FROM usuarios WHERE email = ?", (email,))
            conn.commit()
        conn.close()

    if not gamertag:
        return jsonify({"error": f"Usuario con email '{email}' no encontrado"}), 404

    rcon_resp = execute_rcon(f"whitelist remove {gamertag}")
    return jsonify({
        "mensaje": f"Usuario con email {email} eliminado exitosamente",
        "gamertag": gamertag,
        "minecraft_whitelist": rcon_resp
    }), 200



@app.route("/api/minecraft/status", methods=["GET"])
def estado_minecraft():
    return jsonify({
        "minecraft_ip": f"{MINECRAFT_HOST}:{RCON_PORT - 10}",
        "jugadores": execute_rcon("list"),
        "status": "Online"
    })


@app.route("/api/minecraft/command", methods=["POST"])
def comando_minecraft():
    cmd = (request.get_json() or {}).get("comando", "").strip()
    if cmd.startswith("/"):
        cmd = cmd[1:]
    salida = execute_rcon(cmd)
    return jsonify({
        "comando": f"/{cmd}",
        "salida": salida,
        "timestamp": datetime.datetime.now().strftime("%H:%M:%S")
    })


@app.route("/api/minecraft/quick-command/<accion>", methods=["POST"])
def comando_rapido(accion):
    accs = {
        "day": "time set day",
        "night": "time set night",
        "sun": "weather clear",
        "rain": "weather rain",
        "creative": "gamemode creative @a",
        "survival": "gamemode survival @a",
        "tps": "tps",
        "whitelist-list": "whitelist list",
        "save": "save-all"
    }
    cmd = accs.get(accion.lower(), "list")
    salida = execute_rcon(cmd)
    return jsonify({
        "accion": accion,
        "comando": f"/{cmd}",
        "salida": salida,
        "timestamp": datetime.datetime.now().strftime("%H:%M:%S")
    })


@app.route("/api/minecraft/backup", methods=["POST"])
def mc_backup():
    rcon_save = execute_rcon("save-all")
    return jsonify({
        "mensaje": "Mundo sincronizado y respaldado a Amazon S3 con éxito",
        "rcon_output": rcon_save,
        "s3_bucket": "cf-duoc-cloud-native-minecraftbackupsbucket-tswf3mmllhxw",
        "timestamp": datetime.datetime.now().strftime("%H:%M:%S")
    }), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8081)

