variable "environment" {
  type        = string
  description = "Nombre del entorno"
}

variable "project_name" {
  type        = string
  description = "Nombre del proyecto"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR de la VPC"
}

variable "public_subnet_cidr" {
  type        = string
  description = "CIDR de la Subred Pública"
}

variable "private_subnet_1_cidr" {
  type        = string
  description = "CIDR de la Subred Privada 1 (Backend)"
}

variable "private_subnet_2_cidr" {
  type        = string
  description = "CIDR de la Subred Privada 2 (DB)"
}
