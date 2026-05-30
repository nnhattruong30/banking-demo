module "iam_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "6.6.1"

  name            = var.name
  use_name_prefix = true
  description     = "IAM role for EC2 instance ${var.name}"
  path            = "/"

  create_instance_profile = true

  trust_policy_permissions = {
    EC2AssumeRole = {
      actions = ["sts:AssumeRole"]
      principals = [{
        type        = "Service"
        identifiers = ["ec2.amazonaws.com"]
      }]
    }
  }

  policies = merge(
    { AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" },
    var.extra_policy_arns
  )

  tags = var.tags
}
