# A otimização de custos é mais uma prática de gerenciamento e monitoramento do que algo diretamente provisionado pelo Terraform. No entanto, o Terraform pode ajudar a provisionar recursos de forma otimizada.

# Exemplo de provisionamento de uma instância spot
resource "aws_spot_instance_request" "cheap_instance" {
  ami           = "ami-0c55b159cbfafe1f0"
  spot_price    = "0.03"
  instance_type = "t3.micro"

  tags = {
    Name = "CheapInstance"
  }
}
