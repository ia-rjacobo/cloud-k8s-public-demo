######################################
## Create Load Balancer(s)
######################################
## FE
resource "aws_lb" "albfe" {
 name               = "fe"
 internal           = false
 load_balancer_type = "application"
 security_groups    = [aws_security_group.alb_sg_group.id]
 subnets            = [aws_subnet.public_subnet[0].id, aws_subnet.public_subnet[1].id, aws_subnet.public_subnet[2].id]

 tags = {
   Environment = "dev"
 }
}
// Listener
resource "aws_lb_listener" "albfe_listener" {
 load_balancer_arn = aws_lb.albfe.arn
 port              = "443"
 protocol          = "HTTPS"
 ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-Res-2021-06"
 certificate_arn   = aws_acm_certificate.albfecertificate.arn

 default_action {
   type             = "forward"
      forward {
        target_group {
          arn    = aws_lb_target_group.blue.arn
          weight = lookup(local.traffic_dist_map[var.traffic_distribution], "blue", 100)
        }

        target_group {
          arn    = aws_lb_target_group.green.arn
          weight = lookup(local.traffic_dist_map[var.traffic_distribution], "green", 0)
        }

        stickiness {
          enabled  = true
          duration = 24 * 60 * 60
        }
      }
    }
}
resource "aws_security_group" "alb_sg_group" {
    name = "alb_sg_group"
    description = "Security group"
    vpc_id = aws_vpc.vpc.id

    ingress {
        description = "security group"
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
        ipv6_cidr_blocks = [ "::/0" ]
    }

}
######################################
## Create A Record - FE
######################################
resource "aws_route53_record" "alb_record" {
  zone_id = var.vpc_zone_id
  name    = var.route53_fealb
  type     = "A"
  # Use alias to point to the load balancer
  alias {
    name = aws_lb.albfe.dns_name # Reference the ALB's DNS name
    zone_id  = aws_lb.albfe.zone_id # Reference the ALB's zone ID
    evaluate_target_health = true # Optional: Route 53 health check
  }
}
######################################
## Create SSL Cert(s) - FE
######################################
resource "aws_acm_certificate" "albfecertificate" {
  domain_name       = var.route53_cert_domain_name
  validation_method = "DNS"

  subject_alternative_names = [
    "*.${var.route53_cert_domain_name}",
    "*.us.${var.route53_cert_domain_name}",
    "*.blue.${var.route53_cert_domain_name}",
    "*.us-west-2.blue.${var.route53_cert_domain_name}"
  ]

  tags = {
    Name = "${var.route53_fealb} SSL certificate"
  }
}
resource "aws_route53_record" "certificate" {
  for_each = {
    for dvo in aws_acm_certificate.albfecertificate.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
   # Skips the domain if it doesn't contain a wildcard
    if length(regexall("\\*\\..+", dvo.domain_name)) > 0
  }
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.vpc_zone_id
}
# Associate the SSL certificate with the ALB listener
resource "aws_lb_listener_certificate" "albfecertificate" {
  listener_arn = aws_lb_listener.albfe_listener.arn
  certificate_arn = aws_acm_certificate.albfecertificate.arn
}
