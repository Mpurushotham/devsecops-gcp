## Summary

<!-- What does this PR do? Why is it needed? -->

## Type of Change

- [ ] Infrastructure (Terraform)
- [ ] CI/CD pipeline
- [ ] Kubernetes / GKE
- [ ] Security policy (Gatekeeper / OPA / org policy)
- [ ] Cloud Function
- [ ] Documentation

## Security Impact

<!-- Does this change affect security posture? Describe any new attack surface, permissions granted, or controls removed. -->

## Compliance

<!-- Does this change affect CIS GCP Benchmark or SOC 2 controls? If yes, which ones? -->

- [ ] No compliance controls affected
- [ ] CIS GCP control(s) affected: <!-- list control IDs -->
- [ ] SOC 2 control(s) affected: <!-- list control IDs -->

## Testing

- [ ] `terraform fmt` and `terraform validate` pass
- [ ] `tfsec` / `checkov` show no new HIGH/CRITICAL findings
- [ ] Gatekeeper policy unit tests pass (`opa test`)
- [ ] Prowler scan run against affected environment
- [ ] Manual verification performed in dev/staging

## Checklist

- [ ] No secrets or credentials committed
- [ ] `terraform.tfvars` not committed (use `terraform.tfvars.example` for new variables)
- [ ] State backend not modified without team approval
- [ ] Least-privilege: no `roles/owner` or `roles/editor` granted
- [ ] VPC-SC changes tested in DRY_RUN before enforcing
