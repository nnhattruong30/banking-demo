variable "aws_region" {
  description = "AWS region to deploy the VPC into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "banking-demo"
}

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of AZs to create subnets in"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "enable_nat_gateway" {
  description = "Whether to create NAT Gateways for private subnets"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# ── EKS ────────────────────────────────────────────────────────────────────────

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.35"
}

variable "node_instance_type" {
  description = "EC2 instance type for the managed node group (ARM64 t4g family)"
  type        = string
  default     = "t4g.medium"
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 2
}

variable "update_kubeconfig" {
  description = "Whether to update the local kubeconfig after EKS cluster creation"
  type        = bool
  default     = true
}

# ── EC2 ────────────────────────────────────────────────────────────────────────

variable "ec2_instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ec2_subnet_placement" {
  description = "Place the EC2 instance in a 'public' or 'private' subnet"
  type        = string
  default     = "public"

  validation {
    condition     = contains(["public", "private"], var.ec2_subnet_placement)
    error_message = "ec2_subnet_placement must be either 'public' or 'private'."
  }
}

variable "ec2_key_name" {
  description = "EC2 key pair name for SSH access. Leave empty for no key pair"
  type        = string
  default     = ""
}

variable "ec2_allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to reach port 22. Empty list disables SSH ingress"
  type        = list(string)
  default     = []
}
