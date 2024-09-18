module "network" {
  source             = "./modules/network"
  aws_region         = var.aws_region
  prefix             = var.prefix
  availability_zones = var.availability_zones
}

resource "aws_cloudwatch_log_group" "batch_job_loggroup" {
  name              = "/aws/batch/job2"
  retention_in_days = 3
}

resource "aws_ecr_repository" "this" {
  name = "${var.prefix}-repository"
}

resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Expire images older than 14 days",
        selection = {
          tagStatus   = "untagged",
          countType   = "sinceImagePushed",
          countUnit   = "days",
          countNumber = 14
        },
        action = {
          type = "expire"
        }
      }
    ]
  })

}

module "run_e2e_from_aws_batch" {
  # https://registry.terraform.io/modules/terraform-aws-modules/batch/aws/latest
  source  = "terraform-aws-modules/batch/aws"
  version = "2.0.2"

  create_instance_iam_role          = true
  instance_iam_role_name            = "${var.prefix}-instance-role"
  instance_iam_role_use_name_prefix = false
  instance_iam_role_path            = "/"

  create_service_iam_role          = true
  service_iam_role_name            = "${var.prefix}-batch-role"
  service_iam_role_use_name_prefix = false
  service_iam_role_path            = "/"

  create_spot_fleet_iam_role = false

  compute_environments = {
    run-e2e-from-aws-batch-fargate = {
      name = "${var.prefix}-fargate"

      compute_resources = {
        type      = "FARGATE"
        min_vcpus = 0
        max_vcpus = 4

        security_group_ids = [module.network.security_group_id]
        subnets            = [module.network.private_subnets]

        tags = {
          Team = var.prefix
        }
      }
    }
  }

  job_queues = {
    run-e2e-from-aws-batch-queue = {
      name                     = "${var.prefix}-queue"
      state                    = "ENABLED"
      priority                 = 1
      create_scheduling_policy = false

      tags = {
        Team = var.prefix
      }
    }
  }

  job_definitions = {
    run-e2e-from-aws-batch = {
      name                  = "${var.prefix}-job-definition"
      propagate_tags        = true
      platform_capabilities = ["FARGATE"]

      container_properties = jsonencode({
        # praywright を実行する。"npm", "run", "test" はコンテナ内で実行されるコマンド

        image = "${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.prefix}-repository:latest"

        fargatePlatformConfiguration = {
          platformVersion = "LATEST"
        }

        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = aws_cloudwatch_log_group.batch_job_loggroup.name
            awslogs-stream-prefix = "run-e2e-from-aws-batch"
          }
        }

        networkConfiguration = {
          assignPublicIp = "DISABLED"
        }

        environment = [
          {
            name  = "E2E_ARTIFACTS_BUCKET"
            value = aws_s3_bucket.e2e_artifacts.bucket
          },
          {
            name  = "AWS_REGION"
            value = var.aws_region
          }
        ]


        jobRoleArn       = module.iam_role_run_e2e_from_aws_batch_job_role.iam_role_arn
        executionRoleArn = module.iam_role_run_e2e_from_aws_batch_execution_role.iam_role_arn

        resourceRequirements = [
          { type = "VCPU", value = "1" },
          { type = "MEMORY", value = "2048" }
        ]
      })

      attempt_duration_seconds = 1801 // 60s * 30 = 30min
    }
  }

  tags = {
    Team = var.prefix
  }
}

# IAM Role Run E2E from AWS Batch Job Role
module "iam_role_run_e2e_from_aws_batch_job_role" {
  # https://registry.terraform.io/modules/terraform-aws-modules/iam/aws/latest
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "5.33.0"

  create_role                     = true
  role_name                       = "${var.prefix}-job-assume-role"
  custom_role_policy_arns         = [module.iam_policy_run_e2e_from_aws_batch_job_role.arn]
  create_custom_role_trust_policy = true
  custom_role_trust_policy        = data.aws_iam_policy_document.iam_assume_run_e2e_from_aws_batch_job_role.json

