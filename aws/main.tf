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

module "iam" {
  source = "./modules/iam"

  name = "${var.project_name}-instance"
  tags = local.tags
}

# # Two EC2 instances in public and private subnets
# module "ec2_public" {
#   source = "./modules/ec2"

#   name               = "${var.project_name}-public"
#   vpc_id             = module.vpc.vpc_id
#   public_subnet_ids  = module.vpc.public_subnet_ids
#   private_subnet_ids = module.vpc.private_subnet_ids

#   subnet_placement     = "public"
#   instance_type        = var.ec2_instance_type
#   key_name             = var.ec2_key_name
#   allowed_ssh_cidrs    = var.ec2_allowed_ssh_cidrs
#   iam_instance_profile = module.iam.instance_profile_name

#   tags = local.tags
# }

# module "ec2_private" {
#   source = "./modules/ec2"

#   name               = "${var.project_name}-private"
#   vpc_id             = module.vpc.vpc_id
#   public_subnet_ids  = module.vpc.public_subnet_ids
#   private_subnet_ids = module.vpc.private_subnet_ids

#   subnet_placement     = "private"
#   instance_type        = var.ec2_instance_type
#   key_name             = var.ec2_key_name
#   allowed_ssh_cidrs    = var.ec2_allowed_ssh_cidrs
#   iam_instance_profile = module.iam.instance_profile_name

#   tags = local.tags
# }

module "eks" {
  source = "./modules/eks"

  cluster_name       = "${var.project_name}-eks"
  kubernetes_version = var.kubernetes_version
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids

  node_instance_type = var.node_instance_type
  node_desired_size  = var.node_desired_size
  node_min_size      = var.node_min_size
  node_max_size      = var.node_max_size

  update_kubeconfig = var.update_kubeconfig

  tags = local.tags
}
