data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical

}


resource "aws_security_group" "nasrsg" {
  description = "Allow SSH and HTTP inbound traffic"
  vpc_id = var.vpc_id

  ingress {
    description      = "SSH from Anywhere"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = [var.allow_all_ipv4_cidr_blocks]
    ipv6_cidr_blocks = [var.allow_all_ipv6_cidr_blocks]
  }

  ingress {
    description      = "HTTP from Anywhere"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = [var.allow_all_ipv4_cidr_blocks]
    ipv6_cidr_blocks = [var.allow_all_ipv6_cidr_blocks]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = [var.allow_all_ipv4_cidr_blocks]
    ipv6_cidr_blocks = [var.allow_all_ipv6_cidr_blocks]
  }

  tags = {
    Name = "allow_ssh_http"
  }
}

resource "aws_instance" "nasr-ec2" {
  ami = coalesce(var.ec2-ami, data.aws_ami.ubuntu.id)
  instance_type = var.instance_type
  subnet_id = var.subnet_id
  associate_public_ip_address = var.is_public
  vpc_security_group_ids = [aws_security_group.nasrsg.id]
  key_name = var.key-name

  provisioner "local-exec" {
    command = var.is_public ? "echo public-ip-${var.item-count} ${self.public_ip} >> all-ips.txt" : "echo private-ip$-${var.item-count} ${self.private_ip} >> all-ips.txt"
  }

  provisioner "remote-exec" {

      inline = var.my-remote-commands

      connection {
        type = "ssh"
        host = var.is_public ? self.public_ip : self.private_ip
        user = "ubuntu"
        private_key = file(var.path-to-pem-file)

        bastion_host = var.is_public ? "" : var.bastion_host_ip
        bastion_user = var.is_public ? "" :  "ubuntu"
        bastion_host_key = var.is_public ? "" : file(var.path-to-pem-file)
      }
  }
}
