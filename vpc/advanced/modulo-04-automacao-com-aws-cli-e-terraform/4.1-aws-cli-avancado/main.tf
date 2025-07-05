# O AWS CLI é uma ferramenta de linha de comando e não possui recursos diretos no Terraform para sua configuração ou uso. No entanto, você pode usar o provisionador 'local-exec' para executar comandos da AWS CLI como parte de seu fluxo de trabalho do Terraform.

# Exemplo de como executar um comando AWS CLI após a criação de um recurso Terraform
resource "null_resource" "cli_advanced_example" {
  provisioner "local-exec" {
    command = "aws ec2 describe-vpcs --vpc-ids ${aws_vpc.custom_vpc.id}"
  }
}
