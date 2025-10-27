WireGuard EC2 deployment module

This directory contains a minimal Terraform configuration to launch an Ubuntu EC2 instance
that installs and runs WireGuard via cloud-init (user data). It creates:

- Security group allowing UDP on the WireGuard port and SSH.
- An EC2 instance (Ubuntu Jammy by default).
- An Elastic IP attached to the instance.

Usage

Set the required variables in your root `main.tf` module call or via `terraform.tfvars`:

- `vpc_id`
- `public_subnet_id`
- Optionally `key_name`, `instance_profile_name`, `wireguard_port`, etc.

After `terraform apply` the output `wireguard_public_ip` will contain the IP to use
as the WireGuard server endpoint. The client config is written on the instance to
`/home/ubuntu/wireguard-client.conf` (or `/root/wireguard-client.conf` if user ubuntu is not present).

To retrieve it you can SSH to the instance and download the file, or add SSM/S3 logic
if your instance profile has the required permissions.
