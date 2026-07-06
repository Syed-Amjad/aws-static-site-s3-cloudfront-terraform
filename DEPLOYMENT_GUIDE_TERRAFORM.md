# CloudHost (Terraform Edition) — Deployment Guide

> Rebuild the **exact same** production stack — private S3 + CloudFront + OAC + HTTPS — but as
> **Infrastructure as Code** with Terraform, run from **Ubuntu 24.04 (WSL2)**.
>
> **We reuse the existing ACM certificate and keep the Hostinger validation CNAME**, so there is
> **no re-request and no re-validation**. The only manual DNS action is updating **one** routing CNAME
> after `apply`.

---

## What this Terraform builds

| Resource | File | Notes |
|---|---|---|
| Private S3 bucket | `s3.tf` | Block Public Access ON, versioning, SSE-S3 encryption |
| Website objects | `s3.tf` | One `aws_s3_object` per file, correct Content-Type + Cache-Control |
| Bucket policy | `s3.tf` | Allows only this distribution (OAC + `AWS:SourceArn`) |
| Origin Access Control | `cloudfront.tf` | SigV4 signing |
| CloudFront distribution | `cloudfront.tf` | HTTPS redirect, custom 403/404 → `/error.html` |
| ACM certificate | `cloudfront.tf` | **Reused** via `data` source (not created) |

