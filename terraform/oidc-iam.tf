data "aws_iam_policy_document" "oidc-policy-document" {
  # for all resources
  statement {
    actions = [
      # ecr:GetAuthorizationTokenは全てのresourceに対して許可する必要がある
      "ecr:GetAuthorizationToken",
    ]
    resources = ["*"]
  }

  # for s3
  statement {
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketVersioning",
      "s3:GetBucketLocation",
      "s3:GetBucketPolicy",
      "s3:ListBucket",
      "s3:ListBucketVersions",
      "s3:ListBucketMultipartUploads",
      "s3:ListMultipartUploadParts",
      "s3:AbortMultipartUpload",
      "s3:CreateBucket",
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:PutObjectVersionAcl",
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
      "s3:DeleteBucket",
      "s3:DeleteBucketPolicy",
      "s3:PutBucketPolicy",
      "s3:PutBucketVersioning",
      "s3:PutBucketAcl",
      "s3:PutBucketPublicAccessBlock",
      "s3:PutBucketRequestPayment",
      "s3:PutBucketLogging",
      "s3:PutBucketNotification",
      "s3:PutBucketTagging",
      "s3:PutBucketWebsite",
      "s3:PutAccelerateConfiguration",
      "s3:GetAccelerateConfiguration",
      "s3:PutBucketCORS",
      "s3:GetBucketCORS",
      "s3:DeleteBucketCORS",
      "s3:GetBucketTagging",
      "s3:GetBucketLogging",
      "s3:GetBucketPublicAccessBlock",
      "s3:GetBucketWebsite",
      "s3:GetBucketAcl",
      "s3:GetBucketPolicy",
      "s3:GetBucketRequestPayment",
      "s3:GetBucketNotification",
      "s3:GetBucketPolicyStatus"
    ]
    resources = [
      "*"
    ]
  }

  # for ecr
  statement {
    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:UploadLayerPart",
      "ecr:PutImage",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:BatchCheckLayerAvailability"
    ]
    resources = [
      "arn:aws:ecr:${var.aws_region}:${var.aws_account_id}:repository/${var.ecr_repository_name}-repository",
    ]
  }
}

module "oicd-iam-policy" {
  source = "terraform-aws-modules/iam/aws//modules/iam-policy"
  name   = "oidc-policy-gha-${var.prefix}"
  path   = "/"
  policy = data.aws_iam_policy_document.oidc-policy-document.json
}

# https://docs.github.com/ja/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services#adding-permissions-settings
# https://registry.terraform.io/modules/terraform-aws-modules/iam/aws/latest/submodules/iam-assumable-role-with-oidc
module "oidc-iam-role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "5.30.0"

  create_role  = true
  role_name    = "oidc-iam-role-gha-${var.prefix}"
  provider_url = var.github-oidc-endpoint
  oidc_subjects_with_wildcards = [
    "repo:${var.github_owner}/${var.github_repo}:*",
  ]

  role_policy_arns = [
    module.oicd-iam-policy.arn
  ]
}
