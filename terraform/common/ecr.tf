resource "aws_ecr_repository" "test-app" {
   name                 = "test-app"
   image_tag_mutability = "IMMUTABLE"
   image_scanning_configuration {
     scan_on_push = true
   }
   tags = local.default_tags
}

resource "aws_ecr_lifecycle_policy" "main" {
  repository = aws_ecr_repository.test-app.name
  policy     = <<EOF
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Keep last 30 images",
      "selection": {
        "tagStatus": "tagged",
        "tagPrefixList": ["v"],
        "countType": "imageCountMoreThan",
        "countNumber": 30
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
EOF
}