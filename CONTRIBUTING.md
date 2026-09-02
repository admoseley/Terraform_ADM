# Contributing

This repository follows a **branch-and-pull-request workflow**. Nothing is
committed directly to `main` — every change goes through an issue, a branch, and
a reviewed PR.

## Workflow

1. **Open an issue** describing the task, chore, or bug (the "why").
2. **Create a branch** off `main`, named `<type>/<issue#>-<slug>`:
   - `feat/12-restrict-ssh`
   - `fix/15-nsg-priority`
   - `chore/1-ci-pipeline`
   - Types: `feat`, `fix`, `chore`, `docs`, `refactor`.
3. **Make the change** with clear, conventional commit messages that reference
   the issue.
4. **Open a PR into `main`**, fill in the template, and link the issue
   (`Closes #N`).
5. **Pass checks** — CI and Copilot review run automatically (see below).
6. **Merge** via squash once approved and green, then delete the branch.

## Commit messages

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <short summary>

<body — what and why>

Refs #<issue>
```

Example: `feat(network): restrict SSH ingress to a single admin CIDR`

## Automated checks (run on every PR)

| Check | Purpose |
|-------|---------|
| `terraform fmt -check` | Consistent formatting |
| `terraform validate` | Configuration is valid |
| `tflint` | Lint + Azure best-practice rules |
| **Checkov** | IaC security scanning (Azure policies) |
| **Copilot code review** | AI review of logic and build practices |

Run the code checks locally before pushing:

```bash
terraform fmt -recursive
terraform init -backend=false
terraform validate
```

If a Checkov finding is a deliberate, accepted choice, suppress it **inline**
with a justification rather than disabling the scanner:

```hcl
# checkov:skip=CKV_AZURE_XXX: <reason this is acceptable here>
```

## Deployments

- `main` is the source of truth. Merging to `main` triggers a `terraform plan`
  followed by an `apply` **gated behind a manual sign-off** (GitHub Environment
  approval). Nothing reaches Azure without that approval.
- Never commit `terraform.tfvars` or state files — both are git-ignored.

## Principles

- **Budget:** keep the environment within ~$150/month; note cost impact in PRs.
- **Security:** least privilege, no secrets in code, restrict ingress.
- **Parity:** the two regions come from one module — change the module, not one
  region, to keep them identical.
