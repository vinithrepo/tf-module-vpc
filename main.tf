resource "aws_vpc" "main" {
  cidr_block = var.cidr
  tags = {
    Name = "dev"
  }

}
module "subnets" {
  source = "./subnets"
  for_each = var.subnets
  subnets = each.value
  vpc_id = aws_vpc.main.id
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main"
  }
}

resource "aws_route" "igw" {
  for_each = lookup(lookup(module.subnets, "public", null), "route_table_ids", null)
  route_table_id            = each.value["id"]
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.igw.id
}
 # in below block i used count_length because given input as list (locals input coming as list)
resource "aws_eip" "ngw" {
  #for_each = lookup(lookup(module.subnets, "public", null), "subnet_ids", null)
  #domain   = "vpc"
  count = length(local.public_subnet_ids)
  domain = "vpc"
}
resource "aws_nat_gateway" "ngw" {
  #for_each = lookup(lookup(module.subnets, "public", null), "subnet_ids", null)
  #allocation_id = lookup(lookup(aws_eip.ngw, each.key, null ),"id", null )
  #subnet_id     = each.value["id"]
  count = length(local.public_subnet_ids)
  allocation_id = element(aws_eip.ngw.*.id, count.index )
  subnet_id = element(local.public_subnet_ids, count.index)

}

resource "aws_route" "ngw" {
  #for_each = lookup(lookup(module.subnets, "public", null), "route_table_ids", null)
  #route_table_id            = each.value["id"]
  #destination_cidr_block = "0.0.0.0/0"
  #gateway_id = aws_nat_gateway.ngw.id
  count = length(local.private_route_table_ids)
  route_table_id = element(local.private_route_table_ids, count.index )
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = element(aws_nat_gateway.ngw.*.id, count.index)
}

resource "aws_vpc_peering_connection" "peering" {
  peer_vpc_id   = aws_vpc.main.id
  vpc_id        = var.default_vpc_id
  auto_accept   = true
}

resource "aws_route" "peer" {
  count = length(local.private_route_table_ids)
  route_table_id = element(local.private_route_table_ids, count.index )
  destination_cidr_block = var.default_vpc_cidr
  vpc_peering_connection_id   = aws_vpc_peering_connection.peering.id
}
resource "aws_route" "default-vpc-peer-entry" {

  route_table_id = var.default_route_table_id
  destination_cidr_block = var.cidr
  vpc_peering_connection_id   = aws_vpc_peering_connection.peering.id
}

resource "aws_instance" "ec2" {
  ami = "ami-0b4f379183e5706b9"
  instance_type = "t3.micro"
  vpc_security_group_ids = [aws_security_group.allow_tls.id]
  subnet_id = local.app_subnet_ids[0]
}

resource "aws_security_group" "allow_tls" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "TLS from VPC"
    from_port   = 22
    protocol = "tcp"
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    protocol = "-1"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "allow_tls"
  }
}

