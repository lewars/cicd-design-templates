# Contributing to the Databricks DataOps Platform

## Prerequisites

- [Databricks CLI](https://docs.databricks.com/en/dev-tools/cli/index.html) v0.200+
- [Go Task](https://taskfile.dev/installation/) (`task`)
- [Python](https://www.python.org/) 3.10+
- [act](https://github.com/nektos/act) (for local GitHub Actions testing)
- Access to a Databricks sandbox workspace

Install Python dev dependencies:

```bash
pip install -r requirements-dev.txt
```

---

## Commit Message Standard

This project uses [Conventional Commits](https://www.conventionalcommits.org/) to drive automated SemVer via `release-please`. Every commit to `main` (direct or via PR merge) **must** follow this format:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Types and Their SemVer Impact

| Type | SemVer Bump | When to Use |
|---|---|---|
| `fix:` | Patch (1.0.**1**) | Bug fixes, config corrections |
| `feat:` | Minor (1.**1**.0) | New resources, new pipeline logic |
| `feat!:` or `BREAKING CHANGE:` | Major (**2**.0.0) | Schema changes, renamed resources |
| `chore:`, `docs:`, `ci:`, `test:` | None | Maintenance, no functional change |

### Examples

```
feat(jobs): add daily_sales_ingestion job with DLT trigger
fix(dashboards): correct warehouse_id variable reference in prod target
feat!: rename catalog variable from source_catalog to catalog_name
chore(ci): pin actions/checkout to v4
docs: update sandbox setup instructions
```

> PRs with non-conforming commit messages will fail the lint check and cannot be merged.

---

## Branching Strategy

| Branch | Purpose |
|---|---|
| `main` | Integration branch; triggers Staging deployment on push |
| `feature/<name>` | All new work; branch from and PR back to `main` |
| `hotfix/<name>` | Urgent fixes; use the ChatOps Fast-Track after merging |

Never commit directly to `main`.

---

## Local Development Workflow

### 1. Configure Databricks CLI for your sandbox

```bash
databricks configure --host <your-sandbox-workspace-url>
```

### 2. Deploy to your personal sandbox

Each developer gets an isolated namespace scoped to their username and current branch:

```bash
task db-deploy:sandbox
```

To override the catalog at deploy time:

```bash
databricks bundle deploy -t sandbox --var "catalog_name=experimental_catalog"
```

### 3. Run unit tests locally

Unit tests validate YAML schema, naming conventions, `file_path` existence, and SQL syntax — no live Databricks connection required:

```bash
task test:unit
```

### 4. Validate the bundle before pushing

```bash
task bundle:validate
```

This runs `databricks bundle validate` and catches schema errors before they hit CI.

---

## Testing Locally with `act`

[`act`](https://github.com/nektos/act) lets you run GitHub Actions workflows locally without pushing to GitHub. This is the recommended way to iterate on workflow changes.

### Install `act` (Fedora)

```bash
sudo dnf install act
```

Or via the install script:

```bash
curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash
```

### Run specific workflows

```bash
# Simulate a pull_request event (lint + unit tests)
act pull_request

# Simulate a push to main (staging deployment)
act push

# Run a specific job within a workflow
act push -j deploy-staging
```

> `act` requires Docker. Secrets can be supplied via a local `.secrets` file — **never commit this file**. It is already listed in `.gitignore`.

Example `.secrets` file:

```
DATABRICKS_HOST=https://your-workspace.azuredatabricks.net
DATABRICKS_TOKEN=dapi...
TEAMS_WEBHOOK_URL=https://...
```

---

## Pull Request Process

1. Branch from `main` using the naming convention above.
2. Write code with conforming commit messages throughout.
3. Ensure `task bundle:validate` and `task test:unit` pass locally.
4. Open a PR against `main`. The `lint.yml` CI workflow will run automatically.
5. Obtain at least one peer review approval.
6. Squash-merge or merge with conforming commit message. This triggers Staging deployment and integration tests automatically.
7. If `release-please` opens a Release PR, review the generated changelog and merge it to trigger Production deployment.

---

## ChatOps Fast-Track (`/release`)

For urgent hotfixes that cannot wait for the standard release cycle:

1. Open (or identify) a PR with your change.
2. Comment `/release` on the PR.
3. The bot will post a confirmation comment, merge the PR, and trigger the Production deployment pipeline immediately.
4. Monitor the Actions run — a Teams notification will fire on completion or failure.

> Fast-Track bypasses the Release PR step; `release-please` will reconcile the version on the next standard cycle. Use sparingly.

---

## Environment Summary

| Environment | Trigger | Identity | Purpose |
|---|---|---|---|
| Sandbox | `task db-deploy:sandbox` (manual) | Developer PAT | Isolated personal iteration |
| Staging | Push to `main` | CI token | Integration testing |
| Production | Merge Release PR or `/release` | Service Principal | Live workloads |

---

## Secrets Reference

The following secrets must be configured in GitHub repository (or environment) settings before CI workflows can run:

| Secret | Description |
|---|---|
| `DATABRICKS_HOST` | Workspace URL for the target environment |
| `DATABRICKS_TOKEN` | PAT or SP token for authentication |
| `PROD_SP_ID` | Service Principal ID for Production deployments |
| `TEAMS_WEBHOOK_URL` | Incoming webhook URL for MS Teams notifications |

Contact a platform engineer if you need access provisioned.

---

## Getting Help

- Check the [Databricks Asset Bundles docs](https://docs.databricks.com/en/dev-tools/bundles/index.html) for DAB configuration reference.
- Check the [Taskfile docs](https://taskfile.dev/usage/) for task runner usage.
- Open a GitHub Issue for bugs or platform questions.
- Tag `@platform-eng` in your PR for urgent reviews.
