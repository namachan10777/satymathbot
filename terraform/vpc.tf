resource "aws_vpc" "main" {
  cidr_block                       = "172.16.0.0/16"
  instance_tenancy                 = "default"
  assign_generated_ipv6_cidr_block = true
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "public" {
  destination_cidr_block      = "0.0.0.0/0"
  destination_ipv6_cidr_block = "::0/0"
  route_table_id              = aws_route_table.main.id
  gateway_id                  = aws_internet_gateway.main.id
}

locals {
  public_subnets = {
    a = 1
    c = 2
    d = 3
  }

  private_subnets = {
    a = 4
    c = 5
    d = 6
  }
}

resource "aws_subnet" "public" {
  for_each                        = local.public_subnets
  vpc_id                          = aws_vpc.main.id
  cidr_block                      = cidrsubnet(aws_vpc.main.cidr_block, 8, each.value)
  ipv6_cidr_block                 = cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, each.value)
  assign_ipv6_address_on_creation = true
  availability_zone               = "ap-northeast-1${each.key}"
}

resource "aws_route_table_association" "public" {
  for_each       = local.public_subnets
  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.main.id
}

resource "aws_subnet" "private" {
  for_each                        = local.private_subnets
  vpc_id                          = aws_vpc.main.id
  cidr_block                      = cidrsubnet(aws_vpc.main.cidr_block, 8, each.value)
  ipv6_cidr_block                 = cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, each.value)
  assign_ipv6_address_on_creation = true
  availability_zone               = "ap-northeast-1${each.key}"
}