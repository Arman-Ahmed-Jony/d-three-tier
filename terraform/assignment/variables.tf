variable "region" {
  description = "AWS region. Subnets use the a and b Availability Zones in this region."
  type        = string
  default     = "us-east-2"
}

variable "instance_type" {
  description = "EC2 instance type. t2.micro is Free Tier eligible."
  type        = string
  default     = "t2.micro"
}

variable "stop_instance_1" {
  description = "When true, stop the instance in us-east-2a so the load balancer fails over to us-east-2b."
  type        = bool
  default     = false
}
