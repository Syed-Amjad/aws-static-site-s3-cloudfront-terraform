# =============================================================================
# CloudHost — outputs.tf
# =============================================================================

output "cloudfront_domain_name" {
  description = "New CloudFront domain. Point your Hostinger routing CNAME at THIS value."
  value       = aws_cloudfront_distribution.site.domain_name
}

output "cloudfront_distribution_id" {
  description = "Use for cache invalidations: aws cloudfront create-invalidation --distribution-id <id> --paths '/*'"
  value       = aws_cloudfront_distribution.site.id
}

output "bucket_name" {
  description = "The private origin bucket."
  value       = aws_s3_bucket.site.id
}

output "acm_certificate_arn" {
  description = "The reused ACM certificate ARN."
  value       = data.aws_acm_certificate.site.arn
}

output "custom_url" {
  description = "Your live site once the routing CNAME points at CloudFront."
  value       = "https://${var.domain_name}"
}

output "NEXT_STEP_update_hostinger_dns" {
  description = "The one manual DNS change after apply."
  value       = "In Hostinger DNS, set the routing CNAME for '${var.domain_name}' to point to: ${aws_cloudfront_distribution.site.domain_name}"
}
