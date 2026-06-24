# Internal NLB
resource "aws_lb" "internal_nlb" {
  #checkov:skip=CKV_AWS_91: Ensure the ELBv2 (Application/Network) has access logging enabled
  #checkov:skip=CKV_AWS_150: Ensure that Load Balancer has deletion protection enabled
  #checkov:skip=CKV_AWS_152: Ensure that Load Balancer (Network/Gateway) has cross-zone load balancing enabled
  name                       = "${var.ingress_lb_group_name}-internal"
  internal                   = true
  load_balancer_type         = "network"
  enable_deletion_protection = false


  subnet_mapping {
    subnet_id = data.aws_subnets.filtered_subnets.ids[0]
  }

  subnet_mapping {
    subnet_id = data.aws_subnets.filtered_subnets.ids[1]
  }

  subnet_mapping {
    subnet_id = data.aws_subnets.filtered_subnets.ids[2]
  }

  # Attach the security group
  security_groups = [aws_security_group.internal_nlb_sg.id]

  tags = merge(
    var.tags,
    {
      "ingress_lb_group_name" = "${var.ingress_lb_group_name}-internal"
    }
  )
}


############################################
# Security Group (no inline ingress/egress)
############################################
resource "aws_security_group" "internal_nlb_sg" {
  name        = var.tenant == "" ? "ingress-internal-sg" : "${var.tenant}-internal-sg"
  description = "Security group for internal NLB"
  vpc_id      = data.aws_vpcs.filtered_vpcs.ids[0]

  tags = merge(
    var.tags,
    {
      Name = var.tenant == "" ? "ingress-internal-sg" : "${var.tenant}-internal-sg"
    }
  )
}

############################################
# Ingress: allow 443 from private ranges
############################################
resource "aws_vpc_security_group_ingress_rule" "allow_443_from_private_ranges" {
  security_group_id = aws_security_group.internal_nlb_sg.id

  description = "Allow traffic from private subnets"
  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443

  cidr_ipv4 = "10.0.0.0/8"
}

resource "aws_vpc_security_group_ingress_rule" "allow_443_from_cgnat" {
  security_group_id = aws_security_group.internal_nlb_sg.id

  description = "Allow traffic from private subnets"
  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443

  cidr_ipv4 = "100.64.0.0/16"
}

resource "aws_vpc_security_group_ingress_rule" "allow_443_from_rfc1918_172" {
  security_group_id = aws_security_group.internal_nlb_sg.id

  description = "Allow traffic from private subnets"
  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443

  cidr_ipv4 = "172.16.0.0/12"
}

############################################
# Ingress: allow 443 from self (health checks)
############################################
resource "aws_vpc_security_group_ingress_rule" "allow_443_from_self" {
  security_group_id = aws_security_group.internal_nlb_sg.id

  description = "Allow traffic from NLB for health checks"
  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443

  referenced_security_group_id = aws_security_group.internal_nlb_sg.id
}

############################################
# Egress: allow all protocols/ports to private ranges
############################################
resource "aws_vpc_security_group_egress_rule" "egress_all_to_10" {
  security_group_id = aws_security_group.internal_nlb_sg.id

  description = "Allow Outbound traffic from NLB"
  ip_protocol = "-1"

  cidr_ipv4 = "10.0.0.0/8"
}

resource "aws_vpc_security_group_egress_rule" "egress_all_to_100_64" {
  security_group_id = aws_security_group.internal_nlb_sg.id

  description = "Allow Outbound traffic from NLB"
  ip_protocol = "-1"

  cidr_ipv4 = "100.64.0.0/16"
}

resource "aws_vpc_security_group_egress_rule" "egress_all_to_172_16" {
  security_group_id = aws_security_group.internal_nlb_sg.id

  description = "Allow Outbound traffic from NLB"
  ip_protocol = "-1"

  cidr_ipv4 = "172.16.0.0/12"
}
