###
## Common module is responsible for infratructure that is common to the region, and the base region.
##  That is to say, it sets up infrastructure that is required by all regions
###

data "aws_region" "current_region" {}
data "aws_availability_zones" "available" {
  state = "available"
}

### Regional VPC
resource "aws_vpc" "aws-vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = var.deployment_group
  }
}

### Internet gateway (allow internet access)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.aws-vpc.id

  tags = {
    Name = var.deployment_group
  }
}

### Public and Private subnets
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.aws-vpc.id
  cidr_block              = var.private_subnets
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = var.deployment_group
  }
}
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.aws-vpc.id
  cidr_block              = var.public_subnets
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = var.deployment_group
  }
}

### Traffic routing
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.aws-vpc.id

  tags = {
    Name = var.deployment_group
  }
}
resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.aws-vpc.id

  tags = {
    Name = var.deployment_group
  }
}
resource "aws_route" "private" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}
resource "aws_route_table_association" "nat_private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}