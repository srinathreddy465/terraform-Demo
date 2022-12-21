// Create Ec2 Instance

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.8.0"
    }
  }
}

# configure AWS provider
provider "aws" {
  region = "ap-south-1"

}


#  Create VPC
resource "aws_vpc" "DemoVPC" {
  cidr_block       = "10.10.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "DemoVPC"
  }
}

# create subnets

resource "aws_subnet" "DemoSubnet-1a" {
  vpc_id     = aws_vpc.DemoVPC.id
  cidr_block = "10.10.1.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = "true"
  tags = {
    Name = "DemoSubnet-1a"
  }
}


resource "aws_subnet" "DemoSubnet-1b" {
  vpc_id     = aws_vpc.DemoVPC.id
  cidr_block = "10.10.2.0/24"
  availability_zone = "ap-south-1b"
  map_public_ip_on_launch = "true"

  tags = {
    Name = "DemoSubnet-1b"
  }
}

resource "aws_instance" "WebApp1" {
  ami           = "ami-07ffb2f4d65357b42"
  key_name      = "terraform-machine-key"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.DemoSubnet-1a.id
  vpc_security_group_ids = [aws_security_group.allow_port_80_22.id]

  tags = {
    Name = "WebApp"
    App = "frontend"
  }
}



resource "aws_security_group" "allow_port_80_22" {
  name        = "allow_port-80 and port-22"
  description = "Allow HTTP and SSH"
  vpc_id      = aws_vpc.DemoVPC.id

  ingress {
    description      = "Allow port 22"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    
  }

  ingress {
    description      = "Allow port 80"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    
  }

  tags = {
    Name = "allow_22_80"
  }
}

resource "aws_internet_gateway" "IGW" {
  vpc_id = aws_vpc.DemoVPC.id

  tags = {
    Name = "IGW"
  }
}


resource "aws_route_table" "DemoRouteTable" {
  vpc_id = aws_vpc.DemoVPC.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IGW.id
  }

  tags = {
    Name = "DemoRouteTable"
  }
}


resource "aws_route_table_association" "RouteTableAssosiation-1a" {
  subnet_id      = aws_subnet.DemoSubnet-1a.id
  route_table_id = aws_route_table.DemoRouteTable.id
}

resource "aws_route_table_association" "RouteTableAssosiation-1b" {
  subnet_id      = aws_subnet.DemoSubnet-1b.id
  route_table_id = aws_route_table.DemoRouteTable.id
}


#create traget Group for LB
resource "aws_lb_target_group" "Target-Group" {
  name     = "InstanceTargetGroup"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.DemoVPC.id
}

#Aws target group attachment with Instance
resource "aws_lb_target_group_attachment" "Target-Group-Attachment" {
  target_group_arn = aws_lb_target_group.Target-Group.arn
  target_id        = aws_instance.WebApp1.id
  port             = 80
}

#create lb
 resource "aws_lb" "Webapplication" {
  name               = "Webapplication"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_port_80-for-LB.id]
  subnets            = [aws_subnet.DemoSubnet-1a.id,aws_subnet.DemoSubnet-1b.id]

 # enable_deletion_protection = true

  tags = {
    Environment = "production"
  }
}


 #Security group for LB 
resource "aws_security_group" "allow_port_80-for-LB" {
  name        = "allow_port_80"
  description = "Allow HTTP "
  vpc_id      = aws_vpc.DemoVPC.id


  ingress {
    description      = "Allow port 80"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    
  }

  tags = {
    Name = "allow_port_80-for-LB"
  }
}

resource "aws_lb_listener" "Listner" {
  load_balancer_arn = aws_lb.Webapplication.arn
  port              = "80"
  protocol          = "HTTP"
 
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.Target-Group.arn
  }
}


#Create AWS Autoscaling
resource "aws_launch_template" "Launch-Template" {
  name_prefix   = "Web-App-Template"
  image_id      = "ami-0fba3f2f64d4c30d0"
  instance_type = "t2.micro"
  key_name = "terraform-machine-key"
  vpc_security_group_ids = [aws_security_group.allow_port_80_22.id]

}

resource "aws_autoscaling_group" "Webapp-ASG" {
  #availability_zones = ["ap-south-1a"]
  desired_capacity   = 1
  max_size           = 3
  min_size           = 1
  vpc_zone_identifier = [aws_subnet.DemoSubnet-1a.id,aws_subnet.DemoSubnet-1b.id]
  

  launch_template {
    id      = aws_launch_template.Launch-Template.id
    version = "$Latest"
  }
}

