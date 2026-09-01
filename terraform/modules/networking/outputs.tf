output "vpc_id" {
  description = "ID de la VPC creada"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "ID de la Subred Pública"
  value       = aws_subnet.public.id
}

output "private_subnet_1_id" {
  description = "ID de la Subred Privada 1"
  value       = aws_subnet.private_1.id
}

output "private_subnet_2_id" {
  description = "ID de la Subred Privada 2"
  value       = aws_subnet.private_2.id
}

output "public_route_table_id" {
  description = "ID de la Tabla de Rutas Pública"
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "ID de la Tabla de Rutas Privada"
  value       = aws_route_table.private.id
}
