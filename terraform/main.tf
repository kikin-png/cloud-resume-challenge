# 1. Specify the Provider (The "Connector" to AWS)
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1" # You can change this to your preferred region
}

# 2. Create the S3 Bucket
resource "aws_s3_bucket" "resume_bucket" {
  bucket = "my-cloud-resume-espregante-2026" # Must be globally unique!
}

# 3. Enable Static Website Hosting
resource "aws_s3_bucket_website_configuration" "resume_host" {
  bucket = aws_s3_bucket.resume_bucket.id

  index_document {
    suffix = "index.html"
  }
}

# 4. Output the URL so we can find it easily
output "website_url" {
  value = aws_s3_bucket_website_configuration.resume_host.website_endpoint
}

# 1. Turn off the "Block all public access" setting
resource "aws_s3_bucket_public_access_block" "resume_access" {
  bucket = aws_s3_bucket.resume_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# 2. Create a "Bucket Policy" that allows everyone to "Read" the files
resource "aws_s3_bucket_policy" "allow_public_read" {
  bucket = aws_s3_bucket.resume_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource = "${aws_s3_bucket.resume_bucket.arn}/*"
      },
    ]
  })

  # This "depends_on" ensures the block is removed before we apply the policy
  depends_on = [aws_s3_bucket_public_access_block.resume_access]
}
 
 # 1. Create the DynamoDB Table
resource "aws_dynamodb_table" "visitor_counter" {
  name           = "cloud-resume-stats"
  billing_mode   = "PAY_PER_REQUEST" # Very cheap for projects!
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S" # S stands for String
  }
}

# 2. Add the initial "0" count so the code doesn't crash
resource "aws_dynamodb_table_item" "initial_count" {
  table_name = aws_dynamodb_table.visitor_counter.name
  hash_key   = aws_dynamodb_table.visitor_counter.hash_key

  item = <<ITEM
{
  "id": {"S": "0"},
  "visitors": {"N": "1"}
}
ITEM
}

# 1. Create a ZIP file of your Python code
data "archive_file" "zip_the_python_code" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/"
  output_path = "${path.module}/lambda/func.zip"
}

# 2. Create the IAM Role (The Lambda's "ID Card")
resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# 3. Create the Lambda Function
resource "aws_lambda_function" "myfunc" {
  filename      = "${path.module}/lambda/func.zip"
  function_name = "myfunc"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "func.lambda_handler" # Point to the file and function name
  runtime       = "python3.9"

  source_code_hash = data.archive_file.zip_the_python_code.output_base64sha256
}

# 1. Define the Permission Policy
resource "aws_iam_policy" "iam_policy_for_resume_project" {
  name        = "aws_iam_policy_for_resume_project"
  path        = "/"
  description = "AWS IAM Policy for managing aws lambda role"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ]
        Resource = "arn:aws:dynamodb:*:*:table/cloud-resume-stats"
        Effect   = "Allow"
      },
    ]
  })
}

# 2. Attach the Policy to the Role
resource "aws_iam_role_policy_attachment" "attach_iam_policy_to_iam_role" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.iam_policy_for_resume_project.arn
}

# 3. Create Lambda Function URL for direct invocation
resource "aws_lambda_function_url" "myfunc_url" {
  function_name          = aws_lambda_function.myfunc.function_name
  authorization_type     = "NONE"
  cors {
    allow_origins = ["*"]
    allow_methods = ["*"]
    allow_headers = ["Content-Type"]
  }
}

# Output the Lambda Function URL
output "lambda_url" {
  value = aws_lambda_function_url.myfunc_url.function_url
  description = "Lambda Function URL for calling the visitor counter"
}
