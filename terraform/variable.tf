variable "aws_region" {
  description = "The AWS region to deploy resources."
  type        = string
  default     = "us-west-2"
}

variable "aws_account_id" {
  description = "The AWS account ID."
  type        = string
}

variable "aws_accsess_key" {
  description = "The AWS access key."
  type        = string
}

variable "aws_secret_key" {
  description = "The AWS secret key."
  type        = string
}

variable "prefix" {
  description = "The prefix to use for all resources in this module."
  type        = string
}

variable "availability_zones" {
  description = "The availability zones to use for the VPC."
  type        = list(string)
  default     = ["us-west-2a"]
}

variable "ecr_repository_name" {
  description = "The name of the ECR repository."
  type        = string
}
