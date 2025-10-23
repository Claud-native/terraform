data "aws_ami" "ecs_ami" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }
}

resource "aws_launch_template" "ecs_wg_lt" {
  name_prefix   = "ecs-wg-lt-"
  image_id      = data.aws_ami.ecs_ami.id
  instance_type = var.instance_type

  dynamic "iam_instance_profile" {
    for_each = var.create_iam ? [1] : (var.instance_profile_name != "" ? [1] : [])
    content {
      name = var.create_iam ? aws_iam_instance_profile.ecs_instance_profile[0].name : var.instance_profile_name
    }
  }

  user_data = base64encode(templatefile("${path.module}/ecs_user_data.sh.tpl", { cluster_name = aws_ecs_cluster.wg_cluster.name }))

  vpc_security_group_ids = [aws_security_group.ecs_wireguard_sg.id]
}
