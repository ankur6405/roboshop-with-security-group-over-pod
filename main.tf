data "aws_eks_cluster" "cluster" {
  name = "dev-skaf"
}

data "aws_eks_cluster_auth" "cluster" {
  name = "dev-skaf"
}

provider "aws" {
  region = "us-east-2"
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
    token                  = data.aws_eks_cluster_auth.cluster.token

  }
}

resource "kubernetes_namespace" "roboshop" {
  count   = var.security_group_enabled ? 1 : 0
  metadata {
    name = var.roboshop_namespace
  }
}

resource "null_resource" "set_daemonset_env" {
  count   = var.security_group_enabled ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<EOT
    kubectl set env daemonset aws-node -n kube-system ENABLE_POD_ENI=true

    EOT
  }
}

module "eks-cluster-sg-additional-rule" {
  count   = var.security_group_enabled ? 1 : 0
  source  = "terraform-aws-modules/security-group/aws"
  version = "v5.1.0"
  vpc_id  = "vpc-091203490f68431fc"

  create_sg         = false
  security_group_id = "sg-028134452c6618502"
  ingress_with_source_security_group_id = [
    {
      from_port                = 0
      to_port                  = 0
      protocol                 = "-1"
      description              = "robo-sg"
      source_security_group_id = module.roboshop-sg[0].security_group_id
    }
  ]
}



module "roboshop-sg" {
  count   = var.security_group_enabled ? 1 : 0
  source  = "terraform-aws-modules/security-group/aws"
  version = "v5.1.0"

  name        = "roboshop-sg" #format("%s-%s", local.environment, "angular-sg")
  description = "roboshop-sg available over services"
  vpc_id      = "vpc-091203490f68431fc"

  ingress_with_cidr_blocks = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "vpc cidr"
      cidr_blocks = "10.10.0.0/16"
    },
    {
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      description = "vpc cidr"
      cidr_blocks = "10.10.0.0/16"
    },
    {
      from_port   = 55555
      to_port     = 55555
      protocol    = "tcp"
      description = "vpc cidr"
      cidr_blocks = "10.10.0.0/16"
    }
  ]
  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      description = "outbound rule"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
}

resource "helm_release" "SecurityGroupPolicy" {
  count   = var.security_group_enabled ? 1 : 0
  name    = "securitygrouppolicyroboshop"
  namespace = "roboshop"
  chart   = "${path.module}/SecurityGroupPolicy/"
  timeout = 600
  values = [
    templatefile("${path.module}/SecurityGroupPolicy/values.yaml", {
      sgid  = module.roboshop-sg[0].security_group_id
    }),
    var.security_group_config.SecurityGroupPolicy_values_yaml
  ]
}
