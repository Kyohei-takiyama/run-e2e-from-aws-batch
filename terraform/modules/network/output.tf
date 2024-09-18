output "vpc_id" {
  value = aws_vpc.this.id
}

output "private_subnets" {
  value = aws_subnet.private.id
}

output "nat_gateway_id" {
  value = aws_nat_gateway.main.id
}

output "security_group_id" {
  value = aws_security_group.batch.id
}
