output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer"
  value       = aws_lb.app.dns_name
}

output "application_url" {
  description = "Public application URL"
  value       = "http://${aws_lb.app.dns_name}"
}

output "s3_bucket_name" {
  description = "S3 bucket name for uploaded photos"
  value       = aws_s3_bucket.photos.bucket
}

output "rds_endpoint" {
  description = "RDS MariaDB endpoint"
  value       = aws_db_instance.mariadb.address
}

output "db_secret_name" {
  description = "Secrets Manager secret name used by the app"
  value       = data.aws_secretsmanager_secret.db_credentials.name
}

output "rds_replica_endpoint" {
  description = "RDS MariaDB read replica endpoint"
  value       = aws_db_instance.mariadb_replica.address
}   