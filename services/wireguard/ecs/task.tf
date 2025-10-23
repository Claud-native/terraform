resource "aws_ecs_task_definition" "wg_task" {
  family                   = "wg-task"
  network_mode             = "host"
  requires_compatibilities = ["EC2"]
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([
    {
      name       = "wireguard"
      image      = var.container_image
      essential  = true
      privileged = true
      linuxParameters = {
        capabilities = { add = ["NET_ADMIN","SYS_MODULE"] }
      }
      environment = [
        { name = "TZ", value = "UTC" }
      ]
      mountPoints = [
        { sourceVolume = "wg_config", containerPath = "/config" },
        { sourceVolume = "lib_modules", containerPath = "/lib/modules", readOnly = true }
      ]
    }
  ])

  volume {
    name = "wg_config"
    host_path = "/opt/wireguard/config"
  }

  volume {
    name = "lib_modules"
    host_path = "/lib/modules"
  }
}

resource "aws_ecs_service" "wg_service" {
  name            = "wg-service"
  cluster         = aws_ecs_cluster.wg_cluster.id
  task_definition = aws_ecs_task_definition.wg_task.arn
  desired_count   = var.desired_capacity
  launch_type     = "EC2"

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
}
