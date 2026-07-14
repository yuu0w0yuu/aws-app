# ECS Service/Taskはecspressoで管理

resource "aws_ecs_cluster" "main" {
  name = local.service

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.default_tags
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 100
  }
}

resource "aws_security_group" "ecs_service" {
  name        = "${local.service}-ecs-service"
  description = "Security group for ${local.service} ECS service"
  vpc_id      = data.aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}