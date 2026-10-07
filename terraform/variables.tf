variable "aws_region" {
  description = "AWS region used in the Learner Lab"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix for all AWS resources"
  type        = string
  default     = "photo-album"
}

variable "instance_type" {
  description = "EC2 instance type for app instances"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "EC2 key pair name"
  type        = string
  default     = "vockey"
}

variable "iam_instance_profile_name" {
  description = "IAM Instance Profile for EC2 app instances"
  type        = string
  default     = "LabInstanceProfile"
}

variable "app_port" {
  description = "Port where the Flask app listens"
  type        = number
  default     = 8000
}

variable "health_check_path" {
  description = "Health check path for the target group"
  type        = string
  default     = "/health"
}

variable "db_identifier" {
  description = "RDS DB instance identifier"
  type        = string
  default     = "dbinstance-1"
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "photoalbum"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_secret_name" {
  description = "Existing Secrets Manager secret name for DB credentials"
  type        = string
  default     = "dbphotoalb-pwd"
}

variable "gitlab_repo_url_base" {
  description = "GitLab repository URL without https://"
  type        = string
  default     = "gitlab.rz.htw-berlin.de/s0588307/iiw_cpc_flask_photo_album.git"
}

variable "gitlab_pat_secret_id" {
  description = "Existing Secrets Manager secret id containing GitLab PAT"
  type        = string
  default     = "gitlab-pat"
}

variable "db_replica_identifier" {
  description = "RDS read replica identifier"
  type        = string
  default     = "dbinstance-1-replica"
}

variable "pillow_layer_arn" {
  description = "Pillow Lambda Layer ARN for Python 3.12 in us-east-1"
  type        = string
  default     = "arn:aws:lambda:us-east-1:770693421928:layer:Klayers-p312-Pillow:11"
}

variable "mysql_connector_layer_arn" {
  description = "mysql-connector-python Lambda Layer ARN for Python 3.12 in us-east-1"
  type        = string
  default     = "arn:aws:lambda:us-east-1:770693421928:layer:Klayers-p312-mysql-connector-python:11"
}

variable "thumbnail_max_size" {
  description = "Maximum thumbnail width/height in pixels"
  type        = number
  default     = 100
}

variable "extra_subnet_cidr_block" {
  description = "CIDR block for the additional subnet in another AZ"
  type        = string
  default     = "172.31.96.0/20"
}