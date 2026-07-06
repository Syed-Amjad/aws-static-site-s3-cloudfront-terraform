# =============================================================================
# CloudHost — variables.tf
# =============================================================================

variable "aws_region" {
  description = "AWS region for the S3 origin bucket."
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Globally-unique name for the PRIVATE origin bucket (lowercase, 3-63 chars). Use a NEW name so it does not clash with the console-created bucket."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "Bucket name must be 3-63 chars, lowercase letters, numbers, hyphens or dots."
  }
}

variable "domain_name" {
  description = "Custom subdomain served by CloudFront. An ISSUED ACM certificate for this exact name MUST already exist in us-east-1 (we reuse it). e.g. s3-demo.sillageandskin.com"
  type        = string
}

variable "default_root_object" {
  description = "Object served for the root path '/'."
  type        = string
  default     = "index.html"
}

variable "price_class" {
  description = "CloudFront price class. PriceClass_100 = North America + Europe (cheapest). PriceClass_All = every edge (best latency, higher cost)."
  type        = string
  default     = "PriceClass_100"
}

variable "minimum_protocol_version" {
  description = "Minimum TLS version viewers may use. TLSv1.2_2021 is a strong, widely-compatible choice (supports TLS 1.2 and 1.3)."
  type        = string
  default     = "TLSv1.2_2021"
}

variable "tags" {
  description = "Tags applied to every resource (cost allocation + governance)."
  type        = map(string)
  default = {
    Project     = "CloudHost"
    Environment = "prod"
    ManagedBy   = "Terraform"
  }
}
