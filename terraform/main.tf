data "http" "tmadmin_pubkey" {
  url = "https://raw.githubusercontent.com/legendmbah/true_markets_th/main/tmadmin_pubkey.pub"
}

resource "aws_key_pair" "tmadmin" {
  key_name   = "tmadmin-key"
  public_key = trimspace(data.http.tmadmin_pubkey.response_body)
}

resource "aws_vpc" "terra_test_vpc" {
  cidr_block = "192.168.0.0/24"

  tags = {
    Name = "Terraform-vpc"
  }
}

resource "aws_internet_gateway" "terra_gw" {
  vpc_id = aws_vpc.terra_test_vpc.id

  tags = {
    Name = "terra-gw"
  }
}

resource "aws_route_table" "terra_rt" {
  vpc_id = aws_vpc.terra_test_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.terra_gw.id
  }
}

resource "aws_subnet" "terra_pub" {
  vpc_id            = aws_vpc.terra_test_vpc.id
  cidr_block        = "192.168.0.0/26"
  availability_zone = "us-east-1b"

  tags = {
    Name = "terra-pub1"
  }
}

resource "aws_route_table_association" "terra_pub_ass" {
  subnet_id      = aws_subnet.terra_pub.id
  route_table_id = aws_route_table.terra_rt.id
}

resource "aws_security_group" "allow_web" {
  name        = "terra-sg"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.terra_test_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "true_markets_thvm" {
  count                       = var.server_count
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.terra_pub.id
  key_name                    = aws_key_pair.tmadmin.key_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.allow_web.id]

  root_block_device {
    volume_size = 20
    volume_type = "gp2"
  }

  user_data = <<EOF
#!/bin/bash
useradd -m ${var.ssh_user}
echo "${var.ssh_user}:${var.ssh_password}" | chpasswd
echo 'tmadmin ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/tmadmin
chmod 440 /etc/sudoers.d/tmadmin

mkdir -p /home/${var.ssh_user}/.ssh
echo "${trimspace(data.http.tmadmin_pubkey.response_body)}" > /home/${var.ssh_user}/.ssh/authorized_keys
chown -R ${var.ssh_user}:${var.ssh_user} /home/${var.ssh_user}/.ssh
chmod 700 /home/${var.ssh_user}/.ssh
chmod 600 /home/${var.ssh_user}/.ssh/authorized_keys

# Apache installation and hostname setup
sudo hostnamectl set-hostname true_markets_thvm
sudo yum install -y httpd
sudo systemctl start httpd
sudo systemctl enable httpd
sudo bash -c 'echo "I love terraform" > /var/www/html/index.html'
chown -R ${var.ssh_user}:${var.ssh_user} /home/${var.ssh_user}/.ssh
chmod 700 /home/${var.ssh_user}/.ssh
chmod 600 /home/${var.ssh_user}/.ssh/authorized_keys
EOF

  tags = {
    Name = "true_markets_thvm-${format("%02d", count.index + 1)}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "null_resource" "generate_inventory" {
  depends_on = [aws_instance.true_markets_thvm]

  provisioner "local-exec" {
    command = join("\n", concat([
      "echo '[true_markets_thvm]' > ../ansible/inventory.yml",
    ],
    [for ip in aws_instance.true_markets_thvm[*].public_ip : "echo \"${ip} ansible_user=${var.ssh_user}\" >> ../ansible/inventory.yml"],
    [
      "echo '' >> ../ansible/inventory.yml",
      "echo '[true_markets_thvm:vars]' >> ../ansible/inventory.yml",
      "echo 'ansible_user=${var.ssh_user}' >> ../ansible/inventory.yml",
      "echo 'ansible_python_interpreter=/usr/bin/python3' >> ../ansible/inventory.yml",
      "echo 'ansible_ssh_private_key_file=/home/bmbah/tmadmin_private_key' >> ../ansible/inventory.yml",
      "echo 'ansible_ssh_common_args=-o StrictHostKeyChecking=no' >> ../ansible/inventory.yml",
    ]))
    interpreter = ["/bin/bash", "-c"]
  }
}

resource "null_resource" "ansible_post_provision" {
  depends_on = [aws_instance.true_markets_thvm, null_resource.generate_inventory]

  provisioner "local-exec" {
    command = <<EOT
      echo "Waiting 5 minutes for AWS instance(s) to stabilize..."
      sleep 300
      ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i ../ansible/inventory.yml ../ansible/proxmox_post_provision.yml
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
}