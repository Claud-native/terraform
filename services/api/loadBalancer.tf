# ========================================
# APPLICATION LOAD BALANCER (PÚBLICO - RED PÚBLICA)
# ========================================
resource "aws_lb" "api" {
  name               = "api-alb"
  internal           = false  # Load balancer PÚBLICO para acceso desde internet
  load_balancer_type = "application"
  security_groups    = [var.public_security_group_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection       = false
  enable_http2                     = true
  enable_cross_zone_load_balancing = true

  tags = {
    Name = "api-application-load-balancer"
    Type = "Public"
  }
}

# ========================================
# TARGET GROUP para ALB
# ========================================
resource "aws_lb_target_group" "api" {
  name        = "api-tg-alb-ip"
  port        = 8080
  protocol    = "HTTP"  # ALB usa HTTP
  vpc_id      = var.vpc_id
  target_type = "ip"    # Requerido para Fargate con awsvpc

  health_check {
    enabled             = true
    protocol            = "HTTP"
    path                = "/api/health"
    port                = 8080
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    timeout             = 5
    matcher             = "200"
  }

  deregistration_delay = 30

  # Stickiness (sesiones pegajosas)
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400  # 1 día
    enabled         = true
  }

  tags = {
    Name = "api-target-group"
  }
}

# ========================================
# LISTENER HTTP para ALB (Puerto 80)
# ========================================
resource "aws_lb_listener" "api" {
  load_balancer_arn = aws_lb.api.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }

  tags = {
    Name = "api-alb-listener-80"
  }
}

# ========================================
# CLOUDWATCH ALARMS para monitoreo
# ========================================

# Alarma: Targets no saludables
resource "aws_cloudwatch_metric_alarm" "api_alb_unhealthy_targets" {
  alarm_name          = "api-alb-unhealthy-targets"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "This metric monitors unhealthy targets in API ALB"
  treat_missing_data  = "notBreaching"

  dimensions = {
    TargetGroup  = aws_lb_target_group.api.arn_suffix
    LoadBalancer = aws_lb.api.arn_suffix
  }

  tags = {
    Name = "api-alb-unhealthy-targets-alarm"
  }
}

# Alarma: Respuestas 5xx
resource "aws_cloudwatch_metric_alarm" "api_alb_5xx_errors" {
  alarm_name          = "api-alb-high-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "This metric monitors 5xx errors in API ALB"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.api.arn_suffix
  }

  tags = {
    Name = "api-alb-5xx-errors-alarm"
  }
}
