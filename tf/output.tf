output "public_subnets" {
  value = aws_subnet.public_subnet[*].id
}

output "private_subnets" {
  value = aws_subnet.private_subnet[*].id
}

output "alb_sg_group" {
  value = aws_security_group.alb_sg_group.id
}

output "instance_sg_group" {
  value = aws_security_group.instance_sg_group.id
}

output "vpc" {
  value = aws_vpc.vpc.id
}