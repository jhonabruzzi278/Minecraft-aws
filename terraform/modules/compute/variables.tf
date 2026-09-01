variable "environment" {
  type        = string
  description = "Nombre del entorno"
}

variable "project_name" {
  type        = string
  description = "Nombre del proyecto"
}

variable "instance_type" {
  type        = string
  description = "Tipo de instancia EC2"
}

variable "instance_profile_name" {
  type        = string
  description = "IAM Instance Profile de AWS Academy"
}

variable "public_subnet_id" {
  type        = string
  description = "ID de la Subred Pública"
}

variable "private_subnet_1_id" {
  type        = string
  description = "ID de la Subred Privada 1"
}

variable "nat_minecraft_sg_id" {
  type        = string
  description = "Security Group ID para NAT y Minecraft"
}

variable "backend_sg_id" {
  type        = string
  description = "Security Group ID para Backend Flask"
}

variable "private_route_table_id" {
  type        = string
  description = "ID de la Tabla de Rutas Privada para inyectar la ruta 0.0.0.0/0"
}

variable "rcon_password" {
  type        = string
  sensitive   = true
  description = "Contraseña segura de RCON para comunicar el Backend con Minecraft"
}

variable "backups_bucket_name" {
  type        = string
  default     = ""
  description = "Nombre del Bucket S3 versionado para respaldos automáticos"
}
