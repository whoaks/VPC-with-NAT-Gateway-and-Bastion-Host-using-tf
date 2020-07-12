// Provide Credentials
 
provider "aws" {
region = "ap-south-1"
profile = "aks07"
}

resource "aws_vpc" "tf_vpc" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = "true"
  tags = {
    Name = "myvpc2"
  }
}

resource "aws_subnet" "tf_subnet" {
  vpc_id     = aws_vpc.tf_vpc.id
  cidr_block = "192.168.0.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = "true"

  tags = {
    Name = "sub1"
  }
}

resource "aws_subnet" "tf_subnet2" {
  vpc_id     = aws_vpc.tf_vpc.id
  cidr_block = "192.168.1.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "sub2"
  }
}

resource "aws_internet_gateway" "tf_gw" {
  vpc_id = aws_vpc.tf_vpc.id

  tags = {
    Name = "my_ig"
  }
}

resource "aws_route_table" "tf_rt" {
  vpc_id = aws_vpc.tf_vpc.id

  route {
    
gateway_id = aws_internet_gateway.tf_gw.id
    cidr_block = "0.0.0.0/0"
  }

    tags = {
    Name = "my_rt2"
  }
}

resource "aws_route_table_association" "tf_sub_a" {
  subnet_id      = aws_subnet.tf_subnet.id
  route_table_id = aws_route_table.tf_rt.id
}


// Wordpress Security Group

resource "aws_security_group" "tf_sg" {
  depends_on = [ aws_vpc.tf_vpc ]
  name        = "wpos_sg"
  vpc_id      = aws_vpc.tf_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  ingress {
      description = "ICMP"  
      from_port = -1
      to_port = -1
      protocol = "icmp"
      cidr_blocks = ["0.0.0.0/0"]
    }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "wpos_sg"
  }
}

// MYSQL Security Group

resource "aws_security_group" "tf_sg2" {
  depends_on = [ aws_vpc.tf_vpc ]
  name        = "mysql_sg"
  vpc_id      = aws_vpc.tf_vpc.id

  ingress {
    description = "MYSQL"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [ aws_security_group.tf_sg.id ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mysql_sg"
  }
}

resource "aws_security_group" "tf_sg3" {
  depends_on = [ aws_vpc.tf_vpc ]
  name        = "bh_sg"
  vpc_id      = aws_vpc.tf_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bh_sg"
  }
}


  resource "aws_instance" "wordpress_os" {
  ami           = "ami-7e257211"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.tf_subnet.id
  vpc_security_group_ids = [ aws_security_group.tf_sg.id ]
  key_name = "key"

  tags = {
    Name = "wordpress"
    }

}

resource "aws_instance" "database" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.tf_subnet2.id
  vpc_security_group_ids = [ aws_security_group.tf_sg2.id , aws_security_group.tf_sg3.id ]
  key_name = "key"

  tags = {
    Name = "database"
    }

}

resource "aws_instance" "bastionhost" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.tf_subnet.id
  vpc_security_group_ids = [ aws_security_group.tf_sg3.id ]
  key_name = "key"
  
    tags = {
    Name = "bastion_host_os"
    }
}

resource "aws_eip" "tf_eip" {
  depends_on = [ aws_instance.wordpress_os , aws_instance.database , aws_instance.bastionhost ]
   vpc      = true
}

resource "aws_nat_gateway" "tf_nat_gw" {
  depends_on = [ aws_eip.tf_eip ]
  allocation_id = aws_eip.tf_eip.id
  subnet_id     = aws_subnet.tf_subnet.id

  tags = {
    Name = "my_Nat_gw"
  }
}

resource "aws_route_table" "tf_nat_rt" {
  depends_on = [ aws_nat_gateway.tf_nat_gw ]
  vpc_id = aws_vpc.tf_vpc.id

  route {
    
gateway_id = aws_nat_gateway.tf_nat_gw.id
    cidr_block = "0.0.0.0/0"
  }

    tags = {
    Name = "my_nat_rt"
  }
}

resource "aws_route_table_association" "tf_sub_b" {
  depends_on = [ aws_route_table.tf_nat_rt ]
  subnet_id      = aws_subnet.tf_subnet2.id
  route_table_id = aws_route_table.tf_nat_rt.id
}

