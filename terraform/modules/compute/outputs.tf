output "nat_minecraft_instance_id" {
  description = "ID de la Instancia NAT y Servidor Minecraft"
  value       = aws_instance.nat_minecraft.id
}

output "nat_minecraft_public_ip" {
  description = "IP Pública para conectarse al Servidor Minecraft"
  value       = aws_instance.nat_minecraft.public_ip
}

output "nat_minecraft_private_ip" {
  description = "IP Privada de la NAT y Servidor Minecraft"
  value       = aws_instance.nat_minecraft.private_ip
}

output "backend_instance_id" {
  description = "ID de la Instancia Backend en Subred Privada"
  value       = aws_instance.backend.id
}

output "backend_private_ip" {
  description = "IP Privada del Backend Flask (SQLite persistente)"
  value       = aws_instance.backend.private_ip
}
