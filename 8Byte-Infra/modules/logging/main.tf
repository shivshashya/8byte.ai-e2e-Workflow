resource "aws_cloudwatch_log_group" "system" {
  name              = "/${var.project_name}/system"
  retention_in_days = var.cloudwatch_log_retention_days
}
resource "aws_cloudwatch_log_group" "application" {
  name              = "/${var.project_name}/application"
  retention_in_days = var.cloudwatch_log_retention_days
}
resource "aws_s3_bucket" "alb_logs" {
  bucket        = "${var.project_name}-alb-logs-${var.aws_account_id}-${var.aws_region}"
  force_destroy = false
}
resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket                  = aws_s3_bucket.alb_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_ownership_controls" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  rule { object_ownership = "BucketOwnerEnforced" }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}
resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  rule {
    id     = "expire-access-logs"
    status = "Enabled"
    filter { prefix = "alb/" }
    expiration { days = var.alb_access_log_retention_days }
  }
}
resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowAlbLogDelivery", Effect = "Allow"
        Principal = { Service = "logdelivery.elasticloadbalancing.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.alb_logs.arn}/alb/AWSLogs/${var.aws_account_id}/*"
        Condition = {
          ArnLike = { "aws:SourceArn" = "arn:aws:elasticloadbalancing:${var.aws_region}:${var.aws_account_id}:loadbalancer/*" }
        }
      },
      {
        Sid      = "DenyInsecureTransport", Effect = "Deny", Principal = "*"
        Action   = "s3:*"
        Resource = [aws_s3_bucket.alb_logs.arn, "${aws_s3_bucket.alb_logs.arn}/*"]
        Condition = {
          Bool = { "aws:SecureTransport" = "false", "aws:PrincipalIsAWSService" = "false" }
        }
      },
    ]
  })
  depends_on = [aws_s3_bucket_public_access_block.alb_logs]
}
