output "instance_id" {
  description = "ID of the EC2 instance"
  value       = module.ec2.id
}

output "private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = module.ec2.private_ip
}

output "public_ip" {
  description = "Public IP address of the EC2 instance (only set when subnet_placement = 'public')"
  value       = module.ec2.public_ip
}

output "security_group_id" {
  description = "ID of the EC2 security group"
  value       = aws_security_group.ec2.id
}
