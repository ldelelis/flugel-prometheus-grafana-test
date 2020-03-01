data "aws_ami" "latest_ubuntu_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

data "aws_subnet" "master_subnet" {
  id = var.master_subnet_id
}

resource "aws_security_group" "node_access" {
  name        = "node_access"
  description = "Allows access to web resources via http and https and exporters"
}

resource "aws_security_group_rule" "allow_http" {
  type = "ingress"

  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.node_access.id
}

resource "aws_security_group_rule" "allow_https" {
  type = "ingress"

  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.node_access.id
}

resource "aws_security_group_rule" "allow_ssh" {
  type = "ingress"

  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.node_access.id
}

resource "aws_security_group_rule" "allow_node_exporter" {
  type = "ingress"

  from_port   = 9100
  to_port     = 9100
  protocol    = "tcp"
  cidr_blocks = [data.aws_subnet.master_subnet.cidr_block]

  security_group_id = aws_security_group.node_access.id
}

resource "aws_security_group_rule" "allow_outgoing" {
  type = "egress"

  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.node_access.id
}

resource "aws_instance" "service_node" {
  ami = data.aws_ami.latest_ubuntu_ami.id

  instance_type   = "t2.micro"
  security_groups = [aws_security_group.node_access.name]
  key_name        = var.aws_key_pair_name
  tags = {
    Name        = "flugel-node.ldelelis.dev"
    Environment = "Training"
    Application = "Monitoring"
  }

  provisioner "remote-exec" { # Wait for the instance to fully start
    inline = ["echo 'waiting on connection'"]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.ec2_ssh_key)
      host        = self.public_ip
    }
  }
}

resource "aws_eip" "node_ip" {
  instance = aws_instance.service_node.id
  vpc      = true
}

resource "digitalocean_record" "node_domain_record" {
  domain = var.do_domain_name
  type   = "A"
  name   = "flugel-node"
  ttl    = 30
  value  = aws_eip.node_ip.public_ip
}

resource "null_resource" "provision_master" {
  triggers = {
    node_instance_id        = aws_instance.service_node.id
    node_instance_record_id = digitalocean_record.node_domain_record.id
  }

  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i '${digitalocean_record.node_domain_record.fqdn},' -u ubuntu --private-key ${var.ec2_ssh_key} -e 'certbot_staging=true' ../../provision/nodes.yml"
  }
}
