# Infrastructure as Code — AWS Production Environment

This Terraform configuration provisions a complete, production-grade AWS environment for the
NestJS todo application. It builds an isolated VPC, an auto-scaling fleet of EC2 app servers
behind an Application Load Balancer, a managed MySQL database, a Redis cache, secret storage,
and CloudWatch-based monitoring with email alerting.

Everything is parameterized through plain-English variables (region names, t-shirt instance
sizes) that are mapped to real AWS values in [locals.tf](locals.tf).

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Module Dependency Graph](#module-dependency-graph)
- [Network Layout](#network-layout)
- [Modules](#modules)
  - [network](#1-network)
  - [security](#2-security)
  - [secrets](#3-secrets)
  - [database](#4-database)
  - [cache](#5-cache)
  - [loadbalancer](#6-loadbalancer)
  - [compute](#7-compute)
  - [monitoring](#8-monitoring)
- [Input Variables](#input-variables)
- [Human-Friendly Abstractions](#human-friendly-abstractions)
- [Outputs](#outputs)
- [How the App Boots](#how-the-app-boots)
- [Usage](#usage)
- [Security Notes](#security-notes)

---

## Architecture Overview

```
                          Internet
                             │
                       ┌─────▼─────┐
                       │    ALB    │  (public subnets, port 80)
                       └─────┬─────┘
                             │ forward → :3000
              ┌──────────────┼──────────────┐
              │              │              │
        ┌─────▼─────┐  ┌─────▼─────┐  ┌─────▼─────┐
        │   EC2     │  │   EC2     │  │   EC2     │  Auto Scaling Group
        │  app:3000 │  │  app:3000 │  │  app:3000 │  (private-app subnets)
        └─────┬─────┘  └─────┬─────┘  └─────┬─────┘
              │              │              │
        ┌─────┴──────────────┴──────┐  ┌────┴───────────┐
        │       RDS MySQL 8.0       │  │ ElastiCache    │   (private-data subnets,
        │     (private-data)        │  │ Redis 7        │    no internet route)
        └───────────────────────────┘  └────────────────┘

   Outbound from private subnets → NAT Gateway (public-a) → Internet Gateway
   Secrets → AWS Secrets Manager (read via EC2 IAM role)
   Metrics/Alarms → CloudWatch → SNS → email
```

The app servers have **no public IP**. They reach the internet (to pull packages and clone the
repo) only through a single NAT Gateway. The data tier (RDS + Redis) has no internet route at
all and is reachable only from the app servers' security group.

---

## Module Dependency Graph

The root [main.tf](main.tf) wires eight modules together. Outputs from one module feed the
inputs of the next:

```
network  ─────────────────────────────────────────────────────────┐
security  (needs vpc_id from network) ─────────────────────────────┤
secrets   (IAM role + Secrets Manager) ────────────────────────────┤
database  (RDS MySQL 8.0, private-data subnets) ─────────────────── compute
cache     (ElastiCache Redis 7, private-data subnets) ───────────── compute
loadbalancer (ALB, public subnets) ──────────────────────────────── compute
monitoring   (CloudWatch alarms → SNS → email) ◄── loadbalancer outputs
```

---

## Network Layout

VPC CIDR: `10.0.0.0/16`, spread across two Availability Zones (`a` and `b`).

| Subnet           | CIDR          | AZ  | Purpose                              | Internet Route        |
|------------------|---------------|-----|--------------------------------------|-----------------------|
| public-a         | 10.0.1.0/24   | a   | ALB, NAT Gateway                     | Internet Gateway      |
| public-b         | 10.0.2.0/24   | b   | ALB                                  | Internet Gateway      |
| private-app-a    | 10.0.3.0/24   | a   | EC2 Auto Scaling Group               | NAT Gateway (egress)  |
| private-app-b    | 10.0.4.0/24   | b   | EC2 Auto Scaling Group               | NAT Gateway (egress)  |
| private-data-a   | 10.0.5.0/24   | a   | RDS + ElastiCache                    | None (isolated)       |
| private-data-b   | 10.0.6.0/24   | b   | RDS + ElastiCache                    | None (isolated)       |

**Route tables:**
- `rt-public-app` → `0.0.0.0/0` via Internet Gateway (associated with both public subnets)
- `rt-private-app` → `0.0.0.0/0` via NAT Gateway (associated with both private-app subnets)
- `rt-private-data` → no default route; purely local VPC traffic (associated with both private-data subnets)

A single NAT Gateway with an Elastic IP lives in `public-a` and provides outbound-only internet
access for the private-app tier.

---

## Modules

### 1. network
**File:** [modules/network/main.tf](modules/network/main.tf)

Provisions the entire VPC foundation:
- 1 VPC (`10.0.0.0/16`) with DNS hostnames and DNS support enabled
- 6 subnets (2 public, 2 private-app, 2 private-data) across two AZs
- 1 Internet Gateway
- 1 Elastic IP + 1 NAT Gateway (in public-a)
- 3 route tables and their subnet associations

**Outputs:** `vpc_id`, `public_subnet_ids`, `private_app_subnet_ids`, `private_data_subnet_ids`

### 2. security
**File:** [modules/security/main.tf](modules/security/main.tf)

Creates four security groups, each scoped to the minimum traffic needed (chained by reference,
not by CIDR):

| Security Group | Ingress                          | Source                |
|----------------|----------------------------------|-----------------------|
| `sg-alb`       | TCP 80 (HTTP)                    | `0.0.0.0/0` (internet) |
| `sg-app`       | TCP 3000                         | `sg-alb` only         |
| `sg-rds`       | TCP 3306 (MySQL)                 | `sg-app` only         |
| `sg-redis`     | TCP 6379 (Redis)                 | `sg-app` only         |

All groups allow unrestricted egress. The chaining (`security_groups = [...]`) means the
database only accepts connections from app servers, and app servers only from the load balancer.

**Outputs:** `alb_sg_id`, `app_sg_id`, `rds_sg_id`, `redis_sg_id`

### 3. secrets
**File:** [modules/secrets/main.tf](modules/secrets/main.tf)

Manages sensitive values and the IAM identity that lets EC2 read them:
- Two Secrets Manager secrets: `<project>/db_password` and `<project>/session_secret`
  (both with `recovery_window_in_days = 0` for easy teardown in dev)
- An IAM role assumable by `ec2.amazonaws.com`
- An IAM policy granting only `secretsmanager:GetSecretValue` and `DescribeSecret` on those
  two specific secret ARNs (least privilege)
- The `AmazonSSMManagedInstanceCore` managed policy (for SSM Session Manager access)
- An instance profile that wraps the role for EC2

> Chain: *EC2 instance → wears → instance profile → contains → IAM role → attached to → IAM policy → allows → the two secrets*

**Outputs:** `db_password_arn`, `session_secret_arn`, `ec2_instance_profile_name`,
`db_password_secret_name`, `session_secret_name`

### 4. database
**File:** [modules/database/main.tf](modules/database/main.tf)

A managed RDS MySQL 8.0 instance in the private-data subnets:
- DB subnet group spanning both private-data subnets
- Parameter group (`mysql8.0` family) forcing `utf8mb4` / `utf8mb4_unicode_ci`
- DB instance: 20 GB gp2 storage (autoscaling up to 100 GB), **encrypted at rest**, not publicly accessible
- Database `todo_app`, master user `admin`
- Multi-AZ toggle via `var.multi_az`
- 1-day backup retention, backup window `03:00–04:00`, maintenance `Mon 04:00–05:00`
- `skip_final_snapshot = true` (dev convenience — change for production)

**Outputs:** `db_endpoint`, `db_host`, `db_port`, `db_name`, `db_username`

### 5. cache
**File:** [modules/cache/main.tf](modules/cache/main.tf)

A single-node ElastiCache Redis 7 cluster used as the Express session store:
- Cache subnet group across both private-data subnets
- Parameter group (`redis7` family) with `maxmemory-policy = allkeys-lru`
- 1 cache node on port 6379, maintenance window `Tue 05:00–06:00`, no snapshot retention

**Outputs:** `redis_host`, `redis_port`, `redis_url`

### 6. loadbalancer
**File:** [modules/loadbalancer/main.tf](modules/loadbalancer/main.tf)

An internet-facing Application Load Balancer in the public subnets:
- ALB with the `sg-alb` security group, deletion protection off
- Target group on port 3000 (HTTP), `instance` target type
- Health check on `/health/readiness`, expecting HTTP 200 (2 healthy / 3 unhealthy thresholds,
  30 s interval, 5 s timeout)
- HTTP listener on port 80 forwarding to the target group

**Outputs:** `target_group_arn`, `alb_dns_name`, `alb_arn`

### 7. compute
**File:** [modules/compute/main.tf](modules/compute/main.tf)

The auto-scaling application tier:
- Looks up the latest **Ubuntu 22.04 (Jammy) amd64** AMI from Canonical
- Launch template: chosen instance type, no public IP, `sg-app`, the EC2 instance profile, and
  a base64-encoded [user_data.sh](modules/compute/user_data.sh) bootstrap script
- Auto Scaling Group across both private-app subnets, registered with the ALB target group,
  using **ELB health checks** (120 s grace) and **rolling instance refresh** (50% min healthy)
- **Scale up:** +1 instance when CPU > 70% for 2 minutes (120 s cooldown)
- **Scale down:** −1 instance when CPU < 30% for 5 minutes (300 s cooldown)
- Two CloudWatch metric alarms drive the scaling policies

**Outputs:** `asg_name`, `launch_template_id`

### 8. monitoring
**File:** [modules/monitoring/main.tf](modules/monitoring/main.tf)

Operational alerting via CloudWatch + SNS email:
- SNS topic with an email subscription (`var.alert_email` — confirm via the email AWS sends)
- **Unhealthy hosts:** alarm when `UnHealthyHostCount > 0` for 2 min (treats missing data as breaching; also fires `ok_actions`)
- **High 5xx:** alarm when `HTTPCode_Target_5XX_Count > 10` per minute for 2 min
- **High latency:** alarm when `TargetResponseTime > 2 s` for 3 min

**Outputs:** `sns_topic_arn`

---

## Input Variables

Declared in [variables.tf](variables.tf):

| Variable              | Type   | Default  | Description                                              |
|-----------------------|--------|----------|----------------------------------------------------------|
| `region`              | string | —        | Human region name: `Paris`, `Ireland`, or `Virginia`    |
| `app_instance_size`   | string | `small`  | App server t-shirt size: `small` / `medium` / `large`   |
| `db_instance_size`    | string | `small`  | Database t-shirt size                                    |
| `redis_instance_size` | string | `small`  | Redis node t-shirt size                                  |
| `min_instances`       | number | `2`      | Minimum app servers in the ASG                          |
| `max_instances`       | number | `4`      | Maximum app servers in the ASG                          |
| `multi_az`            | bool   | `false`  | Enable RDS Multi-AZ (use `true` for production)         |
| `alert_email`         | string | —        | Email address that receives infrastructure alerts       |
| `project_name`        | string | `iac1`   | Prefix applied to all resource names                    |
| `db_password`         | string | — (sensitive) | MySQL master password — **pass at apply time**     |
| `session_secret`      | string | — (sensitive) | Express session secret — **pass at apply time**    |

`db_password` and `session_secret` are marked `sensitive` and must **never** be committed to
`terraform.tfvars`. Pass them on the command line (see [Usage](#usage)).

---

## Human-Friendly Abstractions

[locals.tf](locals.tf) translates the plain-English inputs into AWS values:

**Regions:**
| Input      | AWS Region   |
|------------|--------------|
| `Paris`    | `eu-west-3`  |
| `Ireland`  | `eu-west-1`  |
| `Virginia` | `us-east-1`  |

**Instance sizes:**
| Size     | App (EC2)   | Database (RDS)  | Redis (ElastiCache) |
|----------|-------------|-----------------|---------------------|
| `small`  | `t3.micro`  | `db.t3.micro`   | `cache.t3.micro`    |
| `medium` | `t3.small`  | `db.t3.small`   | `cache.t3.small`    |
| `large`  | `t3.medium` | `db.t3.medium`  | `cache.t3.medium`   |

---

## Outputs

Declared in [outputs.tf](outputs.tf):

| Output    | Description                              |
|-----------|------------------------------------------|
| `app_url` | `http://<alb_dns_name>` — the public URL to access the application |

---

## How the App Boots

When the ASG launches an instance, [user_data.sh](modules/compute/user_data.sh) runs as root:

1. `apt-get update && upgrade`
2. Installs **Node.js 18**, `git`, and `awscli`
3. Pulls `db_password` and `session_secret` from Secrets Manager using the instance's IAM role
4. Reads the instance's private IP from the EC2 metadata endpoint
5. Clones the app repo (`Infrastructure-as-Code`) into `/opt/repo`
6. Writes `/opt/repo/web-app/.env` with DB host/port/user/password, Redis host/port, the session
   secret, `NODE_ENV=production`, and `DB_INIT_SYNC=true`
7. Runs `npm install --legacy-peer-deps`, `npm run build`, then prunes dev dependencies
8. Installs a **systemd service** (`iac1-app`) that runs `node dist/main`, restarts on failure,
   and starts on boot

The ALB then health-checks `/health/readiness`; once an instance returns HTTP 200 it is added to
the rotation.

---

## Usage

All commands run from the `terraform/` directory.

```bash
# Initialize providers and modules
terraform init

# Preview changes (secrets passed inline)
terraform plan \
  -var="db_password=YOUR_DB_PASSWORD" \
  -var="session_secret=YOUR_SESSION_SECRET"

# Apply
terraform apply \
  -var="db_password=YOUR_DB_PASSWORD" \
  -var="session_secret=YOUR_SESSION_SECRET"

# Get the app URL
terraform output app_url

# Tear everything down
terraform destroy \
  -var="db_password=YOUR_DB_PASSWORD" \
  -var="session_secret=YOUR_SESSION_SECRET"
```

Non-sensitive settings live in [terraform.tfvars](terraform.tfvars) and are picked up
automatically. After the first apply, **confirm the SNS subscription** via the email AWS sends to
`alert_email`, or you won't receive alerts.

**Requirements:**
- Terraform with the AWS provider `~> 5.0`
- AWS credentials configured (e.g. `aws configure` or environment variables) with permission to
  create VPC, EC2, RDS, ElastiCache, ELB, IAM, Secrets Manager, CloudWatch, and SNS resources

---

## Security Notes

- **State files contain secrets in plaintext.** The [.gitignore](.gitignore) excludes
  `*.tfstate*`, `*.auto.tfvars`, and override files. Never commit them. For team use, configure
  a remote backend (e.g. encrypted S3 + DynamoDB lock).
- **Secrets are passed at apply time**, stored in Secrets Manager, and read by EC2 through a
  least-privilege IAM policy scoped to the two specific secret ARNs.
- **Network isolation:** app servers have no public IP; the data tier has no internet route.
  Security groups are chained by reference so each tier only accepts traffic from the tier above it.
- **Encryption at rest** is enabled on RDS storage.
- For production, consider: setting `multi_az = true`, enabling RDS final snapshots
  (`skip_final_snapshot = false`), adding HTTPS (an ACM cert + 443 listener) on the ALB, and a
  longer backup retention period.
