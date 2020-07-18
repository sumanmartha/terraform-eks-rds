variable "eks_instance_type" {
	type = string
	default = "c5.large"
}

variable "eks_key-pair" {
  type = string
}

variable "eks_version" {
	type = string
	default = "1.15"
}

variable "cluster-name" {
  default = "eks-dev"
  type    = string
}

variable "aws_public_subnet_ids" {
  type    = list
}

variable "aws_private_subnet_ids" {
  type    = list
}

variable "eks_allow_port" {
  type    = number
}
