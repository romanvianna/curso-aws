resource "aws_instance" "bastion_host" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet.id
  associate_public_ip_address = true
  security_groups = [aws_security_group.allow_ssh.id]

  tags = {
    Name = "BastionHost"
  }
}
