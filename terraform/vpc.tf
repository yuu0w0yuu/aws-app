# VPC/Subnetはterraform/common/vpc.tfで作成
### Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = data.aws_vpc.main.id
  tags = {
    Name = "${local.service}-${local.env}-internet-gateway"
  }
}

resource "aws_eip" "natgateway" {
  domain = "vpc"
  tags = {
    Name = "${local.service}-${local.env}-eip-natgateway"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.natgateway.id
  #コストを考慮して1aにのみ作成
  subnet_id = data.aws_subnet.public["ap-northeast-1a"].id
  tags = {
    Name = "${local.service}-${local.env}-natgateway"
  }
}

### Route Table
## Public Subnet -> Internet
resource "aws_route_table" "internet_gateway" {
  vpc_id = data.aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = {
    Name = "${local.service}-${local.env}-rtb-internet-gateway"
  }
}

resource "aws_route_table_association" "internet_gateway" {
  for_each       = data.aws_subnet.public
  route_table_id = aws_route_table.internet_gateway.id
  subnet_id      = each.value.id
}

## Private Subnet -> Nat Gateway -> Internet
resource "aws_route_table" "gateway" {
  vpc_id = data.aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
  tags = {
    Name = "${local.service}-${local.env}-rtb-gateway"
  }
}

resource "aws_route_table_association" "gateway" {
  for_each       = data.aws_subnet.private
  route_table_id = aws_route_table.gateway.id
  subnet_id      = each.value.id
}

### Security Group for VPC Endpoints
resource "aws_security_group" "endpoint" {
  name        = "${local.service}-${local.env}-endpoint-sg"
  description = "Security group for VPC endpoints"
  vpc_id      = data.aws_vpc.main.id

  tags = {
    Name = "${local.service}-${local.env}-endpoint-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ingress_endpoint" {
  security_group_id            = aws_security_group.endpoint.id
  referenced_security_group_id = aws_security_group.ecs_service.id
  ip_protocol                  = "-1"
}

resource "aws_vpc_security_group_egress_rule" "egress_endpoint" {
  security_group_id = aws_security_group.endpoint.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

### VPC Endpoints
## S3 (Gateway)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = data.aws_vpc.main.id
  service_name      = "com.amazonaws.ap-northeast-1.s3"
  vpc_endpoint_type = "Gateway"

  tags = {
    Name = "${local.service}-${local.env}-s3-endpoint"
  }
}

resource "aws_vpc_endpoint_route_table_association" "s3" {
  route_table_id  = aws_route_table.gateway.id
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
}

## ECR API
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = data.aws_vpc.main.id
  service_name        = "com.amazonaws.ap-northeast-1.ecr.api"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [for subnet in data.aws_subnet.private : subnet.id]
  security_group_ids  = [aws_security_group.endpoint.id]

  tags = {
    Name = "${local.service}-${local.env}-ecr-api-endpoint"
  }
}

## ECR DKR
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = data.aws_vpc.main.id
  service_name        = "com.amazonaws.ap-northeast-1.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [for subnet in data.aws_subnet.private : subnet.id]
  security_group_ids  = [aws_security_group.endpoint.id]

  tags = {
    Name = "${local.service}-${local.env}-ecr-dkr-endpoint"
  }
}

## CloudWatch Logs
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = data.aws_vpc.main.id
  service_name        = "com.amazonaws.ap-northeast-1.logs"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [for subnet in data.aws_subnet.private : subnet.id]
  security_group_ids  = [aws_security_group.endpoint.id]

  tags = {
    Name = "${local.service}-${local.env}-logs-endpoint"
  }
}

## Secrets Manager
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = data.aws_vpc.main.id
  service_name        = "com.amazonaws.ap-northeast-1.secretsmanager"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [for subnet in data.aws_subnet.private : subnet.id]
  security_group_ids  = [aws_security_group.endpoint.id]

  tags = {
    Name = "${local.service}-${local.env}-secretsmanager-endpoint"
  }
}

## Systems Manager (SSM)
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = data.aws_vpc.main.id
  service_name        = "com.amazonaws.ap-northeast-1.ssm"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [for subnet in data.aws_subnet.private : subnet.id]
  security_group_ids  = [aws_security_group.endpoint.id]

  tags = {
    Name = "${local.service}-${local.env}-ssm-endpoint"
  }
}

## SSM Messages
resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = data.aws_vpc.main.id
  service_name        = "com.amazonaws.ap-northeast-1.ssmmessages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [for subnet in data.aws_subnet.private : subnet.id]
  security_group_ids  = [aws_security_group.endpoint.id]

  tags = {
    Name = "${local.service}-${local.env}-ssmmessages-endpoint"
  }
}