variable "vpc_cidr_block" {
  type    = string
  default = "10.10.0.0/16"
}

variable "aws_region" {
}

variable "prefix" {
}

variable "availability_zones" {
  type    = list(string)
  default = []
}

locals {
  private_subnets = "10.10.2.0/24"
  public_subnets  = "10.10.1.0/24"
}
