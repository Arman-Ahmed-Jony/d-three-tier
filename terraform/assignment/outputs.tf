output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer."
  value       = aws_lb.app.dns_name
}

output "target_group_arn" {
  description = "Target group ARN, used to read health status."
  value       = aws_lb_target_group.app.arn
}

output "instance_ids" {
  description = "EC2 instance IDs keyed by instance name."
  value       = { for key, instance in aws_instance.app : key => instance.id }
}

output "availability_zones" {
  description = "Availability Zone of each instance."
  value       = { for key, instance in aws_instance.app : key => instance.availability_zone }
}

output "instance_public_ips" {
  description = "Public IPs. Port 80 on these addresses must fail; only the load balancer accepts user traffic."
  value       = { for key, instance in aws_instance.app : key => instance.public_ip }
}
