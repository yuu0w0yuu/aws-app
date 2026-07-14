# VPC
data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = ["${local.service}-${local.env}-vpc"]
  }
}

data "aws_subnet" "public" {
  for_each = toset(["ap-northeast-1a", "ap-northeast-1c"])

  vpc_id            = data.aws_vpc.main.id
  availability_zone = each.value

  filter {
    name   = "tag:Name"
    values = ["${local.service}-${local.env}-public-*"]
  }
}

data "aws_subnet" "private" {
  for_each = toset(["ap-northeast-1a", "ap-northeast-1c"])

  vpc_id            = data.aws_vpc.main.id
  availability_zone = each.value

  filter {
    name   = "tag:Name"
    values = ["${local.service}-${local.env}-private-*"]
  }
}

# DNS
data "aws_route53_zone" "main" {
  name         = "aws.home2summit.com"
  private_zone = false
}

data "aws_acm_certificate" "wildcard" {
  domain   = "*.aws.home2summit.com"
  statuses = ["ISSUED"]
}

