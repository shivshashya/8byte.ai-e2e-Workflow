# A single public ALB serves both environments without requiring a domain.
# Frontend listener ports and backend EC2 application ports are independent.
resource "aws_lb" "application" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  ip_address_type    = "ipv4"
  security_groups    = [var.security_group_id]
  subnets            = var.public_subnet_ids

  drop_invalid_header_fields = true
  enable_deletion_protection = var.alb_deletion_protection
  idle_timeout               = 60

  access_logs {
    enabled = true
    bucket  = var.access_log_bucket_name
    prefix  = "alb"
  }

  tags = { Name = "${var.project_name}-alb" }
}

resource "aws_lb_target_group" "application" {
  for_each = var.application_ports

  name        = "${var.project_name}-${each.key}"
  target_type = "instance"
  port        = each.value
  protocol    = "HTTP"
  vpc_id      = var.vpc_id

  # Allow in-flight requests to finish when a target is deregistered.
  # Container replacement on the same registered port still needs deployment
  # coordination; this setting alone does not provide zero-downtime releases.
  deregistration_delay = 30

  health_check {
    enabled             = true
    protocol            = "HTTP"
    port                = "traffic-port"
    path                = var.alb_health_check_path
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name        = "${var.project_name}-${each.key}"
    Environment = each.key
  }
}

resource "aws_lb_target_group_attachment" "application" {
  for_each = var.application_ports

  target_group_arn = aws_lb_target_group.application[each.key].arn
  target_id        = var.ec2_instance_id
  port             = each.value
}

resource "aws_lb_listener" "application" {
  for_each = var.alb_listener_ports

  load_balancer_arn = aws_lb.application.arn
  port              = each.value
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.application[each.key].arn
  }

  tags = { Environment = each.key }
}

# Management endpoints stay private. Target-group health checks go directly to
# EC2 and do not pass through listener rules, so /actuator/health still works.
resource "aws_lb_listener_rule" "block_public_actuator" {
  for_each = var.alb_listener_ports

  listener_arn = aws_lb_listener.application[each.key].arn
  priority     = 10

  action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Not found"
      status_code  = "404"
    }
  }

  condition {
    path_pattern {
      values = ["/actuator", "/actuator/*"]
    }
  }
}
