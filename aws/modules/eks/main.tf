data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ------------------------------------------------------------------------------
# IAM – Cluster role
# ------------------------------------------------------------------------------

resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ------------------------------------------------------------------------------
# IAM – Node group role
# ------------------------------------------------------------------------------

resource "aws_iam_role" "node" {
  name = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# ------------------------------------------------------------------------------
# Security groups
# ------------------------------------------------------------------------------

resource "aws_security_group" "cluster" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "EKS cluster additional security group"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.cluster_name}-cluster-sg" })
}

resource "aws_vpc_security_group_egress_rule" "cluster_all_outbound" {
  security_group_id = aws_security_group.cluster.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "cluster_from_node_443" {
  security_group_id            = aws_security_group.cluster.id
  referenced_security_group_id = aws_security_group.node.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "Node to cluster API server"
}

resource "aws_security_group" "node" {
  name        = "${var.cluster_name}-node-sg"
  description = "EKS shared node security group"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.cluster_name}-node-sg" })
}

resource "aws_vpc_security_group_egress_rule" "node_all_outbound" {
  security_group_id = aws_security_group.node.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "node_self" {
  security_group_id            = aws_security_group.node.id
  referenced_security_group_id = aws_security_group.node.id
  ip_protocol                  = "-1"
  description                  = "Node to node all traffic"
}

resource "aws_vpc_security_group_ingress_rule" "node_from_cluster" {
  security_group_id            = aws_security_group.node.id
  referenced_security_group_id = aws_security_group.cluster.id
  ip_protocol                  = "-1"
  description                  = "Control plane to node all traffic"
}

# ------------------------------------------------------------------------------
# EKS Cluster
# ------------------------------------------------------------------------------

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.kubernetes_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = var.subnet_ids
    security_group_ids      = [aws_security_group.cluster.id]
    endpoint_public_access  = true
    endpoint_private_access = true
  }

  # Disables extended support (avoids extra charges)
  upgrade_policy {
    support_type = "STANDARD"
  }

  # Use access entries API (required for enable_cluster_creator_admin_permissions)
  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
  ]

  tags = var.tags
}

# ------------------------------------------------------------------------------
# OIDC provider (for IRSA)
# ------------------------------------------------------------------------------

data "tls_certificate" "this" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "this" {
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.this.certificates[0].sha1_fingerprint]

  tags = var.tags
}

# ------------------------------------------------------------------------------
# Cluster-admin access entry (enable_cluster_creator_admin_permissions = true)
# ------------------------------------------------------------------------------

resource "aws_eks_access_entry" "cluster_admin" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = data.aws_caller_identity.current.arn
  type          = "STANDARD"

  tags = var.tags
}

resource "aws_eks_access_policy_association" "cluster_admin" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = data.aws_caller_identity.current.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.cluster_admin]
}

# ------------------------------------------------------------------------------
# Add-ons: vpc-cni and pod-identity-agent before node group (before_compute)
# ------------------------------------------------------------------------------

resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "vpc-cni"

  tags = var.tags
}

resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "eks-pod-identity-agent"

  tags = var.tags
}

# ------------------------------------------------------------------------------
# Managed node group
# ------------------------------------------------------------------------------

resource "aws_eks_node_group" "default" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "default"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.subnet_ids

  # AL2023 on ARM64 (matches t4g instance family)
  ami_type       = "AL2023_ARM_64_STANDARD"
  instance_types = [var.node_instance_type]

  scaling_config {
    min_size     = var.node_min_size
    max_size     = var.node_max_size
    desired_size = var.node_desired_size
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
    aws_eks_addon.vpc_cni,
    aws_eks_addon.pod_identity_agent,
  ]

  tags = var.tags
}

# ------------------------------------------------------------------------------
# Add-ons that require nodes to be ready
# ------------------------------------------------------------------------------

resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "coredns"

  depends_on = [aws_eks_node_group.default]

  tags = var.tags
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "kube-proxy"

  depends_on = [aws_eks_node_group.default]

  tags = var.tags
}

resource "aws_eks_addon" "metrics_server" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "metrics-server"

  depends_on = [aws_eks_node_group.default]

  tags = var.tags
}

# ------------------------------------------------------------------------------
# Update local kubeconfig
# ------------------------------------------------------------------------------

resource "null_resource" "update_kubeconfig" {
  count = var.update_kubeconfig ? 1 : 0

  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --name ${aws_eks_cluster.this.name} --region ${data.aws_region.current.name}"
  }

  depends_on = [aws_eks_cluster.this]
}
