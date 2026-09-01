output "vpc_id" {
  description = "ID de la VPC creada"
  value       = module.networking.vpc_id
}

output "public_subnet_id" {
  description = "ID de la Subred Pública"
  value       = module.networking.public_subnet_id
}

output "private_subnet_1_id" {
  description = "ID de la Subred Privada 1 (Backend)"
  value       = module.networking.private_subnet_1_id
}

output "dynamodb_table_name" {
  description = "Nombre de la Tabla DynamoDB para Jugadores"
  value       = module.storage.dynamodb_table_name
}

output "frontend_website_endpoint" {
  description = "URL del Sitio Web del Frontend en Amazon S3"
  value       = module.storage.frontend_website_endpoint
}

output "backups_bucket_name" {
  description = "Nombre del Bucket S3 versionado para respaldos"
  value       = module.storage.backups_bucket_name
}

output "minecraft_instance_id" {
  description = "ID de la Instancia NAT / Servidor Minecraft"
  value       = module.compute.nat_minecraft_instance_id
}

output "minecraft_public_ip" {
  description = "IP Pública para conectarse al Servidor Minecraft"
  value       = module.compute.nat_minecraft_public_ip
}

output "backend_instance_id" {
  description = "ID de la Instancia Backend en Subred Privada"
  value       = module.compute.backend_instance_id
}

output "backend_private_ip" {
  description = "IP Privada del Backend Flask"
  value       = module.compute.backend_private_ip
}

output "ssm_connect_minecraft" {
  description = "Comando SSM para conectarse al Servidor Minecraft"
  value       = "aws ssm start-session --target ${module.compute.nat_minecraft_instance_id}"
}

output "ssm_connect_backend" {
  description = "Comando SSM para conectarse al Backend Privado"
  value       = "aws ssm start-session --target ${module.compute.backend_instance_id}"
}
