data "aws_route53_zone" "main" {
  name         = "aws.home2summit.com"
  private_zone = false
}

data "aws_acm_certificate" "wildcard" {
  domain   = "*.aws.home2summit.com"
  statuses = ["ISSUED"]
} 