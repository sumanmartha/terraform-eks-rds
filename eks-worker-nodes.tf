#
# EKS Worker Nodes Resources
#  * IAM role allowing Kubernetes actions to access other AWS services
#  * EC2 Security Group to allow networking traffic
#  * Data source to fetch latest EKS worker AMI
#  * AutoScaling Launch Configuration to configure worker instances
#  * AutoScaling Group to launch worker instances
#

resource "aws_iam_role" "eks-cluster-node" {
  name = "${var.cluster-name}-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

data "template_file" "cluster-iam-role" {
  template = "${file("iam-role.json")}"
}
/*
data "template_file" "ecr-iam-role" {
  template = "${file("ecr-iam-role.json")}"
}

resource "aws_iam_policy" "ECRPolicy" {
  name        = "eks-ECR-images-Policy"
  description = "EKS ECR Policy"
  policy = "${data.template_file.ecr-iam-role.rendered}"
}

resource "aws_iam_role_policy_attachment" "eks-node-ECRPolicy" {
  role       = "${aws_iam_role.eks-cluster-node.name}"
  policy_arn = "${aws_iam_policy.ECRPolicy.arn}"
}
*/

resource "aws_iam_policy" "IngressControllerPolicy" {
  name        = "eks-IngressControllerPolicy"
  description = "EKS IngressControllerPolicy"
  policy = data.template_file.cluster-iam-role.rendered
}

resource "aws_iam_role_policy_attachment" "eks-cluster-node-IngressControllerPolicy" {
  role       = aws_iam_role.eks-cluster-node.name
  policy_arn = aws_iam_policy.IngressControllerPolicy.arn
}

resource "aws_iam_role_policy_attachment" "eks-cluster-node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks-cluster-node.name
}

resource "aws_iam_role_policy_attachment" "eks-cluster-node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks-cluster-node.name
}

resource "aws_iam_role_policy_attachment" "eks-cluster-node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks-cluster-node.name
}

resource "aws_iam_instance_profile" "eks-cluster-node" {
  name = var.cluster-name
  role = aws_iam_role.eks-cluster-node.name
}

resource "aws_security_group" "eks-cluster-node" {
  name        = "${var.cluster-name}-node"
  description = "Security group for all nodes in the cluster"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = map (
     "Name", "${var.cluster-name}-node",
     "kubernetes.io/cluster/${var.cluster-name}", "owned"
    )
}

resource "aws_security_group_rule" "eks-cluster-node-ingress-self" {
  description              = "Allow node to communicate with each other"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.eks-cluster-node.id
  source_security_group_id = aws_security_group.eks-cluster-node.id
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "eks-cluster-node-ingress-cluster" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 1025
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks-cluster-node.id
  source_security_group_id = aws_security_group.eks-cluster.id
  to_port                  = 65535
  type                     = "ingress"
}

data "aws_ami" "eks-worker" {
  filter {
    name   = "name"
    values = ["amazon-eks-node-${aws_eks_cluster.eks-cluster.version}-v*"]
  }

  most_recent = true
  owners      = ["602401143452"] # Amazon EKS AMI Account ID
}

# EKS currently documents this required userdata for EKS worker nodes to
# properly configure Kubernetes applications on the EC2 instance.
# We utilize a Terraform local here to simplify Base64 encoding this
# information into the AutoScaling Launch Configuration.
# More information: https://docs.aws.amazon.com/eks/latest/userguide/launch-workers.html
locals {
  eks-cluster-node-userdata = <<USERDATA
#!/bin/bash
set -o xtrace
/etc/eks/bootstrap.sh --apiserver-endpoint '${aws_eks_cluster.eks-cluster.endpoint}' --b64-cluster-ca '${aws_eks_cluster.eks-cluster.certificate_authority.0.data}' '${var.cluster-name}'
USERDATA
}

resource "aws_launch_configuration" "eks-cluster" {
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.eks-cluster-node.name
  image_id                    = data.aws_ami.eks-worker.id
  instance_type               = var.ec2_instance_type
  name_prefix                 = var.cluster-name
  security_groups             = [aws_security_group.eks-cluster-node.id]
  user_data_base64            = base64encode(local.eks-cluster-node-userdata)
  key_name                    = var.eks_key-pair

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "eks-cluster-node" {
  desired_capacity     = 2
  launch_configuration = aws_launch_configuration.eks-cluster.id
  max_size             = 2
  min_size             = 1
  name                 = var.cluster-name
  vpc_zone_identifier  = var.aws_private_subnet_ids
  target_group_arns    = [aws_lb_target_group.tf_eks.arn]

  tag {
      key                 = "Name"
      value               = "${var.cluster-name}-eks-workers"
      propagate_at_launch = true
    }
  tag {
      key                 = "kubernetes.io/cluster/${var.cluster-name}"
      value               = "owned"
      propagate_at_launch = true
    }
  tag {
      key                 = "k8s.io/cluster-autoscaler/${var.cluster-name}"
      value               = ""
      propagate_at_launch = true
    }
  tag {
      key                 = "k8s.io/cluster-autoscaler/enabled"
      value               = ""
      propagate_at_launch = true
    }
}