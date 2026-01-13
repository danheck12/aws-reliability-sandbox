# AWS Reliability Sandbox

![GitHub Workflow Status](https://github.com/danheck12/aws-reliability-sandbox/actions/workflows/deploy.yml/badge.svg)

A senior-level AWS reliability sandbox focused on SLO-driven infrastructure, high availability, observability, failure testing, and automated CI/CD.

---

## Table of Contents

1. [Goals](#goals)
2. [Architecture](#architecture)
3. [Tech Stack](#tech-stack)
4. [Repository Structure](#repository-structure)
5. [Getting Started](#getting-started)
6. [Usage Examples](#usage-examples)
7. [Reliability Model](#reliability-model)
8. [Controlled Failure](#controlled-failure)
9. [Incident Response](#incident-response)
10. [CI/CD](#cicd)
11. [Cost Awareness](#cost-awareness)
12. [Roadmap](#roadmap)
13. [Author](#author)

---

## Goals

This project demonstrates how to design and operate a reliable, observable, and automated service on AWS using infrastructure-as-code, container deployments, and monitoring practices that mirror real production workflows.

---

## Architecture

Users
|
ALB (Application Load Balancer)
|
ECS Fargate (API Service)
|
Prometheus → Alertmanager → (Slack/PagerDuty or GitHub Issues)
|
Grafana Dashboards

yaml
Copy code

All infrastructure is provisioned with Terraform. Deployments are handled via GitHub Actions using AWS OIDC (no stored AWS keys).

---

## Tech Stack

**Cloud + Infrastructure**
- AWS: VPC, ALB, ECS Fargate, ECR, CloudWatch
- Terraform remote state (S3 + DynamoDB)

**Application**
- FastAPI (Python)
- Prometheus metrics endpoint
- Configurable fault injection

**Observability**
- Prometheus
- Grafana
- Alertmanager

**CI/CD**
- GitHub Actions with AWS OIDC
- Build + push + ECS force deploy

---

## Repository Structure

.
├── terraform/
│ └── envs/staging/ # AWS infra: VPC, ECS, ALB, ECR
├── services/
│ └── api/ # FastAPI app (metrics + error/latency endpoints)
├── observability/
│ ├── prometheus/
│ ├── rules/
│ └── alertmanager/
├── chaos/
│ └── experiments/ # Controlled failure playbooks
├── runbooks/ # Incident work instructions
├── incidents/ # Incident writeups & analysis
└── .github/workflows/ # CI/CD workflows

yaml
Copy code

---

## Getting Started

These steps will provision AWS infrastructure and deploy the API.

### Prerequisites

- AWS account with permissions to create VPC, ECS, ALB, etc.
- AWS CLI configured (`aws sts get-caller-identity` must succeed)
- Terraform v1.5+
- Docker
- GitHub repo with Actions enabled

### Provision Infrastructure

```bash
git clone git@github.com:danheck12/aws-reliability-sandbox.git
cd aws-reliability-sandbox

cd terraform/envs/staging
terraform init
terraform apply -auto-approve
Terraform outputs:

alb_dns (example: xyz123abc.us-east-2.elb.amazonaws.com)

ecr_api repository URL

Trigger Deployment
Deployment is done automatically via GitHub Actions on push to main.

bash
Copy code
git commit --allow-empty -m "Trigger deploy"
git push
Validate:

bash
Copy code
ALB=$(terraform output -raw alb_dns)
curl --fail http://$ALB/healthz
curl http://$ALB/metrics | head
Usage Examples
Once deployed, you can interact with the service:

Fetch Health
bash
Copy code
curl http://$ALB/healthz
Generate Latency
bash
Copy code
curl http://$ALB/latency?ms=500
Trigger Error Pattern
bash
Copy code
curl http://$ALB/error
Reliability Model
This service is built with measurable SLIs/SLOs:

Metric	Target	Meaning
Availability	99.9%	Minimal downtime SLA indicator
Error Rate	< 2%	Error noise threshold
Latency p95	< 300ms	Good responsiveness benchmark

Error budget burn rate alerts guide escalation vs. action.

Controlled Failure
This project includes fault injection experiments:

5xx spike via /error

Injected latency via /latency

Task restarts via ECS desired count changes

Broken deploys to exercise rollback/runbooks

Experiments are documented in chaos/experiments.

Incident Response
Guided runbooks in runbooks/ capture how to respond to common alerts.
Incident writeups in incidents/ include:

Timeline

Root cause analysis (5 Whys)

Corrective actions

CI/CD
On every push to main, GitHub Actions:

Builds Docker image

Pushes to ECR

Forces ECS service redeploy via:

bash
Copy code
aws ecs update-service \
  --cluster aws-reliability-sandbox-staging \
  --service aws-reliability-sandbox-staging-api \
  --force-new-deployment
AWS authentication is done via OIDC, so no static credentials are stored.

Cost Awareness
This architecture uses:

NAT Gateway

Application Load Balancer

Fargate tasks

Expected minimal monthly cost if idle: ~$10–$25.
Destroy infrastructure when not needed:

bash
Copy code
cd terraform/envs/staging
terraform destroy -auto-approve
Roadmap
Planned enhancements:

Grafana + Prometheus as ECS services

Burn-rate SLO alerting (fast/slow windows)

Slack/PagerDuty alert routing

Canary deployments

Policy as Code (OPA / Terraform Guardrails)

Author
Dan Heck
Infrastructure & Reliability Engineer (10+ years production)
Happy to discuss design, incident handling, or architectural choices.
