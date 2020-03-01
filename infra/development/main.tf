terraform {
  required_version = ">= 0.12.0"
}

provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region
}

provider "digitalocean" {}

resource "aws_key_pair" "provisioner" {
  key_name   = "provisioner_key"
  public_key = file("${var.ssh_access_key}.pub")
}

module "prometheus_master" {
  source = "../modules/prometheus"

  do_domain_name    = var.domain_name
  ec2_ssh_key       = var.ssh_access_key
  aws_key_pair_name = aws_key_pair.provisioner.key_name
  aws_region        = var.aws_region
}

module "service_node" {
  source = "../modules/node"

  master_subnet_id  = module.prometheus_master.master_subnet_id
  do_domain_name    = var.domain_name
  ec2_ssh_key       = var.ssh_access_key
  aws_key_pair_name = aws_key_pair.provisioner.key_name
}

