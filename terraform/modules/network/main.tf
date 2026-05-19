////////  The VPC  /////////

resource "aws_vpc" "main" {
    cidr_block = "10.0.0.0/16"
    enable_dns_hostnames = true
    enable_dns_support = true
    tags = {
        Name = "${var.project_name}-vpc"
  }
}


////////  Public Subnets (LB)  /////////


resource "aws_subnet" "public_a" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "${var.aws_region}a"
    map_public_ip_on_launch = true
    tags = {
        Name = "${var.project_name}-public-a"
    }
}

resource "aws_subnet" "public_b" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.2.0/24"
    availability_zone = "${var.aws_region}b"
    map_public_ip_on_launch = true
    tags = {
        Name = "${var.project_name}-public-b"
    }

}


////////  Private App Subnets (EC2)  /////////


resource "aws_subnet" "private_app_a" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.3.0/24"
    availability_zone = "${var.aws_region}a"
    tags = {
        Name = "${var.project_name}-private-app-a"
    }
}

resource "aws_subnet" "private_app_b" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.4.0/24"
    availability_zone = "${var.aws_region}b"
    tags = {
        Name = "${var.project_name}-private-app-b"
    }
}


////////  Private Data Subnets (RDS & REDIS)  /////////


resource "aws_subnet" "private_data_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.5.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "${var.project_name}-private-data-a"
  }
}

resource "aws_subnet" "private_data_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.6.0/24"
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = "${var.project_name}-private-data-b"
  }
}


////////  IGW + Elastic IP + NAT Gateway  /////////


resource "aws_internet_gateway" "main" {
    vpc_id = aws_vpc.main.id
    tags = {
        Name = "${var.project_name}-igw"
    }
}

resource "aws_eip" "nat" {
    domain = "vpc"
    tags = {
        Name = "${var.project_name}-nat-eip"
    }
}

resource "aws_nat_gateway" "main" {
    allocation_id = aws_eip.nat.id
    subnet_id = aws_subnet.public_a.id
    tags = {
        Name = "${var.project_name}-nat"
    }
    # Good Behavior
    depends_on = [aws_internet_gateway.main]
}


////////  Route Table  /////////


resource "aws_route_table" "public_app" {
    vpc_id = aws_vpc.main.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.main.id
 
   }
    tags = {
        Name = "${var.project_name}-rt-public-app"
    }
}

resource "aws_route_table" "private_app" {
    vpc_id = aws_vpc.main.id
    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = aws_nat_gateway.main.id
    }
    tags = {
      Name = "${var.project_name}-rt-private-app"
    }
}

resource "aws_route_table" "private_data" {
    vpc_id = aws_vpc.main.id
    tags = {
      Name = "${var.project_name}-rt-private-data"
    }
}

////////  Route Table Associations  /////////

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public_app.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public_app.id
}

resource "aws_route_table_association" "private_app_a" {
  subnet_id      = aws_subnet.private_app_a.id
  route_table_id = aws_route_table.private_app.id
}

resource "aws_route_table_association" "private_app_b" {
  subnet_id      = aws_subnet.private_app_b.id
  route_table_id = aws_route_table.private_app.id
}

resource "aws_route_table_association" "private_data_a" {
  subnet_id      = aws_subnet.private_data_a.id
  route_table_id = aws_route_table.private_data.id
}

resource "aws_route_table_association" "private_data_b" {
  subnet_id      = aws_subnet.private_data_b.id
  route_table_id = aws_route_table.private_data.id
}
