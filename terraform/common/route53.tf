resource "aws_route53_zone" "main" {
  name = var.domain_name
}

resource "aws_route53_record" "acm_validation_wildcard" {
  for_each = { for dvo in aws_acm_certificate.wildcard.domain_validation_options : dvo.domain_name => dvo }

  zone_id = aws_route53_zone.main.zone_id
  name    = each.value.resource_record_name
  type    = each.value.resource_record_type
  records = [each.value.resource_record_value]
  ttl     = 60
}