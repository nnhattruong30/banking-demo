variable "name" {
  description = "Name tag and name prefix for resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID to deploy the instance into"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "subnet_placement" {
  description = "Place the instance in a 'public' or 'private' subnet"
  type        = string
  default     = "private"

  validation {
    condition     = contains(["public", "private"], var.subnet_placement)
    error_message = "subnet_placement must be either 'public' or 'private'."
  }
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "AMI ID to use. Defaults to latest Amazon Linux 2023 x86_64 if left empty"
  type        = string
  default     = ""
}

variable "key_name" {
  description = "EC2 key pair name for SSH access. Leave empty for no key pair"
  type        = string
  default     = ""
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to reach port 22. Empty list disables SSH ingress"
  type        = list(string)
  default     = []
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB"
  type        = number
  default     = 20
}

variable "iam_instance_profile" {
  description = "Name of an existing IAM instance profile to attach to the instance. Leave empty to use no profile"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
