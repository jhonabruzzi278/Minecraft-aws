variable "environment" {
  type        = string
  description = "Nombre del entorno"
}

variable "project_name" {
  type        = string
  description = "Nombre del proyecto"
}

variable "vpc_id" {
  type        = string
  description = "ID de la VPC"
}

variable "vpc_cidr" {
  type        = string
  description = "Bloque CIDR de la VPC"
}

variable "private_subnet_1_cidr" {
  type        = string
  description = "Bloque CIDR de la Subred Privada 1 (para RCON)"
}

variable "rcon_password" {
  type        = string
  sensitive   = true
  description = "Contraseña segura de RCON"
}
