# =============================================================================
# CloudHost — s3.tf
# Private origin bucket + secure defaults + the website objects (pure IaC).
# =============================================================================

# ---------------------------------------------------------------------------
# The private origin bucket
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "site" {
  bucket = var.bucket_name
}

# Keep the bucket 100% private — the equivalent of the four
# "Block Public Access" checkboxes in the console.
resource "aws_s3_bucket_public_access_block" "site" {
  bucket                  = aws_s3_bucket.site.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versioning — recover from accidental overwrite / delete.
resource "aws_s3_bucket_versioning" "site" {
  bucket = aws_s3_bucket.site.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt every object at rest by default (SSE-S3 / AES256).
resource "aws_s3_bucket_server_side_encryption_configuration" "site" {
  bucket = aws_s3_bucket.site.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ---------------------------------------------------------------------------
# Upload the website as code — one aws_s3_object per file, with the correct
# Content-Type and a per-file-type Cache-Control. This is the "pure IaC" way;
# you could instead run `aws s3 sync` (see the deployment guide).
# ---------------------------------------------------------------------------
locals {
  website_dir = "${path.module}/website"

  mime_types = {
    "html" = "text/html; charset=utf-8"
    "css"  = "text/css; charset=utf-8"
    "js"   = "application/javascript; charset=utf-8"
    "svg"  = "image/svg+xml"
    "png"  = "image/png"
    "jpg"  = "image/jpeg"
    "jpeg" = "image/jpeg"
    "ico"  = "image/x-icon"
    "json" = "application/json"
    "txt"  = "text/plain; charset=utf-8"
  }
}

resource "aws_s3_object" "website" {
  for_each = fileset(local.website_dir, "**")

  bucket = aws_s3_bucket.site.id
  key    = each.value
  source = "${local.website_dir}/${each.value}"

  # etag = MD5 of the file, so `terraform apply` re-uploads only changed files.
  etag = filemd5("${local.website_dir}/${each.value}")

  # Look up Content-Type from the file extension; default to a safe binary type.
  content_type = lookup(
    local.mime_types,
    lower(try(regex("[^.]+$", each.value), "")),
    "application/octet-stream"
  )

  # HTML refreshes quickly; static assets cache for a year.
  cache_control = endswith(each.value, ".html") ? "public, max-age=60" : "public, max-age=31536000, immutable"
}

# ---------------------------------------------------------------------------
# Bucket policy: allow ONLY this CloudFront distribution to read objects (OAC).
# The AWS:SourceArn condition prevents any other distribution/account from
# reading the bucket — the key least-privilege control.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "site" {
  statement {
    sid    = "AllowCloudFrontServicePrincipalReadOnly"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.site.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.site.json

  # The bucket must not accept the policy until public access is locked down.
  depends_on = [aws_s3_bucket_public_access_block.site]
}
