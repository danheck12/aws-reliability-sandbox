# AWS Reliability Sandbox

Production-style reliability engineering sandbox built on AWS using ECS Fargate, Terraform, GitHub Actions, and Prometheus/Grafana.  
This project demonstrates **reliability ownership end-to-end**: infrastructure as code, observability, SLO-driven alerting, controlled failure, incident response, and automation.

> This is not a tutorial project. It is intentionally designed to mirror how internal platform / SRE teams build, operate, and harden real production systems.

---

## 🎯 Goals

- Demonstrate **reliability as an engineering discipline**, not just “DevOps tooling”
- Practice **incident response, root cause analysis, and prevention**
- Build a **production-style ECS platform** with real failure modes
- Implement **SLO-driven alerting** and meaningful observability
- Show **automation, CI/CD, and infrastructure validation**

---

## 🏗️ Architecture

High-level flow:

Users
|
Application Load Balancer
|
ECS Fargate (API Service)
|
Prometheus -> Alertmanager
|
Grafana Dashboards

All infrastructure is provisioned with **Terraform**.  
Deployments are handled via **GitHub Actions using AWS OIDC (no static credentials)**.

---

## 🔧 Tech Stack

**Cloud & Infra**
- AWS (VPC, ALB, ECS Fargate, ECR, CloudWatch)
- Terraform (remote state, modules, env separation)

**Application**
- Python (FastAPI)
- Structured logging
- Prometheus metrics endpoint

**Observability**
- Prometheus
- Grafana
- Alertmanager

**CI/CD**
- GitHub Actions
- OIDC authentication to AWS
- Automated container build + ECS deploy

**Reliability**
- SLO-based alerting (error rate, latency)
- Controlled failure experiments
- Runbooks and incident templates

---

## 📁 Repository Structure

.
├── terraform/
│ └── envs/staging/ # VPC, ECS, ALB, ECR, Cloud Map
├── services/
│ └── api/ # FastAPI service w/ metrics + failure injection
├── observability/
│ ├── prometheus/
│ ├── rules/
│ └── alertmanager/
├── chaos/
│ └── experiments/ # Controlled failure scenarios
├── runbooks/ # Incident response guides
├── incidents/ # Postmortems & timelines
└── .github/workflows/ # CI/CD pipelines

---

## 📊 Reliability Model

### Service Level Objectives (SLOs)

| Metric        | Target  |
|--------------|---------|
| Availability | 99.9%   |
| Error Rate   | < 2%    |
| Latency p95  | < 300ms |

Alerting is designed to be **signal-based**, not noisy, and will be expanded to multi-window burn-rate alerts.

---

## 🔬 Controlled Failure

The service includes built-in fault injection:

| Endpoint     | Purpose                     |
|-------------|-----------------------------|
| `/error`    | Inject 5xx at configurable rate |
| `/latency`  | Inject artificial latency   |
| Task kills  | ECS service scaling / stops |
| Bad deploys | Misconfig / broken image    |

Each experiment is documented under:

chaos/experiments/

With:
- Hypothesis
- Steps
- Expected outcome
- Observed behavior

---

## 🚨 Incident Response

Runbooks live in:

runbooks/

Incident writeups live in:

incidents/

Each incident includes:
- Timeline
- Impact analysis
- Root cause (5 Whys)
- Corrective actions

This mirrors real on-call + postmortem workflows.

---

## 🚀 CI/CD

Every push to `main`:

1. Builds the container
2. Pushes to ECR
3. Forces new ECS deployment
4. Uses AWS OIDC (no long-lived secrets)

Workflow:
.github/workflows/deploy.yml

yaml
Copy code

---

## 💰 Cost Awareness

This stack uses:
- NAT Gateway
- ALB
- Fargate

When not actively working:
bash
cd terraform/envs/staging
terraform destroy
Remote state (S3 + DynamoDB) can be retained.

🧠 Why This Project Exists
This project was built to practice and demonstrate:

Systems thinking

Production failure handling

Observability maturity

Incident leadership

Infrastructure discipline

It is intentionally opinionated and operationally focused.

🔮 Future Work
Planned expansions:

Prometheus + Grafana as ECS services

Burn-rate SLO alerting

Slack / PagerDuty integration

Canary deployments

Cost-based scaling guardrails

Policy-as-code for Terraform

🧾 Author
Built by Dan Heck
Infrastructure / Reliability Engineer
10+ years production experience
