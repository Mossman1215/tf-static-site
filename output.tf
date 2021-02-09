output "website_cdn_root_arn" {
  description = "CloudFront Distribution ID"
  value       = aws_cloudfront_distribution.website_cdn_root.arn
}
output "certificate_arn" {
  description = "AWS Certificate ARN"
  value       = aws_acm_certificate.cert_website.arn
}
output "cloudfront_cname" {
  description = "cname of the created cloudfront distribution"
  value       = aws_cloudfront_distribution.website_cdn_root.domain_name
}

output "cloudfront_oai_arn" {
  description = "arn for cloudfront origin access identity"
  value       = aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn
}

output "cloudfront_oai_identity" {
  description = "unique cloudfront origin access identity"
  value       = aws_cloudfront_origin_access_identity.origin_access_identity.etag
}

output "s3_web_bucket" {
  description = "s3 bucket name"
  value       = aws_s3_bucket.website_root.id
}