# E2.0: dev VPC shared by EMR on EC2, MWAA, RDS/DMS and Redshift.
# Cost: $0. No NAT gateway (~$32/mo) and no interface endpoints; the S3 gateway endpoint is free.

locals {
  vpc_cidr = "10.20.0.0/16"

  # Two AZs: RDS, MWAA and Redshift require subnets in at least two.
  public_subnets = {
    "us-east-1a" = "10.20.0.0/24"
    "us-east-1b" = "10.20.1.0/24"
  }
  private_subnets = {
    "us-east-1a" = "10.20.10.0/24"
    "us-east-1b" = "10.20.11.0/24"
  }
}

resource "aws_vpc" "main" {
  cidr_block           = local.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true # EMR nodes resolve each other by DNS name
  tags                 = { Name = "${local.prefix}-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.prefix}-igw" }
}

# Public subnets: route to the internet. A public IP does not mean open; security groups still block inbound.
resource "aws_subnet" "public" {
  for_each                = local.public_subnets
  vpc_id                  = aws_vpc.main.id
  availability_zone       = each.key
  cidr_block              = each.value
  map_public_ip_on_launch = true
  tags                    = { Name = "${local.prefix}-public-${each.key}", tier = "public" }
}

# Private subnets: no internet route at all (databases, internal services).
resource "aws_subnet" "private" {
  for_each          = local.private_subnets
  vpc_id            = aws_vpc.main.id
  availability_zone = each.key
  cidr_block        = each.value
  tags              = { Name = "${local.prefix}-private-${each.key}", tier = "private" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.prefix}-public-rt" }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.prefix}-private-rt" }
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

# Free: S3 traffic from both tiers stays on the AWS network, never the internet.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.public.id, aws_route_table.private.id]
  tags              = { Name = "${local.prefix}-s3-endpoint" }
}

# Adopt the VPC's default security group and remove all of its rules (CIS benchmark).
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.prefix}-default-sg-locked" }
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = [for s in aws_subnet.public : s.id]
}

output "private_subnet_ids" {
  value = [for s in aws_subnet.private : s.id]
}
