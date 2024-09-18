resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.prefix}-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = local.public_subnets
  availability_zone = var.availability_zones[0]

  tags = {
    Name = "${var.prefix}-public-subnet"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = local.private_subnets
  availability_zone = var.availability_zones[0]

  tags = {
    Name = "${var.prefix}-private-subnet"
  }
}

########
# Internet Gateway
#########
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.this.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.prefix}-private-rt"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}


#########
# Elastic IP
#########

resource "aws_eip" "this" {
  domain = "vpc"

  tags = {
    Name = "${var.prefix}-eip"
  }
}

#########
# NAT Gateway
#########

resource "aws_nat_gateway" "main" {

  allocation_id = aws_eip.this.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "${var.prefix}-nat-gateway"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.prefix}-private-rt"
  }
}

resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}


#########
# Security Group
#########

resource "aws_security_group" "batch" {
  vpc_id = aws_vpc.this.id
  name   = "${var.prefix}-batch"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# # security group for vpc endpoint
resource "aws_security_group" "vpc_endpoint" {
  name   = "${var.prefix}-vpc-endpoint"
  vpc_id = aws_vpc.this.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }
}

# # https://zenn.dev/yoshinori_satoh/articles/ecs-fargate-vpc-endpoint
# #########
# # VPC Endpoint
# #########
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id             = aws_vpc.this.id
  service_name       = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = [aws_subnet.private.id]
  security_group_ids = [aws_security_group.vpc_endpoint.id]

  tags = {
    Name = "${var.prefix}-ecr-dkr-vpce"
  }
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private.id]
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.prefix}-ecr-api-vpce"
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = {
    Name = "${var.prefix}-s3-vpce"
  }
}
