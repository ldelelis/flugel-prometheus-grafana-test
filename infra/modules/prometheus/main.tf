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


resource "aws_iam_role" "ec2_discovery_role" {
  name               = "EC2Discovery"
  assume_role_policy = <<POL
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
POL
}

resource "aws_iam_role_policy_attachment" "ec2_discovery_readonly_pol" {
  role       = aws_iam_role.ec2_discovery_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

resource "aws_iam_instance_profile" "ec2_discovery_profile" {
  name = "EC2Discovery"
  role = aws_iam_role.ec2_discovery_role.name
}

resource "aws_security_group" "master_http" {
  name        = "allow_web"
  description = "Allows access to web resources via http and https"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress { # Allow outgoing connections
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "prometheus_master" {
  ami = data.aws_ami.latest_ubuntu_ami.id

  instance_type        = "t2.micro"
  iam_instance_profile = aws_iam_instance_profile.ec2_discovery_profile.name
  key_name             = var.aws_key_pair_name
  security_groups = [
    aws_security_group.master_http.name
  ]

  tags = {
    Name        = "flugel-grafana.ldelelis.dev"
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

resource "aws_eip" "master_ip" {
  instance = aws_instance.prometheus_master.id
  vpc      = true
}

resource "digitalocean_record" "master_domain_record" {
  domain = var.do_domain_name
  type   = "A"
  name   = "flugel-grafana"
  ttl    = 30
  value  = aws_eip.master_ip.public_ip
}

resource "null_resource" "provision_master" {
  triggers = {
    master_instance_record_id = digitalocean_record.master_domain_record.id
  }

  provisioner "local-exec" {
    command = "sleep 30" # Wait for DO record to propagate correctly
  }

  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i '${digitalocean_record.master_domain_record.fqdn},' -u ubuntu --private-key ${var.ec2_ssh_key} -e 'ec2_instance_region=${var.aws_region} ec2_instance_profile_arn=${aws_iam_instance_profile.ec2_discovery_profile.arn} certbot_staging=true' ../../provision/master.yml"
  }
}
