data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_subnet" "existing_default" {
  id = data.aws_subnets.default.ids[0]
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  second_az = [
    for az in data.aws_availability_zones.available.names :
    az
    if az != data.aws_subnet.existing_default.availability_zone
  ][0]

  selected_subnet_ids = [
    data.aws_subnet.existing_default.id,
    aws_subnet.extra.id,
  ]
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

data "aws_caller_identity" "current" {}

data "aws_route_tables" "default" {
  vpc_id = data.aws_vpc.default.id
}