# Declare provider and profile

provider "aws" {
    region = "ap-south-1"
    profile = "default"
    #shared_credentials_file = "/root/.aws/credentials"
    shared_credentials_file = "C:\\Users\\Lenovo\\.aws\\credentials"
  
}

# Backend Configurations

terraform {
  backend "s3" {
    
    bucket = "tf-main-storage"
    key = "statefilesarea/toasg/terraform.tfstate"
    region = "ap-south-1"

    dynamodb_table = "tf-locks"
    encrypt = true
    
  }
}

# Creating read-only data source 

data "aws_vpc" "vpcdata" {
    default = true
}

data "aws_subnet_ids" "subnetids" {
  vpc_id = data.aws_vpc.vpcdata.id
}

# Create security group to allow port 80 for ALB to listen

resource "aws_security_group" "albsg" {
  name = "sg-for-alb"

  # Allows inbound http requests
  ingress = [ {
    cidr_blocks = [ "0.0.0.0/0" ]
    description = "http port"
    protocol = "tcp"
    from_port = 80    
    to_port = 80
  } ]

  # Allows all outbound requests
  egress = [ {
    cidr_blocks = [ "0.0.0.0/0" ]
    description = "allows all outbound traffic"
    from_port = 0
    to_port = 0
    protocol = "-1"    
  } ]

}

# Making a target group for the ASG

resource "aws_lb_target_group" "albtargetgroup" {
    name = "lb-target-group"
    port = 80
    protocol = "HTTP"
    vpc_id = data.aws_vpc.vpcdata.id

    health_check {
      path = "/"
      protocol = "HTTP"
      matcher = "200"
      interval = 15
      timeout = 3
      healthy_threshold = 2
      unhealthy_threshold = 2
    }
      
}

# Create a ASG Launch Configuration

resource "aws_launch_configuration" "asglaunchconfig" {
  image_id = "ami-03f0fd1a2ba530e75"
  instance_type = "t2.micro"
  security_groups = [ aws_security_group.instance.id ]
  user_data = <<-EOF
             #!/bin/bash
             sudo apt update -y
             sudo apt install apache2 -y
             sudo systemctl start apache2 
             sudo bash -c 'systemctl status apache2 > /var/www/html/index.html'
             EOF
    
    lifecycle {
      create_before_destroy = true
    }
}

# Create the ASG itself

resource "aws_autoscaling_group" "asgtestgroup" {
    launch_configuration = aws_launch_configuration.asglaunchconfig.name
    vpc_zone_identifier = data.aws_subnet_ids.subnetids.ids
    target_group_arns = [ aws_lb_target_group.albtargetgroup.arn ]
    health_check_type = "ELB"
    min_size = 2
    max_size = 10

    tag {
      key = "Name"
      value = "asgexample"
      propagate_at_launch = true
    }
  
}

# Creating Application Load Balancer ALB 

resource "aws_lb" "albtest" {
  name = "ALB-for-ASG"
  load_balancer_type = "application"
  subnets = data.aws_subnet_ids.subnetids.ids
  security_groups = [ aws_security_group.albsg.id ]
}

# Creating ALB listener

resource "aws_lb_listener" "alblistener" {
    load_balancer_arn = aws.lb.albtest.arn
    port = 80
    protocol = "HTTP"

    # by default, return a simple 404 page
    default_action {
      type = "fixed-response"

      fixed_response {
        content_type = "text/plain"
        message_body = "404: Page Not Found"
        status_code = 404
      }
    }
}

# Making a ALB Listener Rule

resource "aws_alb_listener_rule" "alblistenerrule" {
    listener_arn = aws_lb_listener.alblistener.arn
    priority = 100
    condition {
      field = "path-pattern"
      values = ["*"]
    }

    action {
      type = "forward"
      target_group_arn = aws_lb_target_group.albtargetgroup.arn
    }
  
}

output "alb-dns-name" {
  value = aws_lb.albtest.dns_name
  description = "The domain name of the Load Balancer"
}

