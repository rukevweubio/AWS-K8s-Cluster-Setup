
resource "aws_key_pair" "deployer" {
  key_name   = "my-local-key"
  public_key  = file("id_rsa.pub.pem")
}




resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "main-vpc"
  }
}

resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.subnet_cidr
  availability_zone = var.availability_zone
  map_public_ip_on_launch = true
  tags = {
    Name = "main-subnet"
  }
}


resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "main-igw"
  }
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = {
    Name = "main-rt"
  }
}

resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}







resource "aws_security_group" "master_sg" {
  name        = "k8s-master-sg"
  description = "Security group for Kubernetes master node"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  ingress {
    description = "Kubernetes API server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  
  }

  # Add other master-specific ports here (etcd, kube-scheduler, etc.)

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "k8s-master-sg"
  }
}

# Worker Security Group
resource "aws_security_group" "worker_sg" {
  name        = "k8s-worker-sg"
  description = "Security group for Kubernetes worker node"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

 
  ingress {
    description = "Kubelet API"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "k8s-worker-sg"
  }
}

# Master Instance
resource "aws_instance" "K8_master" {
  ami                         = var.ami_id
  instance_type               = var.master_instance_type
  subnet_id                   = aws_subnet.main.id
  vpc_security_group_ids      = [aws_security_group.master_sg.id]
  associate_public_ip_address = true
  key_name                   = aws_key_pair.deployer.key_name

  tags = {
    Name = "K8_master"
  }
}

# Worker Instance
resource "aws_instance" "K8_worker" {
  ami                         = var.ami_id
  instance_type               = var.worker_instance_type
  subnet_id                   = aws_subnet.main.id
  vpc_security_group_ids      = [aws_security_group.worker_sg.id]
  associate_public_ip_address = true
  key_name                   = aws_key_pair.deployer.key_name

  tags = {
    Name = "K8_worker"
  }
}
