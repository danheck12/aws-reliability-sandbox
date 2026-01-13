# Runbook: Elevated 5xx

## Symptoms
- Alert: ApiHigh5xxRate
- Customer impact: errors on key endpoints

## Triage
1) Check ALB target health in EC2 console or via AWS CLI
2) Check CloudWatch logs for API task errors
3) Check if ERROR_RATE / feature flag is set

## Mitigation
- If recent deploy: rollback (force redeploy previous image tag)
- If injected fault: set ERROR_RATE=0 and redeploy
- If dependency issue: isolate / degrade features

## Follow-up
- Add guardrails (canary, automated rollback)
- Improve alert signal-to-noise
