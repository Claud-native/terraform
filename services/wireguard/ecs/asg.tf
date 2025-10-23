resource "aws_autoscaling_group" "ecs_wg_asg" {
  name_prefix          = "ecs-wg-asg-"
  launch_template {
    id      = aws_launch_template.ecs_wg_lt.id
    version = "$Latest"
  }

  min_size             = var.desired_capacity
  max_size             = var.max_capacity
  desired_capacity     = var.desired_capacity

  vpc_zone_identifier = var.public_subnet_ids

  tag {
    key                 = "Name"
    value               = "ecs-wg-instance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}
