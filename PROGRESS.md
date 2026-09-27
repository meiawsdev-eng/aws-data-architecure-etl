# Progress Log

## Phase 0 – Foundations
- [x] Project repo + mentor instructions (CLAUDE.md) created — 2026-09-23
- [x] Step 1: Install tools — AWS CLI 2.37.0 (official pkg; brew build unsupported on macOS 14), Terraform 1.16.4 — 2026-09-23
- [x] Step 2: Root secured (MFA on, no root keys in any account — verified via get-account-summary), org-wide COST budget `monthly-cost-50` ($50/mo) in mgmt, root creds in password manager — 2026-09-23
- [x] Step 3: AWS Organizations + dev/prod accounts — 2026-09-23
- [x] Step 4: IAM Identity Center (SSO) user + CLI profiles data-dev, data-prd, mgmt (sso-session `mei-aws`) — 2026-09-23
- [x] Step 5: Terraform state bucket `mei-aws-slug-tfstate-dev-237162087184` (versioned, AES256, public blocked) — 2026-09-26.
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
- SSO user created, invitation accepted, MFA registered, member of DataPlatformAdmins (2026-09-23).
- OU confirmed as **Workloads** (ou-k7ua-roiruzwc) holding dev + prd; management account (Mae) at org root.
- Permission set **AdministratorAccess** (ps-7223b91fc7c9bc5e, 4h session) assigned to DataPlatformAdmins on all 3 accounts (2026-09-23). TODO Phase 3: narrower sets (DataEngineer, ReadOnly, Billing), drop admin on management/prod.
- E1 (2026-09-26): same orders job ran on Glue ($0.019, 78 s, 2×G.1X) and EMR Serverless ($0.006, 101 s, 1-core driver + 2 executors). Removed Athena-set legacy Iceberg property 'write.object-storage.path' — newer Iceberg on EMR rejects it. Script is engine-agnostic (argparse).

## Open items
- [ ] Change prod account (mei-aws-prd) root email from school address to a long-lived/company email — before real data lands in prod.
- [ ] Company slug for resource naming (needed for Step 5).
- [ ] Phase 3: enable Centralized root access management (IAM, mgmt account); delegated admin for Identity Center; narrower permission sets.

## Phase 1 – First pipeline
- [x] Step 8: First ETL — sample orders.csv → raw (Bronze) → Glue job `mei-aws-slug-dev-orders-bronze-to-silver` → `silver.orders` (Iceberg, MERGE, idempotent) → Athena — 2026-09-26
- [x] Step 9.1: Git identity, private GitHub repo (SSH), first push — 2026-09-26
- [x] Step 9.2: Bootstrap state migrated to S3 (`bootstrap/dev/terraform.tfstate`); local state deleted — 2026-09-26

## Roadmap (re-ordered 2026-09-27, based on 48 Texas AWS data engineer postings)
Survey (Dice, 104 TX postings, 48 mention AWS): Databricks 50%, Snowflake 44%, Kafka/Kinesis 42%,
Glue 33%, Redshift 31%, Airflow 29%, Kubernetes 25% (mostly general), Terraform 21%, EMR 10%, EMR on EKS 0%.

- [x] E1: EMR Serverless — Glue $0.019 vs EMR Serverless $0.006 (2026-09-26)
- [x] E2.0: Dev VPC — public/private subnets, S3 endpoint, no NAT (2026-09-27)
- [x] E2: EMR on EC2 lab — job ran as EMR Step, YARN + Spark UI, cluster destroyed (2026-09-27)
- [ ] 1. E3: Spark tuning lab — data skew, AQE vs salting, Spark UI
- [ ] 2. Databricks — run the orders pipeline on Databricks (free trial)
- [ ] 3. Airflow + Docker basics — local Docker first, then short MWAA lab
- [ ] 4. Streaming — Kafka concepts + Kinesis, Spark Structured Streaming
- [ ] 5. Snowflake + dbt — Gold layer, dimensional modeling (star schema, SCD2)
- [ ] 6. Redshift Serverless — load Gold, compare with Athena/Snowflake
- [ ] 7. CI/CD — GitHub Actions, OIDC to AWS, ruff + terraform plan on PR
- [ ] 8. CDC — RDS Postgres → DMS → raw
- [ ] 9. Data quality + pytest + Lake Formation
- [ ] Short: E4 (Spot + scaling) and E5 (ADR: Glue vs EMR vs EMR Serverless)
- [ ] Later: Docker/Kubernetes basics (general skill; EMR on EKS skipped: 0% of postings)
- Cost rule: MWAA, RDS, Kinesis, Redshift, EMR clusters are lab-only — create, learn, delete. Budget $50/mo. Databricks/Snowflake: free trials.
