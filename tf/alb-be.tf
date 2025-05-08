######################################
## Create Load Balancer(s) NLB
######################################
## be
resource "aws_lb" "albbe" {
 name               = "be"
 internal           = true
 load_balancer_type = "application"
 security_groups    = [aws_security_group.alb_sg_group-be.id]
 subnets            = [aws_subnet.private_subnet[0].id, aws_subnet.private_subnet[1].id, aws_subnet.private_subnet[2].id]

 tags = {
   Environment = "dev"
 }
}
// Listener
resource "aws_lb_listener" "albbe_listener-443" {
 load_balancer_arn = aws_lb.albbe.arn
 port              = "443"
 protocol          = "HTTPS"
 ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-Res-2021-06"
 certificate_arn   = aws_acm_certificate.albfecertificate.arn
 default_action {
   type             = "forward"
   target_group_arn = aws_lb_target_group.blue-be-443.arn
    }
}
// Listener
resource "aws_lb_listener" "albbe_listener-8443" {
 load_balancer_arn = aws_lb.albbe.arn
 port              = "8443"
 protocol          = "HTTPS"
 ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-Res-2021-06"
 certificate_arn   = aws_acm_certificate.albfecertificate.arn
 default_action {
   type             = "forward"
   target_group_arn = aws_lb_target_group.blue-be-8443.arn
    }
}

// Listener
resource "aws_lb_listener" "albbe_listener-8444" {
 load_balancer_arn = aws_lb.albbe.arn
 port              = "8444"
 protocol          = "HTTPS"
 ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-Res-2021-06"
 certificate_arn   = aws_acm_certificate.albfecertificate.arn
 default_action {
   type             = "forward"
   target_group_arn = aws_lb_target_group.green-be-8444.arn
    }
}

// Listener
resource "aws_lb_listener" "albbe_listener-9999" {
 load_balancer_arn = aws_lb.albbe.arn
 port              = "9999"
 protocol          = "HTTPS"
 ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-Res-2021-06"
 certificate_arn   = aws_acm_certificate.albfecertificate.arn
 default_action {
   type             = "forward"
   target_group_arn = aws_lb_target_group.blue-be-9999.arn
    }
}

