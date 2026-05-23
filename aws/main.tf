locals {
  tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

module "vpc" {
  source = "./modules/vpc"

  name               = "${var.project_name}-vpc"
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  enable_nat_gateway = var.enable_nat_gateway
  tags               = local.tags
}

module "ec2" {
  source = "./modules/ec2"

  name               = "${var.project_name}-bastion"
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids

  subnet_placement  = var.ec2_subnet_placement
  instance_type     = var.ec2_instance_type
  key_name          = var.ec2_key_name
  allowed_ssh_cidrs = var.ec2_allowed_ssh_cidrs

  tags = local.tags
}

# module "eks" {
#   source = "./modules/eks"

#   cluster_name       = "${var.project_name}-eks"
#   kubernetes_version = var.kubernetes_version
#   vpc_id             = module.vpc.vpc_id
#   subnet_ids         = module.vpc.private_subnet_ids

#   node_instance_type = var.node_instance_type
#   node_desired_size  = var.node_desired_size
#   node_min_size      = var.node_min_size
#   node_max_size      = var.node_max_size

#   update_kubeconfig = var.update_kubeconfig

#   tags = local.tags
# }
