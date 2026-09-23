# Progress Log

## Phase 0 – Foundations
- [x] Project repo + mentor instructions (CLAUDE.md) created — 2026-09-23
- [x] Step 1: Install tools — AWS CLI 2.37.0 (official pkg; brew build unsupported on macOS 14), Terraform 1.16.4 — 2026-09-23
- [ ] Step 2: Secure the AWS root account (MFA, no root keys) + billing budget alert
- [x] Step 3: AWS Organizations + dev/prod accounts — 2026-09-23
- [ ] Step 4: IAM Identity Center (SSO) user + `aws sso login` profiles
- [ ] Step 5: Terraform remote state (bootstrap)
- [ ] Step 6: KMS key + data lake S3 buckets (dev)

## Company context (fill in)
- Sources:
- Daily volume:
- Freshness needed:
- Consumers:
- Compliance:

## Decisions
- AWS account created fresh by the user as root owner (2026-09-23).
- Home region: **us-east-1 (N. Virginia)**; set as console default region (2026-09-23). All resources go here unless there's a documented reason.
- AWS Organizations enabled; original account = management account (billing/admin only, no workloads).
- Organization **o-cr8t80750g**; management account **457778953166** (name "Mae").
- Member accounts (both in the same OU ou-k7ua-roiruzwc): **mei-data-dev = 237162087184**, **mei-aws-prd = 219712358777** (2026-09-23).
- IAM Identity Center enabled: **Single-Region, us-east-1**, organization instance `ssoins-7223fd24797c3af2` (2026-09-23). Chose single-region for simplicity; a replica region can be added later if needed.
- AWS access portal URL (use for browser + `aws configure sso`): **https://d-90667e1293.awsapps.com/start** (dual-stack alt: https://ssoins-7223fd24797c3af2.portal.us-east-1.app.aws).
- SSO MFA: always-on, register-at-sign-in required. Group **DataPlatformAdmins** created (2026-09-23).
