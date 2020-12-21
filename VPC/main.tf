# Declare provider and profile

provider "aws" {
  region = "ap-south-1"
  shared_credentials_file = "/root/.aws/credentials"
  profile = "default"
}

# Backend Configurations

terraform {
  backend "s3" {
    
    bucket = "tf-main-storage"
    key = "statefilesarea/tovpc/terraform.tfstate"
    region = "ap-south-1"

    dynamodb_table = "tf-locks"
    encrypt = true
    
  }
}

# Task to be done step by step

# 1. Create VPC

variable "cidrblock" {
  #type = list
  description = "VPC range and subnet values"
}

resource "aws_vpc" "vpctest" {
  cidr_block = var.cidrblock[0].cid_block
  tags = {
    "Name" = var.cidrblock[0].name
  }

}

# 2. Create Internet Gateway

resource "aws_internet_gateway" "GW" {
  vpc_id = aws_vpc.vpctest.id
  tags = {
    "Name" = "gatewayforvpc"
  }
}

# 3. Create Custom Route Table

resource "aws_route_table" "test-route" {
  vpc_id = aws_vpc.vpctest.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.GW.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id = aws_internet_gateway.GW.id
  }
  
  tags = {
    "Name" = "test-route-table"
  }
}

# 4. Create a Subnet

resource "aws_subnet" "subnet-1" {
  vpc_id = aws_vpc.vpctest.id
  cidr_block = var.cidrblock[1].cid_block
  availability_zone = "ap-south-1a"  
  tags = {
    "Name" = var.cidrblock[1].name
  }
}

# 5. Associate subnet with Route Table

resource "aws_route_table_association" "subnet-1-assoc" {
  subnet_id = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.test-route.id
}

# 6. Create Security Group to allow ports (22, 8080, 443, 80) to function 

resource "aws_security_group" "test-sg" {
  name = "test-sg"
  description = "Used for terraform instances"
  vpc_id = aws_vpc.vpctest.id
  # name_prefix = "terraform-"

  ingress {
    description = "ssh coming from VPC"
    from_port = var.sshport
    to_port = var.sshport
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    
  }

  ingress {
    description = "http coming from VPC"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    
  }

  ingress {
    description = "https coming from VPC"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    
  }

  ingress {
    description = "https coming from VPC"
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    
  }

  egress {
    description = "Traffic going out from VPC"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    "Name" = "test-sg"
  }
}

# 7. Create a network interface with an IP in the subnet 

resource "aws_network_interface" "test-nic" {
  subnet_id = aws_subnet.subnet-1.id 
  private_ips = ["10.0.1.25"]
  security_groups = [aws_security_group.test-sg.id]
  
}

# 8. Assign a Elastic IP to the network interface just created

resource "aws_eip" "test-eip" {
  vpc = true
  network_interface = aws_network_interface.test-nic.id
  associate_with_private_ip = "10.0.1.25"
  depends_on = [aws_internet_gateway.GW]
}

# 9. Create a ubuntu instance

resource "aws_instance" "test-instance" {
 ami = "ami-03f0fd1a2ba530e75"  
 instance_type = "t2.micro"
 availability_zone = "ap-south-1a"
 key_name = "2020key"
 network_interface {
   device_index = 0
   network_interface_id = aws_network_interface.test-nic.id
 }

 user_data = <<-EOF
             #!/bin/bash
             sudo apt update -y
             sudo apt install apache2 -y
             sudo systemctl start apache2 
             sudo bash -c 'systemctl status apache2 > /var/www/html/index.html'
             EOF

 tags = {
   "Name" = "ubuntu-instance"
 }

}
