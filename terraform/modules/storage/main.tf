# 1. Tabla NoSQL DynamoDB para Jugadores
resource "aws_dynamodb_table" "usuarios" {
  name         = "UsuariosMinecraft"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "email"

  attribute {
    name = "email"
    type = "S"
  }

  tags = {
    Name = "${var.environment}-${var.project_name}-dynamodb-usuarios"
  }
}

# 2. Bucket S3 para Hosting del Frontend
resource "aws_s3_bucket" "frontend" {
  bucket_prefix = "${var.environment}-${var.project_name}-frontend-"
  force_destroy = true

  tags = {
    Name = "${var.environment}-${var.project_name}-frontend-website"
  }
}

resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

# 3. Bucket S3 Versionado para Respaldos del Mundo de Minecraft
resource "aws_s3_bucket" "backups" {
  bucket_prefix = "${var.environment}-${var.project_name}-mc-backups-"
  force_destroy = true

  tags = {
    Name = "${var.environment}-${var.project_name}-minecraft-backups"
  }
}

resource "aws_s3_bucket_versioning" "backups" {
  bucket = aws_s3_bucket.backups.id
  versioning_configuration {
    status = "Enabled"
  }
}
