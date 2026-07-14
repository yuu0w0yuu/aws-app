### VPC
resource "aws_vpc" "main" {

  cidr_block = local.vpc.vpc_cidr

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${local.service}-${local.env}-vpc"
  }
}

### Subnets
resource "aws_subnet" "public" {
  vpc_id   = aws_vpc.main.id
  for_each = { for i in local.vpc.public_subnets : i.az => i }

  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = {
    Name = "${local.service}-${local.env}-public-${substr(each.value.az, -2, 2)}"
  }
}

resource "aws_subnet" "private" {
  vpc_id   = aws_vpc.main.id
  for_each = { for i in local.vpc.private_subnets : i.az => i }

  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = {
    Name = "${local.service}-${local.env}-private-${substr(each.value.az, -2, 2)}"
  }
}