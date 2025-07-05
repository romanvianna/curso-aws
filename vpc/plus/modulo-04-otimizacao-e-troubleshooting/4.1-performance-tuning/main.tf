# Otimização de desempenho geralmente envolve monitoramento e ajustes manuais ou scripts. O Terraform pode provisionar os recursos, mas o tuning em si é mais operacional.

# Exemplo de provisionamento de uma instância com ENI otimizada
resource "aws_instance" "optimized_instance" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "c5.large"
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    Name = "OptimizedInstance"
  }
}
