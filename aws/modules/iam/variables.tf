variable "name" {
  description = "Name prefix for the IAM role and instance profile"
  type        = string
}

variable "extra_policy_arns" {
  description = "Additional IAM managed policy ARNs to attach to the role (beyond AmazonSSMManagedInstanceCore)"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
