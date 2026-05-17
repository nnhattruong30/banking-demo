locals {
  public_subnets  = [cidrsubnet(var.vpc_cidr, 8, 0)]
  private_subnets = [cidrsubnet(var.vpc_cidr, 8, 10)]
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = var.name
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  public_subnets  = local.public_subnets
  private_subnets = local.private_subnets

  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Lock down the default security group (CIS benchmark)
  manage_default_security_group  = true
  default_security_group_ingress = []
  default_security_group_egress  = []

  public_subnet_tags  = { Tier = "public" }
  private_subnet_tags = { Tier = "private" }

  tags = var.tags
}
