# 1. SSM Parameter Store para Hardening de Contraseñas
resource "aws_ssm_parameter" "rcon_password" {
  name        = "/minecraft/rcon_password"
  description = "Contraseña segura de RCON para Minecraft"
  type        = "String"
  value       = var.rcon_password

  tags = {
    Name = "${var.environment}-${var.project_name}-ssm-rcon"
  }
}

# 2. Security Group para NAT Instance y Servidor Minecraft
resource "aws_security_group" "nat_minecraft" {
  name        = "${var.environment}-${var.project_name}-nat-mc-sg"
  description = "Security Group para NAT Instance y Servidor Minecraft"
  vpc_id      = var.vpc_id

  ingress {
    description = "Minecraft TCP"
    from_port   = 25565
    to_port     = 25565
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Minecraft UDP"
    from_port   = 25565
    to_port     = 25565
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "RCON desde Subred Privada"
    from_port   = 25575
    to_port     = 25575
    protocol    = "tcp"
    cidr_blocks = [var.private_subnet_1_cidr]
  }

  ingress {
    description = "Trafico interno de la VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Salida libre a Internet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-${var.project_name}-nat-mc-sg"
  }
}

# 3. Security Group para Backend Flask en Subred Privada
resource "aws_security_group" "backend" {
  name        = "${var.environment}-${var.project_name}-backend-sg"
  description = "Security Group para Backend Flask en Subred Privada"
  vpc_id      = var.vpc_id

  ingress {
    description = "API Flask desde la VPC"
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Salida a Internet via NAT"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-${var.project_name}-backend-sg"
  }
}
