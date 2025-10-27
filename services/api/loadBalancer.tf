# ========================================
# NETWORK LOAD BALANCER (INTERNO - RED PRIVADA)
# ========================================
resource "aws_lb" "api" {
  name               = "api-nlb"
  internal           = true  # Load balancer INTERNO en red privada
  load_balancer_type = "network"
  subnets            = var.private_subnet_ids

  enable_deletion_protection       = false
  enable_cross_zone_load_balancing = true

  tags = {
    Name = "api-network-load-balancer"
    Type = "Internal"
  }
}

# ========================================
# TARGET GROUP para NLB
# ========================================
resource "aws_lb_target_group" "api" {
  name        = "api-tg-ip"
  port        = 8080
  protocol    = "TCP"  # NLB usa TCP, no HTTP
  vpc_id      = var.vpc_id
  target_type = "ip"   # Requerido para Fargate con awsvpc

  health_check {
    enabled             = true
    protocol            = "TCP"
    port                = 8080
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
  }

  deregistration_delay = 30

  tags = {
    Name = "api-target-group"
  }
}

# ========================================
# LISTENER para NLB (Puerto 8080)
# ========================================
resource "aws_lb_listener" "api" {
  load_balancer_arn = aws_lb.api.arn
  port              = 8080
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }

  tags = {
    Name = "api-nlb-listener-8080"
  }
}

# ========================================
# CLOUDWATCH ALARMS para monitoreo
# ========================================

# Alarma: Targets no saludables
resource "aws_cloudwatch_metric_alarm" "api_nlb_unhealthy_targets" {
  alarm_name          = "api-nlb-unhealthy-targets"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/NetworkELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "This metric monitors unhealthy targets in API NLB"
  treat_missing_data  = "notBreaching"

  dimensions = {
    TargetGroup  = aws_lb_target_group.api.arn_suffix
    LoadBalancer = aws_lb.api.arn_suffix
  }

  tags = {
    Name = "api-nlb-unhealthy-targets-alarm"
  }
}

# Alarma: Número de conexiones activas
resource "aws_cloudwatch_metric_alarm" "api_nlb_active_connections" {
  alarm_name          = "api-nlb-high-active-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ActiveFlowCount"
  namespace           = "AWS/NetworkELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 1000  # Ajustar según necesidades
  alarm_description   = "This metric monitors high active connections in API NLB"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.api.arn_suffix
  }

  tags = {
    Name = "api-nlb-high-connections-alarm"
  }
}
