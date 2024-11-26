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
  vpc_id                  = aws_vpc.VPC.id
  availability_zone       = var.az_1
  cidr_block              = "10.0.0.0/28"
  map_public_ip_on_launch = true

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
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
  tags = {
    Name = "HTTP"
  }
}

# EC2 instances for web server
resource "aws_ami_copy" "amazon_linux_copy" {
  name              = "amazon-linux-2-v1.0"
  source_ami_id     = "ami-0166fe664262f664c"
  source_ami_region = "us-east-1"
  description       = "Amazon Linux 2 v1.0"
  tags = {
    Version = "v1.0"
    project = var.project_tag
  }
}

resource "aws_instance" "web_server_1" {
  ami                         = aws_ami_copy.amazon_linux_copy.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.EC2_web1.id
  vpc_security_group_ids      = [aws_security_group.EC2_security_group.id]
  key_name                    = var.key_name
  associate_public_ip_address = true
  tags = {
    Name    = "Web-Server-1"
    project = var.project_tag
  }
}

resource "aws_instance" "web_server_2" {
  ami                         = aws_ami_copy.amazon_linux_copy.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.EC2_web2.id
  vpc_security_group_ids      = [aws_security_group.EC2_security_group.id]
  key_name                    = var.key_name
  associate_public_ip_address = true
  tags = {
    Name    = "Web-Server-2"
    project = var.project_tag
  }
}

# Security Group for Ansible 
resource "aws_security_group" "Ansible_security_group" {
  name        = "Ansible-SG"
  description = "Ansible-SG"
  vpc_id      = aws_vpc.VPC.id

  tags = {
    Name    = "AnsibleSG"
    project = var.project_tag
  }
}

# Security Group Rules for Ansible
resource "aws_vpc_security_group_ingress_rule" "http_ansible" {
  security_group_id = aws_security_group.Ansible_security_group.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
  tags = {
    Name = "HTTP"
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
  name    = "guestbook.csr4w.com"
  comment = "Used for Guestbook Web App. DNS for subdomain is managed here. Main domain is managed elsewhere."

  tags = {
    project = var.project_tag
  }
}

resource "aws_route53_record" "a_record" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "guestbook.csr4w.com"
  type    = "A"
  ttl     = 300
  records = [aws_eip.elastic_ip.public_ip]
}

# Elastic IP resources
resource "aws_eip" "elastic_ip" {
  instance = aws_instance.web_server_1.id
  domain   = "vpc"

  tags = {
    project = var.project_tag
  }
}

# Internet Gateway
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.VPC.id

  tags = {
    Name = "main"
  }
}

# Route Table resources
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.VPC.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }

  tags = {
    Name    = "guestbookapp_public_route_table"
    project = var.project_tag
  }
}

resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.EC2_web1.id
  route_table_id = aws_route_table.public_route_table.id
}