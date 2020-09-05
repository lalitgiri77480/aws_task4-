// Creating Provider

provider "aws"{
 region = "ap-south-1"
 profile = "paylit"
}

// Creating VPC 

resource "aws_vpc" "main" {
  cidr_block       = "192.168.0.0/16"
  enable_dns_hostnames = "true"

  tags = {
    Name = "autoVPC"
  }
}

// Creating Subnets for public world

resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "192.168.0.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = "true"

  tags = {
    Name = "Public_Subnet-1"
  }
}

// Creating Subnets for private Access

resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "192.168.1.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "Private_Subnet-1"
  }
}

// Creating Internet Gateway for connect vpc to internet
resource "aws_internet_gateway" "MyGateWay" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "my_gateway"
  }
}

// Creating Routing Table for internet gateway so that instance can connect to outside world

resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.MyGateWay.id
  }

  tags = {
    Name = "myroute"
  }
}

// Associatings subnets with public and privates 

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.route_table.id
}
resource "aws_route_table_association" "b" {
  subnet_id     = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.route_table.id
}

//Create NAT Gateway for connect our VPC/Network to the internet world and attach this gateway to our VPC in the public network

resource "aws_eip" "nat" {
  vpc      = true
  depends_on = [aws_internet_gateway.MyGateWay,]
}

resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_subnet.id
  depends_on = [aws_internet_gateway.MyGateWay,]
  tags = {
    Name = "gw NAT"
  }
}

// Update the routing table of private subnet , so that to access the internet it uses the nat gateway created in the public subnet

resource "aws_route_table" "route_table1" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id= aws_nat_gateway.ngw.id
    
  }

  tags = {
    Name = "myroute_natgw"
  }
}

//Creating Security Group for Wordpress 

resource "aws_security_group" "mysecurity" {
  name        = "mysecurity"
  description = "Allow inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "TCP"
    from_port   = 3306
    to_port     = 3306
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
    Name = "Allowing_HTTP_SSH_TCP"
  }
}

//Creating Security group for MSQL Aurora for DataBase

resource "aws_security_group" "mysqlsecurity" {
  name        = "my_sql_security"
  description = "Allow inbound traffic mysql"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "MYSQL/Aurora"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.mysecurity.id]
  }
  

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Allowing_mysql_sg"
  }
}

// Create Security group for allow ssh.

resource "aws_security_group" "mybastionsecurity" {
  name        = "my_bastionhost_security"
  description = "Allow inbound traffic ssh "
  vpc_id      = aws_vpc.main.id


  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
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
    Name = "Allowing_mybastion_sg"
  }
}

//Creating Security group for MYSQL_Server

resource "aws_security_group" "mysqlserversecurity" {
  name        = "my_sql_server_security"
  description = "Allow inbound traffic ssh "
  vpc_id      = aws_vpc.main.id


  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.mybastionsecurity.id]
  }
  

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Allowing_mysqlserver_sg"
  }
}



//Launching an EC2 instance which has Wordpress setup already having the security group allowing port 80 so that our client can connect to our wordpress site. Also attach the key to instance for further login into it.
resource "aws_instance" "Wordpress" {
  ami           = "ami-000cbce3e1b899ebd"
  instance_type = "t2.micro"
  associate_public_ip_address = true
  availability_zone = "ap-south-1a"
  key_name= "taskkey"
  vpc_security_group_ids= [aws_security_group.mysecurity.id]
  subnet_id= aws_subnet.public_subnet.id
  tags = {
    Name = "WordPress_OS"
  }
}


//Launch an ECinstance which has MSQL setup already with secirtity group allowing port 3306 in private subnet so that our wordpress vn can connect with the same. Also attach the key with the same .

resource "aws_instance" "MYSQL" {
  ami           = "ami-08706cb5f68222d09"
  instance_type = "t2.micro"
  availability_zone = "ap-south-1b"
  key_name= "taskkey"
  vpc_security_group_ids= [aws_security_group.mysqlsecurity.id, aws_security_group.mysqlserversecurity.id]
  subnet_id= aws_subnet.private_subnet.id
  tags = {
    Name = "MYSQL_OS"
  }
}

// Create one bation_os for login inside the mysql.
resource "aws_instance" "bationhost" {
  ami           = "ami-052c08d70def0ac62"
  instance_type = "t2.micro"
  associate_public_ip_address = true
  availability_zone = "ap-south-1a"
  key_name= "taskkey"
  vpc_security_group_ids= [aws_security_group.mybastionsecurity.id]
  subnet_id= aws_subnet.public_subnet.id
  tags = {
    Name = "MyBationHost_OS"
  }
}






