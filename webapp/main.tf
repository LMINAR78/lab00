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
    from_port = 8080

    to_port = 8080

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

    values = ["packer_ami*"]
  }

  owners = ["056756896182"] # Canonical }
}

data "template_file" "Template" {
  template = "${file("${path.module}/userdata.tpl")}"

  vars {
    username = "loic"
  }
}

/* resource "aws_instance" "web" {
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
} */

resource "aws_launch_configuration" "aws_conf_ami" {
  name_prefix = "aws_conf_ami"

  associate_public_ip_address = "true"
  image_id = "${data.aws_ami.ubuntu.id}"

  instance_type = "t2.micro"

  security_groups = ["${aws_security_group.allow_all.id}"]

  #key_name = "YYYY"

  user_data = "${data.template_file.Template.rendered}"
  lifecycle {
    create_before_destroy = "true"
  }
}

resource "aws_autoscaling_group" "ASG" {
  # vpc_zone_identifier : subnet_ids   
  vpc_zone_identifier       = ["${data.terraform_remote_state.rs-vpc.Subnets[0]}", "${data.terraform_remote_state.rs-vpc.Subnets[1]}"]
  name                      = "asg-${aws_launch_configuration.aws_conf_ami.name}"
  max_size                  = 2
  min_size                  = 2
  health_check_grace_period = 300
  health_check_type         = "EC2"
  launch_configuration      = "${aws_launch_configuration.aws_conf_ami.name}"
  load_balancers            = ["${aws_elb.ELB.id}"]

  tags = [{
    key                 = "Name"
    value               = "autoscaledserver"
    propagate_at_launch = true
  }]

  lifecycle {
    create_before_destroy = "true"
  }
}

resource "aws_elb" "ELB" {
  name = "web-elb"

  subnets = ["${data.terraform_remote_state.rs-vpc.Subnets[0]}", "${data.terraform_remote_state.rs-vpc.Subnets[1]}"]

  security_groups = ["${aws_security_group.allow_all.id}"]

  ## Loadbalancer configuration
  listener {
    instance_port = 8080

    instance_protocol = "http"

    lb_port = 8080

    lb_protocol = "http"
  }

  health_check {
    healthy_threshold = 2

    unhealthy_threshold = 2

    timeout = 2

    target = "HTTP:8080/"

    interval = 5
  }
}
