variable "aws_profile" {
  type        = string
  description = "AWS CLI Profile name."
  default     = "flugel-monitoring"
}

variable "aws_region" {
  type        = string
  description = "AWS Region to operate on."
  default     = "us-east-1"
}

variable "domain_name" {
  type        = string
  description = "Name of the DigitalOcean domain to use."
}

variable "ssh_access_key" {
  type        = string
  description = "Path to the ssh key to use for EC2 instances."
}
