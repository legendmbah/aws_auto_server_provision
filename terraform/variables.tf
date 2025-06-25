variable "aws_access_key" {
  description = "AWS access key ID"
  type        = string
  sensitive   = true
}

variable "server_count" {
  description = "Number of EC2 instances to create"
  type        = number
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.medium"
}

variable "ssh_user" {
  description = "Username for SSH access"
  type        = string
  default     = "tmadmin"
}

variable "ssh_password" {
  type        = string
  description = "Password for the SSH user"
  sensitive   = true
}