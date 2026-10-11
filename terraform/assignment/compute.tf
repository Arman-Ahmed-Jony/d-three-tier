data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "app" {
  for_each = local.instances

  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public[each.key].id
  vpc_security_group_ids      = [aws_security_group.app.id]
  associate_public_ip_address = true
  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    instance_label    = each.value.label
    availability_zone = each.value.az
  })
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = {
    Name = "${local.name}-${each.key}"
  }
}

resource "aws_ec2_instance_state" "instance_1" {
  instance_id = aws_instance.app["instance_1"].id
  state       = var.stop_instance_1 ? "stopped" : "running"
}
