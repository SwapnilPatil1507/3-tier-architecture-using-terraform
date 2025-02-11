terraform {
  required_version = "~> 1.1"
  required_providers {
    aws = {
      version = "~>3.1"
    }
  }
}
provider "aws" {
  region     = var.region
  access_key = var.access
  secret_key = var.secret
}
resource "aws_vpc" "customevpc" {
  cidr_block       = "10.0.0.0/16"
  tags = {
    Name = "myvpc"
  }
}
resource "aws_internet_gateway" "myigw" {
    vpc_id = aws_vpc.customevpc.id

    tags = {
        Name = "myigw"
    }
}
resource "aws_subnet" "web-subnet" {
  vpc_id     = aws_vpc.customevpc.id
  cidr_block = "10.0.0.0/20"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "websubnet"
  }
}
resource "aws_subnet" "app-subnet" {
  vpc_id     = aws_vpc.customevpc.id
  cidr_block = "10.0.16.0/20"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "appsubnet"
  }
}
resource "aws_subnet" "db-subnet" {
  vpc_id     = aws_vpc.customevpc.id
  cidr_block = "10.0.32.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "dbsubnet"
  }
}
resource "aws_route_table" "public-rt" {
  vpc_id = aws_vpc.customevpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myigw.id
  }

  tags = {
    Name = "public-rt"
  }
}
resource "aws_route_table" "private-rt" {
  vpc_id = aws_vpc.customevpc.id

  tags = {
    Name = "private-rt"
  }
}
resource "aws_route_table_association" "web-association" {
  subnet_id      = aws_subnet.web-subnet.id
  route_table_id = aws_route_table.public-rt.id
}
resource "aws_route_table_association" "app-association" {
  subnet_id      = aws_subnet.app-subnet.id
  route_table_id = aws_route_table.private-rt.id
}
resource "aws_route_table_association" "db-association" {
  subnet_id      = aws_subnet.db-subnet.id
  route_table_id = aws_route_table.private-rt.id
}
resource "aws_security_group" "mywebsg" {
  name   = "myweb-sg"
  vpc_id = aws_vpc.customevpc.id
  egress {
    to_port     = 0
    from_port   = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    to_port     = 22
    from_port   = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
  # Allow inbound HTTP (port 80)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_security_group" "myappsg" {
  name   = "myapp-sg"
  vpc_id = aws_vpc.customevpc.id
  egress {
    to_port     = 0
    from_port   = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/20"]
  }
}
resource "aws_security_group" "mydbsg" {
  name   = "mydb-sg"
  vpc_id = aws_vpc.customevpc.id
  egress {
    to_port     = 0
    from_port   = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.16.0/20"]
  }
}
resource "aws_instance" "web" {

  ami                    = var.ami
  vpc_security_group_ids = [aws_security_group.mywebsg.id]
  instance_type          = var.ins_type
  subnet_id = aws_subnet.web-subnet.id
  key_name               = "terrakey"
  associate_public_ip_address = true
  tags = {
    Name = "webserver"
  }
}
  resource "aws_instance" "app" {

  ami                    = var.ami
  vpc_security_group_ids = [aws_security_group.myappsg.id]
  subnet_id              = aws_subnet.app-subnet.id
  instance_type          = var.ins_type
  key_name               = "terrakey"
  tags = {
    Name = "appserver"
  }
  }
  resource "aws_db_instance" "myrds" {
  allocated_storage    = 10
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  username             = var.db_user
  password             = var.db_pass
  vpc_security_group_ids = [aws_security_group.mydbsg.id]
  db_subnet_group_name = aws_db_subnet_group.my-subnet-grp.name
  skip_final_snapshot  = true
}
resource "aws_db_subnet_group" "my-subnet-grp" {
  name       = "my-sub-grp"
  subnet_ids = [aws_subnet.app-subnet.id, aws_subnet.db-subnet.id]

  tags = {
    Name = "My DB subnet group"
  }
}
resource "aws_key_pair" "tf-key-pair" {
  key_name   = "terrakey"
  public_key = tls_private_key.rsa.public_key_openssh
}
resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "local_file" "tf-key" {
  content  = tls_private_key.rsa.private_key_pem
  filename = "terrakey"
}
