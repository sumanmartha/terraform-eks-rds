resource "aws_alb" "eks-alb" {
  name            = "${var.cluster-name}-alb"
  subnets         = var.aws_public_subnet_ids
  security_groups = [aws_security_group.eks-cluster-node.id, aws_security_group.eks-alb.id]
  ip_address_type = "ipv4"
  
  tags = map (
     "Name", "${var.cluster-name}-alb",
     "kubernetes.io/cluster/${var.cluster-name}", "owned",
    )
}

resource "aws_lb_target_group" "tf_eks" {
  name     = "${var.cluster-name}-ingress-tg"
  port     = 30080
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    protocol            = "HTTP"
    path                = "/healthz"
    port                = 30080
    healthy_threshold   = 10
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    matcher             = 200
  }

  tags = map (
     "Name", "${var.cluster-name}-alb",
     "kubernetes.io/cluster/${var.cluster-name}", "owned",
    )
}

resource "aws_alb_listener" "eks-alb" {

  load_balancer_arn = aws_alb.eks-alb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tf_eks.arn
  }
}

