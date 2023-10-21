###
## Base Networking - Setup networking exclusive to the base region
##   Route53 Record for API loadbalancer
###

###
## Security Groups
###
resource "aws_security_group" "sg_signaling" {
  name   = "${var.deployment_group}-signaling-sg"
  vpc_id = var.vpc.id

  # HTTP 80 in
  ingress {
    protocol         = "tcp"
    from_port        = 8080
    to_port          = 8080
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # HTTPS 443 in
  ingress {
    protocol         = "tcp"
    from_port        = 8443
    to_port          = 8443
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # 1188 in for netsocket
  ingress {
    protocol         = "tcp"
    from_port        = 1188
    to_port          = 1188
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # any/any out
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

resource "aws_security_group" "sg_authentication" {
  name   = "${var.deployment_group}-authentication-sg"
  vpc_id = var.vpc.id

  # ingress only to the port/s the tasks expose
  # HTTP 80 in
  ingress {
    protocol         = "tcp"
    from_port        = 80
    to_port          = 80
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    protocol         = "tcp"
    from_port        = 443
    to_port          = 443
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

###
## Load Balancer (signaling)
###
resource "aws_lb" "lb" {
  name               = "${var.deployment_group}-signaling-lb"
  internal           = false
  load_balancer_type = "network"
  subnets            = ["${var.sn_public.id}", "${var.sn_private.id}"] # requires subnets in different AZs

  enable_deletion_protection = false

  tags = {
    Name = var.deployment_group
  }
}

resource "aws_alb_target_group" "alb_tg_alt_https" {
  name                 = "${var.deployment_group}-tg-alb-alt-https" # may need to add random id for clean destroy: ${random_id.rnd.id}
  deregistration_delay = "180"                                      # default draining wait is 5m!
  port                 = 8443
  protocol             = "TCP"
  vpc_id               = var.vpc.id
  target_type          = "ip"

  health_check {
    protocol = "TCP"
    port     = 8443
  }

  # avoid ResourceInUse during delete
  # also need to randomize the 'name' for this to work - must manually rename until then
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = var.deployment_group
  }
}

# Port for incoming media server access
resource "aws_alb_target_group" "alb_tg_netsocket" {
  name                 = "${var.deployment_group}-tg-alb-netsocket"
  deregistration_delay = "180" # default draining wait is 5m!
  port                 = 1188
  protocol             = "TCP"
  vpc_id               = var.vpc.id
  target_type          = "ip"

  health_check {
    protocol = "TCP"
    port     = 8443
  }

  # avoid ResourceInUse during delete
  # also need to randomize the 'name' for this to work - must manually rename until then
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = var.deployment_group
  }
}

/* HTTP listener forwards traffic to the target group (external)*/
resource "aws_alb_listener" "alt_https" {
  load_balancer_arn = aws_lb.lb.id
  port              = 443
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_alb_target_group.alb_tg_alt_https.id
    type             = "forward"
  }

  tags = {
    Name = var.deployment_group
  }
}
resource "aws_alb_listener" "netsocket" {
  load_balancer_arn = aws_lb.lb.id
  port              = 1188
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_alb_target_group.alb_tg_netsocket.id
    type             = "forward"
  }

  tags = {
    Name = var.deployment_group
  }
}

# Set DNS record to point to loadbalancer for API server
resource "aws_route53_record" "loadbalancer" {
  name    = "api.${var.dns_base}"
  zone_id = data.aws_route53_zone.hosted_zone.zone_id
  type    = "A"

  alias {
    name                   = aws_lb.lb.dns_name
    zone_id                = aws_lb.lb.zone_id
    evaluate_target_health = true
  }
}

# Set quick site DNS record to point to loadbalancer for API server
resource "aws_route53_record" "loadbalancer_quick" {
  name    = "api.quick.${var.dns_base}"
  zone_id = data.aws_route53_zone.hosted_zone.zone_id
  type    = "A"

  alias {
    name                   = aws_lb.lb.dns_name
    zone_id                = aws_lb.lb.zone_id
    evaluate_target_health = true
  }
}



# -----------------------------------------------
###
## Load Balancer (authentication)
###
resource "aws_lb" "auth_lb" {
  name               = "${var.deployment_group}-authentication-lb"
  internal           = false
  load_balancer_type = "network"
  subnets            = ["${var.sn_public.id}", "${var.sn_private.id}"] # requires subnets in different AZs

  enable_deletion_protection = false

  tags = {
    Name = var.deployment_group
  }
}

resource "aws_alb_target_group" "auth_alb_tg_https" {
  name                 = "${var.deployment_group}-tg-auth-https"
  deregistration_delay = "180" # default draining wait is 5m!
  port                 = 443
  protocol             = "TCP"
  vpc_id               = var.vpc.id
  target_type          = "ip"

  health_check {
    protocol = "TCP"
    port     = 443
  }

  # avoid ResourceInUse during delete
  # also need to randomize the 'name' for this to work - must manually rename until then
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = var.deployment_group
  }
}

resource "aws_alb_target_group" "auth_alb_tg_http" {
  name                 = "${var.deployment_group}-tg-auth-http" # may need to add random id for clean destroy: ${random_id.rnd.id}
  deregistration_delay = "180"                                  # default draining wait is 5m!
  port                 = 80
  protocol             = "TCP"
  vpc_id               = var.vpc.id
  target_type          = "ip"

  # avoid ResourceInUse during delete
  # also need to randomize the 'name' for this to work - must manually rename until then
  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = var.deployment_group
  }
}

/* ssl listener forwards traffic to the target group*/
resource "aws_alb_listener" "auth_https" {
  load_balancer_arn = aws_lb.auth_lb.id
  port              = 443
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_alb_target_group.auth_alb_tg_https.id
    type             = "forward"
  }

  tags = {
    Name = var.deployment_group
  }
}

/* HTTP listener forwards traffic to the target group*/
resource "aws_alb_listener" "auth_http" {
  load_balancer_arn = aws_lb.auth_lb.id
  port              = 80
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_alb_target_group.auth_alb_tg_http.id
    type             = "forward"
  }

  tags = {
    Name = var.deployment_group
  }
}

# Set DNS record to point to loadbalancer for authentication
resource "aws_route53_record" "auth_loadbalancer" {
  name    = "i.${var.dns_base}"
  zone_id = data.aws_route53_zone.hosted_zone.zone_id
  type    = "A"

  alias {
    name                   = aws_lb.auth_lb.dns_name
    zone_id                = aws_lb.auth_lb.zone_id
    evaluate_target_health = true
  }
}