# CloudHost — Static Website on AWS, as Infrastructure as Code (Terraform)

Production-grade static website hosting on AWS, defined entirely in **Terraform**: a **private** S3
bucket served through **CloudFront** with **Origin Access Control**, **HTTPS** via a reused **ACM**
certificate, custom error pages, versioning, encryption, and least-privilege access.

> `terraform apply` builds the whole stack. No public buckets. No wildcard IAM. No HTTP.

## Architecture

```
            ┌────────────┐      ┌──────────────────┐      ┌──────────────────┐
  User ───► │  Hostinger │ ───► │   CloudFront     │ ───► │   S3 (PRIVATE)   │
  (HTTPS)   │    DNS     │ CNAME│  + ACM (TLS)     │ OAC  │  website objects │
            └────────────┘      │  + edge caching  │ SigV4│  Block Public ON │
                                └──────────────────┘      └──────────────────┘
                                         ▲
                                   Terraform manages
                                   everything on the right
```

DNS lives at Hostinger (one CNAME → CloudFront). Everything from CloudFront leftward-to-S3 is Terraform.

## Files

```
terraform-cloudhost/
├── main.tf                        # providers (incl. us-east-1 alias for ACM) + settings
├── variables.tf                   # inputs (bucket_name, domain_name, tags, ...)
├── s3.tf                          # private bucket, encryption, versioning, objects, bucket policy
├── cloudfront.tf                  # OAC + distribution + reused ACM certificate (data source)
├── outputs.tf                     # distribution domain, id, next-step DNS instruction
├── terraform.tfvars.example       # copy to terraform.tfvars and fill in
├── .gitignore                     # ignores state + tfvars, keeps lock file
├── website/                       # the static site (uploaded as aws_s3_object)

```

## Quick start (Ubuntu 24.04 / WSL2)

```bash
cp terraform.tfvars.example terraform.tfvars   # then edit bucket_name + domain_name
terraform init
terraform plan
terraform apply
# then update ONE Hostinger routing CNAME to the printed cloudfront_domain_name
```

Full details, including installing Terraform in WSL2 and cleaning up the old console stack, are in
**[DEPLOYMENT_GUIDE_TERRAFORM.md](DEPLOYMENT_GUIDE_TERRAFORM.md)**.

## Prerequisites

- Ubuntu 24.04 on WSL2 with **Terraform ≥ 1.5** and **AWS CLI v2**.
- AWS credentials configured (`aws configure`).
- An **already-issued ACM certificate** for your domain in **us-east-1** (this project reuses it).
- DNS access to add/edit a CNAME (Hostinger hPanel).

## What makes it production-grade

- Private origin + CloudFront **OAC**; bucket policy scoped with the `AWS:SourceArn` condition.
- **HTTPS enforced**, custom **403/404** error pages, **versioning**, **SSE-S3 encryption**.
- Certificate **reused** via a `data` source — Terraform understands the difference between managed and
  referenced resources.
- Correct **us-east-1 provider alias** for the CloudFront/ACM requirement.
- Per-file **Content-Type** and **Cache-Control**, tagged resources, clean state hygiene.

## License

Personal practice / portfolio project. Reuse freely.