DNS stays at **Hostinger** (there is no first-class Hostinger Terraform provider, and moving the
client's DNS to Route 53 would be overkill), so the routing CNAME is updated by hand — clearly flagged
in the Terraform output.

---

## PHASE 0 — Clean up the console-built resources first

You already built this stack by hand. Remove those resources so Terraform starts clean and there is no
name clash. **Keep the certificate and both CNAMEs.**

> Full copy-paste teardown commands are in **`TEARDOWN_CONSOLE_RESOURCES.md`** in this folder. Summary:
> 1. **Disable** then **delete** the console CloudFront distribution.
> 2. **Empty** then **delete** the console S3 bucket (`amjad-cloudhost-production`).
> 3. Delete the console **OAC** (optional).
> 4. **DO NOT** delete the ACM certificate.
> 5. **DO NOT** delete the Hostinger CNAMEs (we'll just repoint the routing one later).

Do Phase 0 before Phase 3 (`apply`). You can set up WSL/Terraform (Phases 1–2) in parallel.

---

## PHASE 1 — Prepare Ubuntu 24.04 (WSL2)

Open your Ubuntu terminal.

### 1.1 Install the AWS CLI v2
```bash
sudo apt-get update
sudo apt-get install -y unzip curl
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip -q awscliv2.zip
sudo ./aws/install
aws --version          # expect aws-cli/2.x
```

### 1.2 Install Terraform (HashiCorp apt repo)
```bash
sudo apt-get install -y gnupg software-properties-common
wget -O- https://apt.releases.hashicorp.com/gpg | \
  gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
  https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update
sudo apt-get install -y terraform
terraform -version     # expect Terraform v1.x
```

### 1.3 Configure AWS credentials
```bash
aws configure
# Access key / Secret / region = us-east-1 / output = json
aws sts get-caller-identity     # should print your AWS account id
```

> 🔒 **Credentials tip:** for a real pipeline you'd use an IAM role via OIDC, not long-lived keys. For
> local learning, an IAM user with the needed permissions is fine — just never commit the keys.

---

## PHASE 2 — Get the project into the WSL filesystem

Terraform reads the `website/` folder next to the `.tf` files, so keep the whole
`terraform-cloudhost/` folder together.

**Recommended:** copy it into the Linux filesystem (faster than `/mnt/c`):
```bash
mkdir -p ~/projects
cp -r "/mnt/c/Users/CURVE/Desktop/S3/terraform-cloudhost" ~/projects/
cd ~/projects/terraform-cloudhost
ls          # main.tf variables.tf s3.tf cloudfront.tf outputs.tf website/ ...
```
*(Working directly from `/mnt/c/...` also works; it's just slower.)*

### 2.1 Create your variables file
```bash
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```
Set:
- `bucket_name` → a **NEW** globally-unique name, e.g. `amjad-cloudhost-tf-prod` (don't reuse the old one).
- `domain_name` → **exactly** `s3-demo.sillageandskin.com` (must match your issued cert).

Save (`Ctrl+O`, `Enter`, `Ctrl+X`).

---

## PHASE 3 — Deploy with Terraform

```bash
terraform init      # downloads the AWS provider, sets up the working dir
terraform fmt       # (optional) tidy formatting
terraform validate  # syntax + internal consistency check
terraform plan      # preview: shows ~10 resources to be CREATED, 0 destroyed
```

Read the plan. It should say **"Plan: N to add, 0 to change, 0 to destroy"** and the certificate should
appear as a **data source read**, not a resource to create. When happy:

```bash
terraform apply     # type 'yes' to confirm
```

CloudFront takes a few minutes to deploy. On success Terraform prints the **outputs**, including:

```
cloudfront_domain_name          = "dXXXXXXXX.cloudfront.net"
NEXT_STEP_update_hostinger_dns  = "In Hostinger DNS, set the routing CNAME for 's3-demo.sillageandskin.com' to point to: dXXXXXXXX.cloudfront.net"
```

---

## PHASE 4 — Repoint the Hostinger routing CNAME (one line)

Because this is a brand-new distribution, its domain differs from the old one.

1. Hostinger → **hPanel → Domains → sillageandskin.com → DNS Zone**.
2. Find the **routing CNAME** `s3-demo` (the one that used to point at the old `...cloudfront.net`).
3. **Edit** its target to the **new** `cloudfront_domain_name` from the Terraform output.
4. Save. Leave the `_xxxx` **validation** CNAME untouched — it keeps the cert renewing.

> Not touched: the certificate, the validation CNAME. Only the single routing CNAME target changes.

---

## PHASE 5 — Verify end-to-end

Wait for DNS to update (minutes), then from Ubuntu:

```bash
# Homepage should be 200 over HTTPS, served via CloudFront
curl -sS -o /dev/null -w "home: HTTP %{http_code}\n" https://s3-demo.sillageandskin.com

# Missing path should hit the custom error page → 404
curl -sS -o /dev/null -w "404:  HTTP %{http_code}\n" https://s3-demo.sillageandskin.com/nope

# Prove the bucket is PRIVATE — direct S3 must be 403
curl -sS -o /dev/null -w "s3:   HTTP %{http_code} (expect 403)\n" \
  "https://$(terraform output -raw bucket_name).s3.us-east-1.amazonaws.com/index.html"

# Confirm it's really CloudFront (look for via: / x-cache: headers)
curl -sSI https://s3-demo.sillageandskin.com | grep -iE "^HTTP|server:|via:|x-cache:"
```

Expected: `home: HTTP 200`, `404: HTTP 404`, `s3: HTTP 403`, and CloudFront headers. Also open the URL in
a browser and confirm the padlock. ✅

---

## PHASE 6 — The day-to-day update loop

Change a file in `website/`, then:

```bash
terraform apply     # re-uploads only changed objects (etag-based)

# Bust the CDN cache so users see it immediately:
aws cloudfront create-invalidation \
  --distribution-id "$(terraform output -raw cloudfront_distribution_id)" \
  --paths "/*"
```

> **Two ways to upload — both valid, mentioned for completeness:**
> - **Pure IaC (default here):** `terraform apply` manages every file as an `aws_s3_object`.
> - **CLI sync (alternative):** `aws s3 sync ./website s3://$(terraform output -raw bucket_name) --delete`
>   — faster for large sites, but then the objects aren't tracked in Terraform state. Pick one approach and
>   stick to it; don't mix, or Terraform will try to "correct" files that sync uploaded.

---

## PHASE 7 — Full teardown (Terraform)

```bash
# Empty the bucket first (versioned buckets need object versions removed):
aws s3 rm "s3://$(terraform output -raw bucket_name)" --recursive
terraform destroy   # type 'yes'
```
`destroy` removes everything Terraform created. It will **not** touch the ACM certificate (it's a data
source, not managed) or your Hostinger DNS.

---

## Troubleshooting

| Symptom | Cause / Fix |
|---|---|
| `Error: no matching ACM Certificate found` | Cert isn't ISSUED, wrong `domain_name`, or not in us-east-1. Check ACM in the N. Virginia region. |
| `BucketAlreadyExists` / `BucketAlreadyOwnedByYou` | `bucket_name` is taken globally or still exists from the console. Use a new name or finish Phase 0. |
| `CNAMEAlreadyExists` on the distribution | The old console distribution still has `s3-demo...` as an alias. Delete/disable it (Phase 0) first. |
| Site shows old content after apply | CloudFront cache — run the invalidation in Phase 6. |
| `curl` TLS handshake fails on Windows but works in WSL/browser | Old Windows Schannel vs modern TLS. Not a site problem — test from WSL. |

---

## Why this reads as senior-level

- **Declarative, reviewable, repeatable** — the whole stack is `terraform apply` from nothing.
- **Reuses** the certificate via a `data` source instead of recreating it (understands state vs. real world).
- **Least-privilege** bucket policy generated from `aws_iam_policy_document` with the `AWS:SourceArn` guard.
- **Provider aliasing** for the us-east-1 ACM requirement — the classic CloudFront gotcha, handled correctly.
- **Per-file Content-Type / Cache-Control** driven by a mime map, not hand-set.
- Clean `.gitignore`, tagged resources, and a documented state/backend path for scaling to a team.
