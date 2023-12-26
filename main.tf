terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.30.0"
    }
    archive = {
      source = "hashicorp/archive"
      version = "2.4.1"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"
}

provider "archive" {}

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name = "/aws/lambda/s3_lambda"
}

data "archive_file" "function_source" {
  type = "zip"
  source_dir = "app"
  output_path = "archive/my_lambda_function.zip"
}


data "aws_iam_policy_document" "assume" {

  statement {
    actions = [
      "sts:AssumeRole"
    ]
    effect = "Allow"
    principals {
      type = "Service"
      identifiers = [
        "lambda.amazonaws.com"
      ]
    }
  }

}

resource "aws_iam_role" "role" {

  assume_role_policy = data.aws_iam_policy_document.assume.json

  name = "role_for_s3_lambda"

}

resource "aws_iam_role_policy_attachment" "rpa_lambda" {

  role = aws_iam_role.role.id

  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"

}

resource "aws_lambda_function" "function" {
  function_name = "s3_lambda"
  handler = "simple_lambda.lambda_handler"
  role = aws_iam_role.role.arn
  runtime = "python3.10"
  filename = data.archive_file.function_source.output_path
  source_code_hash = data.archive_file.function_source.output_base64sha256
  depends_on = [
    aws_iam_role_policy_attachment.rpa_lambda,
    aws_cloudwatch_log_group.lambda_log_group
    ]
  tags = {
    "Name" = "s3_lambda"
  }
}

resource "aws_s3_bucket" "bucket" {

  bucket = "s3-lambda-15632876-9dba-4a34-b2e8-cf83c6d1039b"

}

resource "aws_lambda_permission" "allow_s3" {
  
  function_name = aws_lambda_function.function.function_name

  action = "lambda:InvokeFunction"

  principal = "s3.amazonaws.com"

  source_arn = aws_s3_bucket.bucket.arn

}

resource "aws_s3_bucket_notification" "bucket_notification" {

  bucket = aws_s3_bucket.bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.function.arn
    events = [
      "s3:ObjectCreated:*"
    ]
  }

  depends_on = [
    aws_lambda_permission.allow_s3
  ]

}
