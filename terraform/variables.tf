variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "Región de AWS donde se desplegará la infraestructura"
}

variable "environment" {
  type        = string
  default     = "lab"
  description = "Nombre del entorno (lab, dev, staging, prod)"
  validation {
    condition     = contains(["lab", "dev", "staging", "prod"], var.environment)
    error_message = "El entorno debe ser uno de los siguientes: lab, dev, staging, prod."
  }
}

variable "project_name" {
  type        = string
  default     = "cloud-native-duoc"
  description = "Nombre del proyecto para prefijos de recursos y tags"
}

variable "owner_name" {
  type        = string
  default     = "Jonathan"
  description = "Nombre del alumno / propietario"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "Bloque CIDR de la VPC principal"
  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "El valor de vpc_cidr debe ser un bloque CIDR válido (ej: 10.0.0.0/16)."
  }
}

variable "public_subnet_cidr" {
  type        = string
  default     = "10.0.1.0/24"
  description = "Bloque CIDR de la Subred Pública"
  validation {
    condition     = can(cidrnetmask(var.public_subnet_cidr))
    error_message = "El valor de public_subnet_cidr debe ser un bloque CIDR válido."
  }
}

variable "private_subnet_1_cidr" {
  type        = string
  default     = "10.0.2.0/24"
  description = "Bloque CIDR de la Subred Privada 1 (Backend Flask)"
  validation {
    condition     = can(cidrnetmask(var.private_subnet_1_cidr))
    error_message = "El valor de private_subnet_1_cidr debe ser un bloque CIDR válido."
  }
}

variable "private_subnet_2_cidr" {
  type        = string
  default     = "10.0.3.0/24"
  description = "Bloque CIDR de la Subred Privada 2 (Base de Datos)"
  validation {
    condition     = can(cidrnetmask(var.private_subnet_2_cidr))
    error_message = "El valor de private_subnet_2_cidr debe ser un bloque CIDR válido."
  }
}

variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "Tipo de instancia EC2"
  validation {
    condition     = contains(["t3.nano", "t3.micro", "t3.small", "t2.micro"], var.instance_type)
    error_message = "El tipo de instancia debe ser t3.nano, t3.micro, t3.small o t2.micro."
  }
}

variable "instance_profile_name" {
  type        = string
  default     = "LabInstanceProfile"
  description = "IAM Instance Profile preexistente de AWS Academy Learner Lab"
}

variable "rcon_password" {
  type        = string
  default     = "DuocCloudNative2026!"
  sensitive   = true
  description = "Contraseña segura de RCON para comunicar el Backend con Minecraft"
  validation {
    condition     = length(var.rcon_password) >= 8
    error_message = "La contraseña de RCON debe tener al menos 8 caracteres."
  }
}
