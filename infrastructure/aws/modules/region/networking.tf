###
## Security Groups
###
resource "aws_security_group" "sg_ingress" {
  name = "${var.deployment_group}-ingress-sg"
  #vpc_id = aws_vpc.aws-vpc.id
  vpc_id = var.vpc.id

  # ingress only to the port/s the tasks expose
  ingress {
    protocol         = "udp"
    from_port        = 10000
    to_port          = 10004
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # outbound all
  egress {
    protocol         = "-1"
    from_port        = 0
    to_port          = 0
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = var.deployment_group
  }
}
resource "aws_security_group" "sg_egress" {
  name   = "${var.deployment_group}-egress-sg"
  vpc_id = var.vpc.id

  # ingress only to the port/s the tasks expose
  ingress {
    protocol         = "udp"
    from_port        = 20000
    to_port          = 20004
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # outbound all
  egress {
    protocol         = "-1"
    from_port        = 0
    to_port          = 0
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = var.deployment_group
  }
}

resource "aws_security_group" "sg_movement_lb" {
  name   = "${var.deployment_group}-movement-lb-sg"
  vpc_id = var.vpc.id

  # outbound traffic not restricted
  egress {
    protocol         = "-1"
    from_port        = 0
    to_port          = 0
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    protocol         = "-1"
    from_port        = 0
    to_port          = 0
    cidr_blocks      = [var.vpc_cidr] // Inbound from network balancer CIDR
  }
  
  tags = {
    Name = var.deployment_group
  }
}
