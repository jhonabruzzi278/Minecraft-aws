output "dynamodb_table_name" {
  description = "Nombre de la tabla DynamoDB"
  value       = aws_dynamodb_table.usuarios.name
}

output "frontend_bucket_name" {
  description = "Nombre del bucket S3 del frontend"
  value       = aws_s3_bucket.frontend.id
}

output "frontend_website_endpoint" {
  description = "URL del sitio web del Frontend en S3"
  value       = aws_s3_bucket_website_configuration.frontend.website_endpoint
}

output "backups_bucket_name" {
  description = "Nombre del bucket S3 versionado para respaldos"
  value       = aws_s3_bucket.backups.id
}
