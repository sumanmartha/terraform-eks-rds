resource "aws_security_group" "eks-alb" {
  name        = "${var.cluster-name}-alb-public"
  description = "Security group allowing public traffic for the eks load balancer."
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = map (
     "Name", "${var.cluster-name}-eks-alb",
     "kubernetes.io/cluster/${var.cluster-name}", "owned",
    )
}

resource "aws_security_group_rule" "eks-alb-public-https" {
  description       = "Allow eks load balancer to communicate with public traffic securely."
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 65535
  protocol          = "tcp"
  security_group_id = aws_security_group.eks-alb.id
  to_port           = 65535
  type              = "ingress"
}

resource "aws_security_group_rule" "eks-alb--workstation" {
  description       = "Allow eks load balancer to communicate with public traffic securely."
  cidr_blocks       = ["${local.workstation-external-cidr}"]
  from_port         = 65535
  protocol          = "tcp"
  security_group_id = aws_security_group.eks-alb.id
  to_port           = 65535
  type              = "ingress"
}