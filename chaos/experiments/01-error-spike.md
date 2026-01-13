# Experiment 01: Inject 5xx spike

Goal: Trigger 5xx alert and validate runbook + rollback.

Steps:
1) Set ERROR_RATE to 0.3 for the API task definition (via terraform env var) OR update task def manually.
2) Generate traffic to /error.
3) Observe metrics (/metrics) and alerts.

Traffic:
- while true; do curl -s -o /dev/null -w "%{http_code}\n" http://<ALB>/error; sleep 0.2; done

Expected:
- 5xx ratio > 2% over 5m triggers ApiHigh5xxRate.
- Runbook guides mitigation (set ERROR_RATE back to 0, redeploy).
