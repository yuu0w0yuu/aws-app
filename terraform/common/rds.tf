resource "aws_rds_cluster" "main" {
  cluster_identifier      = "${local.service}"
  engine                  = "aurora-postgresql"
  engine_version          = "18.3"

  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.rds.id]

  manage_master_user_password = true
  master_username             = "postgres"

  storage_encrypted      = true
  
  serverlessv2_scaling_configuration {
    min_capacity = 0.5
    max_capacity = 4
  }
}

resource "aws_rds_cluster_instance" "main" {
  count              = 1
  identifier         = "${local.service}-instance-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.main.id

  instance_class     = "db.serverless"
 
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version
}

resource "aws_security_group" "rds" {
  name        = "${local.service}-rds"
  description = "Security group for ${local.service} RDS"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
    }
    egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    }
}

resource "aws_db_subnet_group" "main" {
  name       = "${local.service}-db-subnet-group"
  subnet_ids = [for subnet in aws_subnet.private : subnet.id]

  tags = {
    Name = "${local.service}-${local.env}-db-subnet-group"
  }
}