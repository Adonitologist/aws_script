terraform {
  backend "s3" {
    bucket         = "juaneslava-terraform-state-2026"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# 1. DynamoDB Definition
resource "aws_dynamodb_table" "counter_table" {
  name         = "cloud-resume-counter"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# 2. Dynamic Lambda Archive and Function Definition
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/backend"
  output_path = "${path.module}/lambda_function_payload.zip"
}

resource "aws_lambda_function" "resume_counter_lambda" {
  function_name    = "cloud-resume-counter-api"
  role             = "arn:aws:iam::154932391641:role/service-role/cloud-resume-counter-api-role-qg1yriwm"
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.13"
  
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}

# 3. HTTP API Gateway Definition
resource "aws_apigatewayv2_api" "resume_api" {
  name          = "cloud-resume-resume-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_headers = ["content-type"]
    allow_methods = ["GET", "OPTIONS"]
    allow_origins = ["*"]
  }
}

# 4. API Gateway Integration with Lambda
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.resume_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.resume_counter_lambda.invoke_arn
}

# 5. API Gateway Route Configuration
resource "aws_apigatewayv2_route" "counter_route" {
  api_id    = aws_apigatewayv2_api.resume_api.id
  route_key = "GET /counter"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# 6. Security Permission for API Gateway to invoke Lambda
resource "aws_lambda_permission" "api_gateway_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.resume_counter_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.resume_api.execution_arn}/*/*"
}

# ==========================================
# PHASE 2: FRONTEND S3 + CLOUDFRONT DISTRIBUTION
# ==========================================

provider "aws" {
  alias  = "stockholm"
  region = "eu-north-1"
}

# 7. S3 Bucket for Static Website Files
resource "aws_s3_bucket" "resume_bucket" {
  provider      = aws.stockholm
  bucket        = "juaneslava-cloud-resume-2026"
  force_destroy = false
}

# 8. CloudFront Origin Access Control (OAC) for secure S3 connectivity
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "s3-resume-oac"
  description                       = "OAC Protocol for locking down resume storage bucket access"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# 9. CloudFront Global Content Delivery Network Distribution
resource "aws_cloudfront_distribution" "resume_cdn" {
  enabled             = true
  default_root_object = "index.html"

  origin {
    domain_name              = aws_s3_bucket.resume_bucket.bucket_regional_domain_name
    origin_id                = "S3-.html-Resume-Hosting"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-.html-Resume-Hosting"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# 10. S3 Bucket Policy allowing reads strictly from CloudFront CDN
resource "aws_s3_bucket_policy" "allow_access_from_cloudfront" {
  provider = aws.stockholm 
  bucket   = aws_s3_bucket.resume_bucket.id
  policy   = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipalReadOnly"
        Effect    = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.resume_bucket.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.resume_cdn.arn
          }
        }
      }
    ]
  })
}

# ==========================================
# PHASE 3: CI/CD AUTOMATION (OIDC AUTHENTICATION)
# ==========================================

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1c58a3a8518e8759bf075b76b750d4f2df264fcd"]
}

resource "aws_iam_role" "github_actions_role" {
  name = "github-actions-cloud-resume-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:Adonitologist/aws_script:*"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "github_actions_policy" {
  name = "github-actions-deploy-policy"
  role = aws_iam_role.github_actions_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::juaneslava-cloud-resume-2026",
          "arn:aws:s3:::juaneslava-cloud-resume-2026/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation"
        ]
        Resource = "arn:aws:cloudfront::154932391641:distribution/E3CSQJMYF4ECSE"
      }
    ]
  })
}

# S3 Bucket created dynamically to manage remote infrastructure state data safely
resource "aws_s3_bucket" "terraform_state" {
  bucket        = "juaneslava-terraform-state-2026"
  force_destroy = false
}

output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions_role.arn
  description = "The target IAM Role ARN for the GitHub Actions workflow configuration"
}


