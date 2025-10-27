output "wireguard_public_ip" {
  description = "Public IP address to connect WireGuard to"
  value       = aws_eip.wg_eip.public_ip
}

output "instance_id" {
  description = "EC2 instance id running WireGuard"
  value       = aws_instance.wg.id
}

output "security_group_id" {
  description = "Security group created for WireGuard"
  value       = aws_security_group.wg_sg.id
}
