# Static website bucket

## Layout usage

run terraform apply once to create all the resouces
once you have created the DNS records for the certificate run terraform again with acm_arn_validated set to the certificate arn from the output to configure the subject alternative names and certificate in the cloudfront distribution.

the verification values can be retreived with the following aws cli call
`aws acm describe-certificate --certificate-arn <ARN GOES HERE>`
Or equivalent call with the aws SDK

Use the `cloudfront_cname` output variable to route traffic to your CDN

## limitations

hashicorp/aws v3.21 seems to have a bug in that changing the viewer certificate block after the distribution is created doesn't seem to initiate modification.
run `terraform destroy -target=aws_cloudfront_distribution.website_cdn_root` to remove it and then re-apply