resource "aws_security_group" "alb_sg_group-be" {
    name = "alb_sg_group-be"
    description = "Security group"
    vpc_id = aws_vpc.vpc.id

    ingress {
        description = "security group"
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = [var.cidr_block]
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
## Create A Record - be
######################################
resource "aws_route53_record" "alb_record-be" {
  zone_id = var.vpc_zone_id
  name    = var.route53_bealb
  type     = "A"
  # Use alias to point to the load balancer
  alias {
    name = aws_lb.albbe.dns_name # Reference the ALB's DNS name
    zone_id  = aws_lb.albbe.zone_id # Reference the ALB's zone ID
    evaluate_target_health = true # Optional: Route 53 health check
  }
}


######################################
## NLB TG
######################################
resource "aws_lb_target_group" "blue-be-8443" { // Target Group blue-be
 name     = "target-group-blue-be-8443"
 port     = 8443
 protocol = "HTTPS"
 vpc_id   = aws_vpc.vpc.id
 load_balancing_algorithm_type = "round_robin"
 stickiness {
   enabled = true
   type    = "lb_cookie"
   cookie_duration = "86400"
  }
 health_check {
   path = "/"
   port = 8443
   healthy_threshold = 2
   unhealthy_threshold = 2
   timeout = 2
   interval = 5
   matcher = "200,301,302,307"  # has to be HTTP 200 or fails
 }
}





resource "aws_lb_target_group" "green-be-8444" { // Target Group blue-be
 name     = "target-group-green-be-8444"
 port     = 8444
 protocol = "HTTPS"
 vpc_id   = aws_vpc.vpc.id
 load_balancing_algorithm_type = "round_robin"
 stickiness {
   enabled = true
   type    = "lb_cookie"
   cookie_duration = "86400"
  }
 health_check {
   path = "/"
   port = 8444
   healthy_threshold = 2
   unhealthy_threshold = 2
   timeout = 2
   interval = 5
   matcher = "200,301,302,307"  # has to be HTTP 200 or fails
 }
}

resource "aws_lb_target_group" "blue-be-443" { // Target Group blue-be
 name     = "target-group-blue-be-443"
 port     = 8088
 protocol = "HTTP"
 vpc_id   = aws_vpc.vpc.id
 load_balancing_algorithm_type = "round_robin"
 stickiness {
   enabled = true
   type    = "lb_cookie"
   cookie_duration = "86400"
  }
 health_check {
   path = "/StatusPing"
   port = 8088
   healthy_threshold = 2
   unhealthy_threshold = 2
   timeout = 2
   interval = 5
   matcher = "200,301,302,307"  # has to be HTTP 200 or fails
 }
}

resource "aws_lb_target_group" "blue-be-9999" { // Target Group blue-be
 name     = "target-group-blue-be-9999"
 port     = 9999
 protocol = "HTTP"
 vpc_id   = aws_vpc.vpc.id
 load_balancing_algorithm_type = "round_robin"
 stickiness {
   enabled = true
   type    = "lb_cookie"
   cookie_duration = "86400"
  }
 health_check {
   path = "/"
   port = 9999
   healthy_threshold = 2
   unhealthy_threshold = 2
   timeout = 2
   interval = 5
   matcher = "200,301,302,307"  # has to be HTTP 200 or fails
 }
}

resource "aws_lb_target_group_attachment" "tg_attachment_blue-be-8443" {
count            = length(aws_instance.blue)
 target_group_arn = aws_lb_target_group.blue-be-8443.arn
 target_id        = aws_instance.blue[count.index].id
 port             = 8443
}

resource "aws_lb_target_group_attachment" "tg_attachment_blues-be-8443" {
count = var.enable_blue_env ? var.blues_instance_count : 0
 target_group_arn = aws_lb_target_group.blue-be-8443.arn
 target_id        = aws_instance.blues[count.index].id
 port             = 8443
}



resource "aws_lb_target_group_attachment" "tg_attachment_green-be-8444" {
count            = length(aws_instance.green)
 target_group_arn = aws_lb_target_group.green-be-8444.arn
 target_id        = aws_instance.green[count.index].id
 port             = 8444
}

resource "aws_lb_target_group_attachment" "tg_attachment_greens-be-8444" {
count = var.enable_green_env ? var.greens_instance_count : 0
 target_group_arn = aws_lb_target_group.green-be-8444.arn
 target_id        = aws_instance.greens[count.index].id
 port             = 8444
}


resource "aws_lb_target_group_attachment" "tg_attachment_blue-be-443" {
count            = length(aws_instance.blue)
 target_group_arn = aws_lb_target_group.blue-be-443.arn
 target_id        = aws_instance.blue[count.index].id
 port             = 8088
}

resource "aws_lb_target_group_attachment" "tg_attachment_blues-be-443" {
count = var.enable_blue_env ? var.blues_instance_count : 0
 target_group_arn = aws_lb_target_group.blue-be-443.arn
 target_id        = aws_instance.blues[count.index].id
 port             = 8088
}

resource "aws_lb_target_group_attachment" "tg_attachment_blue-be-9999" {
count            = length(aws_instance.blue)
 target_group_arn = aws_lb_target_group.blue-be-9999.arn
 target_id        = aws_instance.blue[count.index].id
 port             = 9999
}

resource "aws_lb_target_group_attachment" "tg_attachment_blues-be-9999" {
count            = length(aws_instance.blue)
 target_group_arn = aws_lb_target_group.blue-be-9999.arn
 target_id        = aws_instance.blues[count.index].id
 port             = 9999
}

resource "aws_lb_target_group_attachment" "tg_attachment_blue-agent-be-9999" {
count            = length(aws_instance.blue)
 target_group_arn = aws_lb_target_group.blue-be-9999.arn
 target_id        = aws_instance.blue-agent[count.index].id
 port             = 9999
}