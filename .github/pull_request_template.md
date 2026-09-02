<!--
  PR template. Fill in each section. CI (fmt/validate/tflint/checkov) and
  Copilot code review run automatically on this PR.
-->

## Summary

<!-- What does this change do and why? Link the issue. -->

Closes #

## Type of change

- [ ] `feat` — new infrastructure/capability
- [ ] `fix` — bug fix
- [ ] `chore` — tooling/CI/workflow
- [ ] `docs` — documentation only
- [ ] `refactor` — no behavior change

## Terraform plan

<!-- Paste the relevant `terraform plan` output, or summarize resource changes. -->

```
# terraform plan output here
```

## Checklist

- [ ] `terraform fmt` run and clean
- [ ] `terraform validate` passes
- [ ] tflint and Checkov pass (or skips are justified inline with a reason)
- [ ] Docs updated (README / comments) where behavior changed
- [ ] **Cost impact considered** — stays within the ~$150/month budget
- [ ] **Security considered** — no secrets committed; least-privilege; ingress restricted

## Cost impact

<!-- Estimated monthly delta, if any. State "none" if unchanged. -->

## Notes for reviewer

<!-- Anything specific to look at, trade-offs, follow-ups. -->
