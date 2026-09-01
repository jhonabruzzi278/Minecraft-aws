output "nat_minecraft_sg_id" {
  description = "ID del Security Group de NAT y Minecraft"
  value       = aws_security_group.nat_minecraft.id
}

output "backend_sg_id" {
  description = "ID del Security Group del Backend Flask Privado"
  value       = aws_security_group.backend.id
}
