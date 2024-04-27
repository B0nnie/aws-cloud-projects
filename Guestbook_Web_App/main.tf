# VPC
resource "aws_vpc" "VPC" {
  cidr_block                       = "10.0.0.0/26"
  instance_tenancy                 = "default"
  assign_generated_ipv6_cidr_block = false

  tags = {
    Name    = "forGuestbook"
    project = var.project_tag
  }
}

# Subnet for EC2 Group 1
resource "aws_subnet" "EC2_web1" {
  vpc_id            = aws_vpc.VPC.id
  availability_zone = var.az_1
  cidr_block        = "10.0.0.0/28"

  tags = {
    Name    = "Guestbook-Web-1"
    project = var.project_tag
  }
}

# Subnet for EC2 Group 2
resource "aws_subnet" "EC2_web2" {
  vpc_id            = aws_vpc.VPC.id
  availability_zone = var.az_2
  cidr_block        = "10.0.0.16/28"

  tags = {
    Name    = "Guestbook-Web-2"
    project = var.project_tag
  }
}

# Security Group for EC2s
resource "aws_security_group" "EC2_security_group" {
  name        = "WebServerGroup"
  description = "TBD"
  vpc_id      = aws_vpc.VPC.id

  tags = {
    Name    = "WebServerGroup"
    project = var.project_tag
  }
}

# Security Group Rules for EC2s
resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.EC2_security_group.id
  cidr_ipv4   = "24.30.14.170/32"  #"0.0.0.0/0"
  from_port   = 80
  ip_protocol = "tcp"
  to_port     = 80
   tags = {
    Name    = "HTTP"
   }
}

# EC2 instances for web server
data "aws_ami" "amazon_linux_2023" {
  owners             = ["amazon"]
  include_deprecated = false

  filter {
    name   = "name"
    values = ["al2023-ami-2023.4.20240319.1-kernel-6.1-x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "web_server_1" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.EC2_web1.id
  vpc_security_group_ids      = [aws_security_group.EC2_security_group.id]
  key_name                    = var.key_name
  associate_public_ip_address = true
  #user_data = file("")

  tags = {
    Name    = "Web-Server-1"
    project = var.project_tag
  }
}

resource "aws_instance" "web_server_2" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.EC2_web2.id
  vpc_security_group_ids      = [aws_security_group.EC2_security_group.id]
  key_name                    = var.key_name
  associate_public_ip_address = true
  #user_data = file("")

  tags = {
    Name    = "Web-Server-2"
    project = var.project_tag
  }
}

# Security Group for RDS DB Instance 
resource "aws_security_group" "RDS_security_group" {
  name        = "RDSStorageGroup"
  description = "TBD"
  vpc_id      = aws_vpc.VPC.id

  tags = {
    Name    = "RDSStorageGroup"
    project = var.project_tag
  }
}

# Subnet 1 for RDS DB Instance
resource "aws_subnet" "RDS_storage1" {
  vpc_id            = aws_vpc.VPC.id
  availability_zone = var.az_1
  cidr_block        = "10.0.0.32/28"

  tags = {
    Name    = "Guestbook-RDS-1"
    project = var.project_tag
  }
}

# Subnet 2 for RDS DB Instance
resource "aws_subnet" "RDS_storage2" {
  vpc_id            = aws_vpc.VPC.id
  availability_zone = var.az_2
  cidr_block        = "10.0.0.48/28"

  tags = {
    Name    = "Guestbook-RDS-2"
    project = var.project_tag
  }
}

# Subnet Group for RDS DB Instance
resource "aws_db_subnet_group" "RDS_db_subnet_group" {
  name       = "guestbook-db-subnet-group"
  subnet_ids = [aws_subnet.RDS_storage1.id, aws_subnet.RDS_storage2.id]

  tags = {
    Name    = "Guestbook-DB-Subnet-Group"
    project = var.project_tag
  }
}

# RDS DB Instance
resource "aws_db_instance" "guestbook_rds_db" {
  engine                     = "mysql"
  engine_version             = "8.0.35"
  db_name                    = "mydb"
  multi_az                   = false
  identifier                 = "guestbook-db"
  username                   = var.db_username
  password                   = var.db_password
  instance_class             = "db.t3.micro"
  storage_type               = "gp2"
  allocated_storage          = 20
  db_subnet_group_name       = aws_db_subnet_group.RDS_db_subnet_group.name
  publicly_accessible        = false
  vpc_security_group_ids     = [aws_security_group.RDS_security_group.id]
  availability_zone          = var.az_1
  storage_encrypted          = true
  auto_minor_version_upgrade = true
  skip_final_snapshot        = true
  tags = {
    project = var.project_tag
  }
}

# Route 53 resources
resource "aws_route53_zone" "primary" {
  name = "guestbook.csr4w.com"
  comment = "Used for Guestbook Web App. DNS for subdomain is managed here. Main domain is managed elsewhere."

  tags = {
    project = var.project_tag
  }
}

/* resource "aws_route53_record" "a_record" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "guestbook.csr4w.com"
  type    = "A"

  alias {
    name                   = 
    zone_id                = 
    evaluate_target_health = true
  }
} */

# Internet Gateway
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.VPC.id

  tags = {
    Name = "main"
  }
}