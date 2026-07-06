# Pushing CloudHost (Terraform) to GitHub — WSL2 Guide

> Publish **this folder** (`terraform-cloudhost/`) as a GitHub repo. The folder's `README.md` becomes
> the repo landing page. You created the GitHub repo **without** a README, so there will be no conflict.

---

## PART 1 — What is safe to commit (and what is NOT)

The important idea: **as long as Terraform *state* and your real *tfvars* are ignored, nothing sensitive
leaks.** There are no AWS keys in this project (they live in `~/.aws`, outside the repo).

### ❌ NEVER commit (already handled by `.gitignore`)
| File / folder | Why |
|---|---|
| `*.tfstate`, `*.tfstate.*` | **State is sensitive** — it records every resource, ARN, and can contain secrets. Treat like a password. |
| `terraform.tfvars` | Your real input values. |
| `.terraform/` | Downloaded provider binaries (huge, machine-specific). |
| `*.tfplan`, `.terraform.tfstate.lock.info` | Plan output / lock files. |
| `~/.aws/credentials` | Your access keys — but these aren't in the project folder anyway. Never paste them into any file. |

### ✅ DO commit
| File | Why |
|---|---|
| `*.tf` (main, variables, s3, cloudfront, outputs) | The infrastructure code — the whole point. |
| `terraform.tfvars.example` | A **placeholder** template so others (and future-you) know what inputs to set. |
| `.terraform.lock.hcl` | Provider version lock — **best practice to commit** for reproducible builds. |
| `website/` | The static site content (public by nature — it's literally on the internet). |
| `README.md`, guides | Documentation. |
| `.gitignore` | So the ignores travel with the repo. |

### About "hiding resource names / placeholders"
- **AWS account ID** — not a true secret (it appears in every ARN you share), but tidy to keep out of a
  public repo. Already genericized in the docs.
- **Bucket name / domain / distribution IDs** — **not secrets.** Bucket names are globally discoverable;
  your domain is public (it's the live site). No need to hide them.
- **Your real values** stay only in `terraform.tfvars` (ignored). The committed `terraform.tfvars.example`
  uses placeholders — that's the correct pattern. ✅

> Bottom line: you do **not** need to redact bucket/domain names. Just make sure `terraform.tfstate` and
> `terraform.tfvars` are never committed (they aren't, thanks to `.gitignore`).

### Optional trims (personal preference)
- `Amazon_S3_Case_Studies_Summary.docx` — a learning doc, not code. Keep it or delete before pushing.
- `LINKEDIN_POST_TERRAFORM.md` / `TEARDOWN_CONSOLE_RESOURCES.md` — fine to keep (they tell your story), or
  remove if you want a purely technical repo.

---

## PART 2 — One-time git identity (skip if already set)

```bash
git config --global user.name  "Your Name"
git config --global user.email "you@example.com"
git config --global init.defaultBranch main
```

---

## PART 3 — Initialise and push

Run these **inside the project folder**:

```bash
cd ~/projects/terraform-cloudhost

# 1) Start a repo here (this folder's contents become the repo root)
git init

# 2) SAFETY CHECK — see what WILL be committed BEFORE committing
git status
git status --ignored     # confirm terraform.tfstate, terraform.tfvars, .terraform/ appear under "Ignored"
```

🔎 **Look at the `git status` list carefully.** You should see `*.tf`, `README.md`, `website/`,
`.gitignore`, `terraform.tfvars.example`, `.terraform.lock.hcl` — and you should **NOT** see
`terraform.tfstate`, `terraform.tfvars`, or `.terraform/`. If any of those *do* appear, stop and tell me.

```bash
# 3) Stage + commit
git add .
git commit -m "CloudHost: static site on AWS (private S3 + CloudFront + OAC) as Terraform"

# 4) Connect to your empty GitHub repo (use the URL GitHub shows you)
git remote add origin https://github.com/<your-username>/<your-repo>.git

# 5) Push
git branch -M main
git push -u origin main
```

---

## PART 4 — Authentication (GitHub no longer accepts your password)

When `git push` prompts for a password, you must use a **Personal Access Token (PAT)**, not your GitHub
account password.

**Create a PAT:** GitHub → your avatar → **Settings → Developer settings → Personal access tokens →
Tokens (classic) → Generate new token (classic)** → tick the **`repo`** scope → copy the token.

Then at the push prompt:
- **Username:** your GitHub username
- **Password:** paste the **PAT** (not your real password)

**To avoid re-entering it every time**, cache credentials in WSL:
```bash
git config --global credential.helper store
# The next push stores the PAT in ~/.git-credentials (plaintext — fine for a personal dev box).
```

> **Alternative (SSH):** generate a key with `ssh-keygen -t ed25519 -C "you@example.com"`, add
> `~/.ssh/id_ed25519.pub` to GitHub → Settings → SSH keys, then use the SSH remote:
> `git remote set-url origin git@github.com:<user>/<repo>.git`. SSH avoids PAT prompts entirely.

---

## PART 5 — Verify, then destroy the infrastructure

1. Refresh your repo page on github.com — you should see all files and the rendered `README.md`.
2. **Now** it's safe to tear down the AWS resources (your code is preserved in git):

```bash
# empty the versioned bucket first, then destroy
aws s3 rm "s3://$(terraform output -raw bucket_name)" --recursive
terraform destroy      # type 'yes'
```

`terraform destroy` removes the bucket, distribution, and OAC. It does **not** touch:
- your **committed code** (that's in git, independent of AWS),
- the **ACM certificate** (a data source, not managed by Terraform),
- your **Hostinger DNS** records.

> After destroy, the live URL stops working — expected. To bring it back later: `terraform apply`, then
> repoint the `s3-demo` CNAME to the new distribution domain (same as before).

---

## PART 6 — Recover if you accidentally committed a secret

If `terraform.tfstate` or `terraform.tfvars` slipped in **before** you pushed:
```bash
git rm --cached terraform.tfstate terraform.tfvars   # untrack, keep local copy
git commit -m "Remove sensitive files from tracking"
```
If it was **already pushed**, the file is in history — rotate anything sensitive and scrub history with
`git filter-repo` (or delete the repo and recreate). Easier to just get the pre-commit `git status` check
right the first time.

---

## Quick command recap

```bash
cd ~/projects/terraform-cloudhost
git init
git status                 # verify no tfstate/tfvars
git add .
git commit -m "CloudHost: static site on AWS as Terraform"
git remote add origin https://github.com/<user>/<repo>.git
git branch -M main
git push -u origin main    # username + PAT
```
