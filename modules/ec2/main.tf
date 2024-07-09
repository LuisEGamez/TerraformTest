resource "aws_security_group" "bastion-tf-sg" {
  name        = "bastion-${var.suffix}-sg"
  description = "Security group for bastion server"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH connection."
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my-ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.prefix}-bastion-sg"
  }
}

resource "aws_security_group" "users-tf-sg" {
  name        = "users-tf-sg"
  description = "Security group for users server"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH connection."
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.bastion-tf-sg.id]
  }

  ingress {
    description = "HTTP app security group."
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    security_groups = [var.elb_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.prefix}-users-${var.suffix}-sg"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "tls_private_key" "users" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "local_file" "private_key" {
  content  = tls_private_key.users.private_key_pem
  filename = "${path.module}/users-${var.suffix}.pem"
}

resource "aws_key_pair" "users-key" {
  key_name   = "users-key"
  public_key = tls_private_key.users.public_key_openssh
}

resource "aws_instance" "bastion-tf" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  subnet_id     = var.public_subnet_ip
  vpc_security_group_ids = [aws_security_group.bastion-tf-sg.id]
  associate_public_ip_address = true
  key_name = aws_key_pair.users-key.key_name
  iam_instance_profile = var.instance_profile_name
  tags = {
    Name = "${var.prefix}-bastion-${var.suffix}"
  }
}

resource "aws_eip" "bastion_eip" {
  instance = aws_instance.bastion-tf.id
}


resource "aws_instance" "users-tf" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  subnet_id     = var.private_subnets_ids[0]
  vpc_security_group_ids = [aws_security_group.users-tf-sg.id]
  key_name = aws_key_pair.users-key.key_name
  iam_instance_profile = var.instance_profile_name
  tags = {
    Name = "${var.prefix}-users-${var.suffix}"
  }
}

resource "aws_security_group" "votes-tf-sg" {
  name        = "votes-tf-sg"
  description = "Security group for votes server"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH connection."
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.bastion-tf-sg.id]
  }

  ingress {
    description = "HTTP app security group."
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    security_groups = [var.elb_security_group_id] // Todo change this
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.prefix}-votes-${var.suffix}-sg"
  }
}

resource "aws_instance" "votes-tf" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  subnet_id     = var.private_subnets_ids[1]
  vpc_security_group_ids = [aws_security_group.users-tf-sg.id]
  key_name = aws_key_pair.users-key.key_name
  iam_instance_profile = var.instance_profile_name
  tags = {
    Name = "${var.prefix}-users-${var.suffix}"
  }
}

resource "aws_launch_template" "votes-launch-template" {
  name     = "${var.prefix}-votes-launch-template-${var.suffix}"
  instance_type = "t3.micro"
  image_id = data.aws_ami.ubuntu.id

  iam_instance_profile {
    name = var.instance_profile_name
  }

  vpc_security_group_ids  = [aws_security_group.votes-tf-sg.id]

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size = 8
      volume_type = "gp3"
    }
  }

  user_data = base64encode(<<EOF
    #!/bin/sh

    #!/bin/bash
    wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt update
    sudo apt-get -y install make apt-transport-https ca-certificates curl gnupg2 software-properties-common jq  cgroup-tools tree terraform

    # Add Docker's official GPG key:
    sudo apt-get update
    sudo apt-get install ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update

    sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    usermod -aG docker ubuntu
    sudo snap install --classic aws-cli
    aws ecr get-login-password --region us-east-1 | sudo docker login --username AWS --password-stdin 273440013219.dkr.ecr.us-east-1.amazonaws.com
    sudo docker run -d -p 9002:9002 --restart unless-stopped --name votes 273440013219.dkr.ecr.us-east-1.amazonaws.com/votes:latest
    reboot
    EOF
  )

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.prefix}-votes-launch-template-${var.suffix}"
    }
  }
}

resource "aws_autoscaling_group" "votes-asg" {
  name                = "${var.prefix}-votes-asg-${var.suffix}"
  vpc_zone_identifier = [var.private_subnets_ids[0],var.private_subnets_ids[1]]

  target_group_arns = [ var.votes_tg_arn ]

  desired_capacity = 2
  max_size         = 4
  min_size         = 0

  max_instance_lifetime = 60*60*24*7

  capacity_rebalance = true

  mixed_instances_policy {

    instances_distribution {
      // prioritized, lowest-price
      on_demand_allocation_strategy = "prioritized"
      // Minimum number of on-demand/reserved nodes
      on_demand_base_capacity = 1
      // Once that minimum has been granted, percentage of on-demand for
      // the rest of the total capacity
      on_demand_percentage_above_base_capacity = 25
      // lowest-price, capacity-optimized, capacity-optimized-prioritized, price-capacity-optimized
      spot_allocation_strategy = "capacity-optimized"
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.votes-launch-template.id
      }

      override {
        instance_type     = "t3.micro"
        weighted_capacity = "1"
      }

      override {
        instance_type     = "t3.small"
        weighted_capacity = "2"
      }

      override {
        instance_type     = "t3.medium"
        weighted_capacity = "2"
      }
    }
  }
}