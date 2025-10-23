# ========================================
# APPLICATION LOAD BALANCER (ALB) - WEB
# ========================================

# Variables que se pasan desde main.tf
variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for ALB"
  type        = string
}

# ========================================
# APPLICATION LOAD BALANCER
# ========================================
resource "aws_lb" "web" {
  name               = "web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.security_group_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false
  enable_http2              = true
  enable_cross_zone_load_balancing = true

  tags = {
    Name        = "web-application-load-balancer"
    Environment = "production"
  }
}

# ========================================
# TARGET GROUP para contenedores/instancias web
# ========================================
resource "aws_lb_target_group" "web" {
  name     = "web-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  # Health check configuration
  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-299"
  }

  # Stickiness (sesiones pegajosas)
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400  # 1 día
    enabled         = true
  }

  # Deregistration delay
  deregistration_delay = 30

  tags = {
    Name = "web-target-group"
  }
}

# ========================================
# LISTENER HTTP (puerto 80)
# ========================================
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = "80"
  protocol          = "HTTP"

  # Default action: Forward to target group
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }

  # Opcional: Redirigir HTTP a HTTPS (descomenta cuando tengas certificado SSL)
  # default_action {
  #   type = "redirect"
  #   redirect {
  #     port        = "443"
  #     protocol    = "HTTPS"
  #     status_code = "HTTP_301"
  #   }
  # }
}

# ========================================
# LISTENER HTTPS (puerto 443)
# ========================================
# Descomenta cuando tengas un certificado SSL/TLS
# resource "aws_lb_listener" "https" {
#   load_balancer_arn = aws_lb.web.arn
#   port              = "443"
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
#   certificate_arn   = "arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/CERT_ID"
#
#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.web.arn
#   }
# }

# ========================================
# CLOUDWATCH ALARMS (Opcional pero recomendado)
# ========================================

# Alarma para Target Unhealthy
resource "aws_cloudwatch_metric_alarm" "target_unhealthy" {
  alarm_name          = "web-alb-unhealthy-targets"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "Alert when targets are unhealthy"

  dimensions = {
    LoadBalancer = aws_lb.web.arn_suffix
    TargetGroup  = aws_lb_target_group.web.arn_suffix
  }

  tags = {
    Name = "web-alb-unhealthy-targets-alarm"
  }
}

# Alarma para respuestas 5xx
resource "aws_cloudwatch_metric_alarm" "http_5xx" {
  alarm_name          = "web-alb-high-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "Alert when 5xx errors are high"

  dimensions = {
    LoadBalancer = aws_lb.web.arn_suffix
  }

  tags = {
    Name = "web-alb-5xx-errors-alarm"
  }
}

# ========================================
# OUTPUTS
# ========================================
output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.web.arn
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer - Use this URL to access your web application"
  value       = aws_lb.web.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.web.zone_id
}

output "target_group_arn" {
  description = "ARN of the target group - use this to attach your web containers/instances"
  value       = aws_lb_target_group.web.arn
}
