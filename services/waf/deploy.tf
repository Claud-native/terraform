# ========================================
# AWS WAF v2 - Web Application Firewall
# ========================================
# Nota: WAF solo protege tráfico HTTP/HTTPS (capa 7)
# Para SSH (puerto 22), usar Security Groups en main.tf

# IP Set para IPs permitidas (opcional - ajusta según tus necesidades)
resource "aws_wafv2_ip_set" "allowed_ips" {
  name               = "allowed-ips"
  description        = "IP set for allowed sources"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"

  # Agrega aquí las IPs que quieres permitir explícitamente
  # addresses = ["203.0.113.0/24", "198.51.100.0/24"]
  addresses = []

  tags = {
    Name = "allowed-ips-set"
  }
}

# WAF Web ACL
resource "aws_wafv2_web_acl" "main" {
  name        = "main-web-acl"
  description = "WAF rules for HTTP/HTTPS traffic protection"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # Regla 1: Bloquear peticiones maliciosas comunes
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # Regla 2: Protección contra ataques conocidos
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesKnownBadInputsRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # Regla 3: Protección contra SQL Injection
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesSQLiRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # Regla 4: Rate limiting - prevenir ataques DDoS
  rule {
    name     = "RateLimitRule"
    priority = 4

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRuleMetric"
      sampled_requests_enabled   = true
    }
  }

  # Regla 5: Permitir solo métodos HTTP específicos
  rule {
    name     = "AllowedHTTPMethods"
    priority = 5

    action {
      allow {}
    }

    statement {
      or_statement {
        statement {
          byte_match_statement {
            search_string         = "GET"
            field_to_match {
              method {}
            }
            text_transformation {
              priority = 0
              type     = "NONE"
            }
            positional_constraint = "EXACTLY"
          }
        }
        statement {
          byte_match_statement {
            search_string         = "POST"
            field_to_match {
              method {}
            }
            text_transformation {
              priority = 0
              type     = "NONE"
            }
            positional_constraint = "EXACTLY"
          }
        }
        statement {
          byte_match_statement {
            search_string         = "HEAD"
            field_to_match {
              method {}
            }
            text_transformation {
              priority = 0
              type     = "NONE"
            }
            positional_constraint = "EXACTLY"
          }
        }
        statement {
          byte_match_statement {
            search_string         = "OPTIONS"
            field_to_match {
              method {}
            }
            text_transformation {
              priority = 0
              type     = "NONE"
            }
            positional_constraint = "EXACTLY"
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AllowedHTTPMethodsMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "MainWebACLMetric"
    sampled_requests_enabled   = true
  }

  tags = {
    Name = "main-web-acl"
  }
}

# ========================================
# CloudWatch Log Group para WAF
# ========================================
resource "aws_cloudwatch_log_group" "waf_log_group" {
  name              = "aws-waf-logs-main"
  retention_in_days = 30

  tags = {
    Name = "waf-logs"
  }
}

# ========================================
# Logging Configuration para WAF
# ========================================
resource "aws_wafv2_web_acl_logging_configuration" "main" {
  resource_arn            = aws_wafv2_web_acl.main.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf_log_group.arn]

  redacted_fields {
    single_header {
      name = "authorization"
    }
  }

  redacted_fields {
    single_header {
      name = "cookie"
    }
  }
}

# ========================================
# Outputs
# ========================================
output "waf_web_acl_id" {
  description = "The ID of the WAF Web ACL"
  value       = aws_wafv2_web_acl.main.id
}

output "waf_web_acl_arn" {
  description = "The ARN of the WAF Web ACL"
  value       = aws_wafv2_web_acl.main.arn
}

output "waf_web_acl_name" {
  description = "The name of the WAF Web ACL"
  value       = aws_wafv2_web_acl.main.name
}
