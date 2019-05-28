provider "aws" {
  region = "eu-west-1"
}

terraform {
  backend "s3" {
    bucket         = "s3.lminar78"
    key            = "webapp/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "terraform_state_lock_appli"
  }
}

data "terraform_remote_state" "rs-vpc" {
  backend = "s3"

  config {
    bucket = "s3.lminar78"
    key    = "VPC/terraform.tfstate"
    region = "eu-west-1"
  }
}

resource "aws_security_group" "allow_all" {
  name = "allow_all"

  description = "Allow all inbound traffic"

  vpc_id = "${data.terraform_remote_state.rs-vpc.Main_VPC_ID}"

  ingress {
    from_port = 80

    to_port = 80

    protocol = "tcp"

    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0

    to_port = 0

    protocol = "-1"

    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name = "name"

    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  owners = ["099720109477"] # Canonical }
}

data "template_file" "Template" {
  template = "${file("${path.module}/userdata.tpl")}"

  vars {
    username = "loic"
  }
}

resource "aws_instance" "web" {
  ami = "${data.aws_ami.ubuntu.id}"

  instance_type = "t2.micro"

  #key_name = "=> Manual import"

  vpc_security_group_ids      = ["${aws_security_group.allow_all.id}"]
  user_data                   = "${data.template_file.Template.rendered}"
  subnet_id                   = "${data.terraform_remote_state.rs-vpc.Subnets[0]}"
  associate_public_ip_address = "true"
  tags {
    Name = "HelloWorld"
  }
}
