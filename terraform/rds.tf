resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = local.selected_subnet_ids

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

resource "aws_db_instance" "mariadb" {
  identifier = var.db_identifier

  engine         = "mariadb"
  instance_class = var.db_instance_class

  allocated_storage = 20
  storage_type      = "gp2"

  db_name  = var.db_name
  username = local.db_credentials.username
  password = local.db_credentials.password

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

  backup_retention_period = 1
  publicly_accessible     = false

  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name = "${var.project_name}-mariadb-primary"
  }
}

resource "aws_db_instance" "mariadb_replica" {
  identifier = "${var.db_identifier}-replica"

  replicate_source_db = aws_db_instance.mariadb.identifier

  instance_class = var.db_instance_class

  publicly_accessible = false

  vpc_security_group_ids = [aws_security_group.rds.id]

  backup_retention_period = 0

  skip_final_snapshot = true
  deletion_protection = false

  depends_on = [
    aws_db_instance.mariadb
  ]

  tags = {
    Name = "${var.project_name}-mariadb-replica"
  }
}