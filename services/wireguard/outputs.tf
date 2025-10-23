output "wireguard_public_ip" {
  description = "Public IP assigned to the WireGuard server"
  value       = aws_eip.wg_eip.public_ip
}

output "wireguard_instance_id" {
  description = "Instance id for the WireGuard server"
  value       = aws_instance.wireguard.id
}

output "wireguard_sg_id" {
  description = "Security group id for WireGuard"
  value       = aws_security_group.wireguard_sg.id
}
