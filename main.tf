provider "aws" {
  region = "us-west-1"
}

data "aws_region" "current" {}

variable vpc_id {
  type        = string
  description = "The VPC ID"
}

resource "aws_ecr_repository" "prowler" {
  name = "securityhub-prowler-ecr"
}

locals {
  prowler_repo_endpoint = split("/", aws_ecr_repository.prowler.repository_url)[0]
}

resource "null_resource" "build_image" {
  provisioner "local-exec" {
    command = <<EOF
      set -ex
      echo "--- SecurityHub Prowler Docker image ---"
      aws ecr get-login-password --region ${data.aws_region.current.name} | \
      docker login --username AWS --password-stdin ${local.prowler_repo_endpoint} && \
      docker build -t securityhub-prowler ${path.module}/prowler --platform linux/amd64 && \
      docker tag securityhub-prowler:latest ${aws_ecr_repository.prowler.repository_url}:latest
      docker push ${aws_ecr_repository.prowler.repository_url}:latest
      EOF
  }
}

resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "ecs_task_role_policy" {
  name   = "ecs_task_role_policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "dynamodb:PutItem"
        ]
        Resource = "*"
      },
      {
        "Action": [
          "securityhub:BatchImportFindings",
          "securityhub:GetFindings"
        ],
        "Effect": "Allow",
        "Resource": "*"
      },
      {
        "Action": [
          "acm:describecertificate",
          "acm:listcertificates",
          "apigateway:get",
          "autoscaling:describe*",
          "cloudformation:describestack*",
          "cloudformation:getstackpolicy",
          "cloudformation:gettemplate",
          "cloudformation:liststack*",
          "cloudfront:get*",
          "cloudfront:list*",
          "cloudtrail:describetrails",
          "cloudtrail:geteventselectors",
          "cloudtrail:gettrailstatus",
          "cloudtrail:listtags",
          "cloudwatch:describe*",
          "codecommit:batchgetrepositories",
          "codecommit:getbranch",
          "codecommit:getobjectidentifier",
          "codecommit:getrepository",
          "codecommit:list*",
          "codedeploy:batch*",
          "codedeploy:get*",
          "codedeploy:list*",
          "config:deliver*",
          "config:describe*",
          "config:get*",
          "datapipeline:describeobjects",
          "datapipeline:describepipelines",
          "datapipeline:evaluateexpression",
          "datapipeline:getpipelinedefinition",
          "datapipeline:listpipelines",
          "datapipeline:queryobjects",
          "datapipeline:validatepipelinedefinition",
          "directconnect:describe*",
          "dynamodb:listtables",
          "ec2:describe*",
          "ecr:describe*",
          "ecs:describe*",
          "ecs:list*",
          "elasticache:describe*",
          "elasticbeanstalk:describe*",
          "elasticloadbalancing:describe*",
          "elasticmapreduce:describejobflows",
          "elasticmapreduce:listclusters",
          "es:describeelasticsearchdomainconfig",
          "es:listdomainnames",
          "firehose:describe*",
          "firehose:list*",
          "glacier:listvaults",
          "guardduty:listdetectors",
          "iam:generatecredentialreport",
          "iam:get*",
          "iam:list*",
          "kms:describe*",
          "kms:get*",
          "kms:list*",
          "lambda:getpolicy",
          "lambda:listfunctions",
          "logs:DescribeLogGroups",
          "logs:DescribeMetricFilters",
          "rds:describe*",
          "rds:downloaddblogfileportion",
          "rds:listtagsforresource",
          "redshift:describe*",
          "route53:getchange",
          "route53:getcheckeripranges",
          "route53:getgeolocation",
          "route53:gethealthcheck",
          "route53:gethealthcheckcount",
          "route53:gethealthchecklastfailurereason",
          "route53:gethostedzone",
          "route53:gethostedzonecount",
          "route53:getreusabledelegationset",
          "route53:listgeolocations",
          "route53:listhealthchecks",
          "route53:listhostedzones",
          "route53:listhostedzonesbyname",
          "route53:listqueryloggingconfigs",
          "route53:listresourcerecordsets",
          "route53:listreusabledelegationsets",
          "route53:listtagsforresource",
          "route53:listtagsforresources",
          "route53domains:getdomaindetail",
          "route53domains:getoperationdetail",
          "route53domains:listdomains",
          "route53domains:listoperations",
          "route53domains:listtagsfordomain",
          "s3:getbucket*",
          "s3:getlifecycleconfiguration",
          "s3:getobjectacl",
          "s3:getobjectversionacl",
          "s3:listallmybuckets",
          "sdb:domainmetadata",
          "sdb:listdomains",
          "ses:getidentitydkimattributes",
          "ses:getidentityverificationattributes",
          "ses:listidentities",
          "ses:listverifiedemailaddresses",
          "ses:sendemail",
          "sns:gettopicattributes",
          "sns:listsubscriptionsbytopic",
          "sns:listtopics",
          "sqs:getqueueattributes",
          "sqs:listqueues",
          "support:describetrustedadvisorchecks",
          "tag:getresources",
          "tag:gettagkeys"
        ],
        "Resource": "*",
        "Effect": "Allow",
        "Sid": "AllowMoreReadForProwler"
      },
      {
        "Effect": "Allow",
        "Action": [
          "apigateway:GET"
        ],
        "Resource": [
          "arn:aws:apigateway:*::/restapis/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role" "ecs_task_role" {
  name = "ecs_task_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_role_policy" {
  policy_arn = aws_iam_policy.ecs_task_role_policy.arn
  role       = aws_iam_role.ecs_task_role.name
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.ecs_execution_role.name
}

resource "aws_security_group" "https_sg" {
  name_prefix = "securityhub-prowler-sg"
  description = "Security Group for HTTPS traffic"
  vpc_id      = var.vpc_id

  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

output "ecs_execution_role_arn" {
  value = aws_iam_role.ecs_execution_role.arn
}

output "ecs_execution_role_policy_arn" {
  value = aws_iam_role_policy_attachment.ecs_execution_role_policy_attachment.policy_arn
}

output "ecs_task_role_arn" {
  value = aws_iam_role.ecs_task_role.arn
}

output "https_sg_id" {
  value = aws_security_group.https_sg.id
}
