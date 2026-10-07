locals {
  thumbnail_lambda_zip = "${path.module}/thumbnail_lambda.zip"
}

data "archive_file" "thumbnail_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/thumbnail_handler.py"
  output_path = local.thumbnail_lambda_zip
}

resource "aws_vpc_endpoint" "s3_gateway" {
  vpc_id            = data.aws_vpc.default.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = data.aws_route_tables.default.ids

  tags = {
    Name = "${var.project_name}-s3-gateway-endpoint"
  }
}

resource "aws_lambda_function" "thumbnail_generator" {
  function_name = "${var.project_name}-thumbnail-generator"

  role    = data.aws_iam_role.lab_role.arn
  runtime = "python3.12"
  handler = "thumbnail_handler.lambda_handler"

  filename         = data.archive_file.thumbnail_lambda.output_path
  source_code_hash = data.archive_file.thumbnail_lambda.output_base64sha256

  timeout     = 60
  memory_size = 512

  layers = [
    var.pillow_layer_arn,
    var.mysql_connector_layer_arn,
  ]

  vpc_config {
    subnet_ids         = local.selected_subnet_ids
    security_group_ids = [aws_security_group.lambda_thumbnail.id]
  }

  environment {
    variables = {
      S3_BUCKET_NAME     = aws_s3_bucket.photos.bucket
      DB_HOST            = aws_db_instance.mariadb.address
      DB_PORT            = "3306"
      DB_NAME            = var.db_name
      DB_USERNAME        = local.db_credentials.username
      DB_PASSWORD        = local.db_credentials.password
      ORIGINAL_PREFIX    = "photos/original/"
      THUMBNAIL_PREFIX   = "photos/small/"
      THUMBNAIL_MAX_SIZE = tostring(var.thumbnail_max_size)
    }
  }

  depends_on = [
    aws_db_instance.mariadb,
    aws_vpc_endpoint.s3_gateway,
  ]

  tags = {
    Name = "${var.project_name}-thumbnail-generator"
  }
}

resource "aws_lambda_permission" "allow_s3_invoke_thumbnail_generator" {
  statement_id   = "AllowS3InvokeThumbnailGenerator"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.thumbnail_generator.function_name
  principal      = "s3.amazonaws.com"
  source_arn     = aws_s3_bucket.photos.arn
  source_account = data.aws_caller_identity.current.account_id
}

resource "aws_s3_bucket_notification" "photo_upload_notification" {
  bucket = aws_s3_bucket.photos.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.thumbnail_generator.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "photos/original/"
    filter_suffix       = ".jpg"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.thumbnail_generator.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "photos/original/"
    filter_suffix       = ".jpeg"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.thumbnail_generator.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "photos/original/"
    filter_suffix       = ".png"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.thumbnail_generator.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "photos/original/"
    filter_suffix       = ".webp"
  }

  depends_on = [
    aws_lambda_permission.allow_s3_invoke_thumbnail_generator,
  ]
}