  tags = {
    Team = var.prefix
  }
}

data "aws_iam_policy_document" "iam_assume_run_e2e_from_aws_batch_job_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

module "iam_policy_run_e2e_from_aws_batch_job_role" {
  # https://registry.terraform.io/modules/terraform-aws-modules/iam/aws/latest
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "5.33.0"

  name   = "${var.prefix}-job-policy"
  policy = data.aws_iam_policy_document.iam_policy_role_run_e2e_from_aws_batch_job_role.json
}

data "aws_iam_policy_document" "iam_policy_role_run_e2e_from_aws_batch_job_role" {
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = ["*"]

  }
  statement {
    effect = "Allow"
    actions = [
      "sqs:SendMessage",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "es:ESHttpHead",
      "es:ESHttpGet",
      "es:ESHttpPost",
      "es:ESHttpPut",
    ]
    resources = ["*"]
  }
}

# IAM Role ChatGPT-Analysis-Support Batch Execution
module "iam_role_run_e2e_from_aws_batch_execution_role" {
  # https://registry.terraform.io/modules/terraform-aws-modules/iam/aws/latest
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "5.33.0"

  create_role                     = true
  role_name                       = "${var.prefix}-execution-role"
  custom_role_policy_arns         = [module.iam_policy_run_e2e_from_aws_batch_execution_role.arn]
  create_custom_role_trust_policy = true
  custom_role_trust_policy        = data.aws_iam_policy_document.iam_assume_role_run_e2e_from_aws_batch_execution_role.json

  tags = {
    Team = var.prefix
  }
}

data "aws_iam_policy_document" "iam_assume_role_run_e2e_from_aws_batch_execution_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

module "iam_policy_run_e2e_from_aws_batch_execution_role" {
  # https://registry.terraform.io/modules/terraform-aws-modules/iam/aws/latest
  source = "terraform-aws-modules/iam/aws//modules/iam-policy"

  name   = "${var.prefix}-execution-policy"
  policy = data.aws_iam_policy_document.iam_policy_run_e2e_from_aws_batch_execution_role.json
}

data "aws_iam_policy_document" "iam_policy_run_e2e_from_aws_batch_execution_role" {
  statement {
    effect = "Allow"
    actions = [
      "logs:PutLogEvents",
      "logs:CreateLogStream",
      "logs:CreateLogGroup",
      "logs:DescribeLogGroups",
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
    ]
    resources = [
      "*",
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "ecr:ListTagsForResource",
      "ecr:ListImages",
      "ecr:GetRepositoryPolicy",
      "ecr:GetLifecyclePolicyPreview",
      "ecr:GetLifecyclePolicy",
      "ecr:GetDownloadUrlForLayer",
      "ecr:DescribeRepositories",
      "ecr:DescribeImages",
      "ecr:DescribeImageScanFindings",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameters",
    ]
    resources = ["*"]
  }
}

# S3 bucket for e2e artifacts
resource "aws_s3_bucket" "e2e_artifacts" {
  bucket = "${var.prefix}-e2e-artifacts"

  tags = {
    Name = "${var.prefix}-e2e-artifacts"
  }
}

resource "aws_s3_bucket_policy" "e2e_artifacts_policy" {
  bucket = aws_s3_bucket.e2e_artifacts.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = module.iam_role_run_e2e_from_aws_batch_job_role.iam_role_arn
        }
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.e2e_artifacts.arn}/*"
      }
    ]
  })
}

resource "aws_s3_bucket_lifecycle_configuration" "e2e_artifacts_lifecycle" {
  bucket = aws_s3_bucket.e2e_artifacts.id

  rule {
    id     = "ExpireOldE2EArtifacts"
    status = "Enabled"

    expiration {
      days = 30
    }

    filter {
      prefix = "test-results/"
    }
  }
}
