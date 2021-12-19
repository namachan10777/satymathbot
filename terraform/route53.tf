resource "aws_route53_zone" "satymathbot" {
  name = "satymathbot.net"
}

resource "aws_acm_certificate" "main" {
  domain_name       = "satymathbot.net"
  validation_method = "DNS"
}

resource "aws_route53_record" "cert" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }
  zone_id = aws_route53_zone.satymathbot.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "main" {
  for_each                = toset([for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name])
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [aws_route53_record.cert[each.key].fqdn]
}

resource "aws_route53_record" "main" {
  zone_id = aws_route53_zone.satymathbot.zone_id
  name    = "satymathbot.net"
  type    = "A"
  alias {
    name                   = aws_alb.main.dns_name
    zone_id                = aws_alb.main.zone_id
    evaluate_target_health = true
  }
}