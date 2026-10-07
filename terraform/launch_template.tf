resource "aws_launch_template" "app" {
  name_prefix   = "${var.project_name}-lt-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.app.id]

  iam_instance_profile {
    name = var.iam_instance_profile_name
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    app_port             = var.app_port
    aws_region           = var.aws_region
    s3_bucket_name       = aws_s3_bucket.photos.bucket
    db_primary_host      = aws_db_instance.mariadb.address
    db_replica_host      = aws_db_instance.mariadb_replica.address
    db_name              = var.db_name
    db_secret_id         = data.aws_secretsmanager_secret.db_credentials.name
    gitlab_repo_url_base = var.gitlab_repo_url_base
    gitlab_pat_secret_id = var.gitlab_pat_secret_id
  }))

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.project_name}-app"
    }
  }

  tags = {
    Name = "${var.project_name}-launch-template"
  }
}