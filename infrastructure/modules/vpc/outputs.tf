output "vpc_id" {
  description = "ID de la VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "Bloque CIDR de la VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "IDs de las subredes públicas."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs de las subredes privadas."
  value       = aws_subnet.private[*].id
}

output "nat_gateway_id" {
  description = "ID del NAT Gateway."
  value       = aws_nat_gateway.this.id
}

output "internet_gateway_id" {
  description = "ID del Internet Gateway."
  value       = aws_internet_gateway.this.id
}
