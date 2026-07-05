# TokenBot Organization GitHub Workflows

This repository contains organization-wide GitHub Actions workflows and automation for TokenBot CI/CD health monitoring.

## 📋 Contents

### Workflow Templates

- **`ci-health-check.yml`** — Daily CI health checks (1:00 AM PT / 9:00 AM UTC)
- **`issue-triage.yml`** — Daily issue triage and priority reports (1:15 AM PT / 9:15 AM UTC)

### Repository Conventions

- **Auto-delete head branches on merge** — enabled org-wide; see the **Repository Settings** section below

## 🎯 CI Health Check Automation

### How It Works

1. **Daily Health Checks** run at 1:00 AM Pacific Time (9:00 AM UTC)
2. Executes full CI suite on `develop` branch:
   - Lint
   - Typecheck (Node.js/TypeScript repos)
   - Tests
   - Build
   - HTML validation (static sites)
3. Tracks **consecutive failures** using state-tracking issues
4. Creates detailed failure issues **only after 2+ consecutive failures** (reduces noise)
5. Auto-closes state trackers when checks pass

### Supported Repo Types

| Type | Detection | CI Steps |
|------|-----------|----------|
| **Node.js (npm)** | `package.json` without pnpm | lint, typecheck, test, build |
| **Node.js (pnpm)** | `package.json` with pnpm | lint, typecheck, test, build |
| **Python** | `pyproject.toml` or `setup.py` | ruff, pytest |
| **Static Site** | No package files | HTML validation |

### Setup Per Repo

1. Copy workflow template to target repo:
   ```bash
   cp workflow-templates/ci-health-check.yml <repo>/.github/workflows/
   ```

2. Ensure repo has required labels (will be created automatically if missing):
   - `ci`
   - `automated`
   - `lint-failure`
   - `typecheck-failure`
   - `test-failure`
   - `build-failure`
   - `deploy-failure`
   - `ci-health-state` (for state tracking)

3. Test via manual dispatch:
   ```bash
   gh workflow run ci-health-check.yml --repo tokenbot-org/<repo>
   ```

### Automated Issue Format

Issues are created with:
- **Title:** `🚨 CI Health Check Failed: <step> (consecutive failure #N)`
- **Labels:** `ci`, `automated`, `<category>-failure`
- **Body:** Detailed failure report with:
  - Workflow run link
  - Failed steps
  - Suggested fix workflow
  - Related commit/run info

### Manual Fix Workflow

When an automated issue is created:

1. **Pull latest develop:**
   ```bash
   git checkout develop && git pull origin develop
   ```

2. **Reproduce failure locally:**
   ```bash
   npm ci              # or pnpm install
   npm run lint        # or the failing command
   ```

3. **Fix the issue** (edit code, update deps, etc.)

4. **Run full local CI:**
   ```bash
   npm run lint && npx tsc --noEmit && npm test && npm run build
   ```

5. **Commit locally:**
   ```bash
   git add .
   git commit -m "fix(ci): resolve <issue> from health check"
   ```

6. **Merge to develop locally:**
   ```bash
   git checkout develop
   git merge <branch> --no-ff
   ```

7. **STOP** — Request confirmation before pushing:
   ```bash
   # DO NOT run this without approval:
   # git push origin develop
   ```

8. **After push approval:**
   ```bash
   git push origin develop
   ```

9. **Close the issue** and reference the fix commit

## 📊 Issue Triage Automation

### How It Works

1. **Daily Triage** runs at 1:15 AM Pacific Time (9:15 AM UTC)
2. Queries all open `ci` + `automated` issues
3. Categorizes by failure type (lint, typecheck, test, build, deploy)
4. Creates/updates triage report issue with:
   - Priority ranking (Critical → High → Medium)
   - Category breakdown
   - Recommended action order

### Triage Report Format

- **🔴 Critical:** Build/deploy failures blocking releases
- **🟠 High:** Test failures affecting quality
- **🟡 Medium:** Lint/typecheck issues

### Using Triage Reports

1. Address **Critical** issues first (block releases)
2. Fix **High** priority items next (quality/stability)
3. Batch **Medium** issues for cleanup sprints

## 🏷️ Label Reference

| Label | Purpose |
|-------|---------|
| `ci` | CI/CD related issue |
| `automated` | Created by automation |
| `ci-health-state` | State tracking for consecutive failures |
| `triage-report` | Daily triage summary |
| `lint-failure` | Lint errors |
| `typecheck-failure` | TypeScript type errors |
| `test-failure` | Unit/integration test failures |
| `build-failure` | Build process errors |
| `deploy-failure` | Deployment verification failures |

## ⚙️ Repository Settings

### Auto-delete head branches on merge

All active repos have **"Automatically delete head branches"** enabled
(`delete_branch_on_merge=true`). When a PR merges, its head branch —
`feat/*`, `fix/*`, `chore/*`, `ci/*`, `docs/*`, `dependabot/*`, etc. — is
deleted automatically. No cleanup workflow required.

**Long-lived branches are never touched.** GitHub does not auto-delete a
**protected** branch (nor the default branch, nor one that still has other
open PRs). So a `develop → main` promotion PR keeps `develop` intact even
though `develop` is the head of that PR. This safety net holds only while the
long-lived branches stay protected — `develop` + `main` on every repo that
has them, and `dev` + `main` on `liquidation-reversal-signals` (it uses
`dev`, not `develop`). Confirm protection with:

```bash
gh api repos/tokenbot-org/<repo>/branches/develop --jq '.protected'   # expect: true
```

There is **no org-wide toggle** — the setting is per-repo. Enable it with:

```bash
gh api -X PATCH repos/tokenbot-org/<repo> -F delete_branch_on_merge=true
```

Enabled across all 18 active repos on 2026-07-05. Archived/sunset repos are
intentionally excluded — do not re-enable them.

## 🔧 Maintenance

### Adding New Repo

1. Enable auto-delete head branches (see **Repository Settings** above):
   ```bash
   gh api -X PATCH repos/tokenbot-org/<repo> -F delete_branch_on_merge=true
   ```
2. Confirm `develop` / `main` are protected — this keeps `develop → main` promotion PRs safe from auto-delete
3. Copy workflow templates to new repo
4. Verify `.github/actions/setup-node` exists (or use default setup)
5. Run manual dispatch to test
6. Monitor for first scheduled run

### Excluding a Repo

Remove the workflow files from the repo:
```bash
git rm .github/workflows/ci-health-check.yml .github/workflows/issue-triage.yml
```

### Adjusting Schedule

Edit cron expressions in workflow files:
- `0 9 * * *` = 1:00 AM PST (9:00 AM UTC)
- `15 9 * * *` = 1:15 AM PST (9:15 AM UTC)

**Note:** Los Angeles uses PST (UTC-8) in winter and PDT (UTC-7) in summer. We use PST year-round for consistency.

### Changing Failure Threshold

Currently set to **2+ consecutive failures**. To adjust:

Edit `ci-health-check.yml`:
```yaml
if: steps.results.outputs.has_failures == 'true' && steps.state.outputs.consecutive >= 2
```

Change `>= 2` to desired threshold (e.g., `>= 3` for 3+ failures).

## 📝 Design Decisions

### Why 2+ Consecutive Failures?

- **Reduces noise:** Transient failures (network glitches, race conditions) don't create issues
- **Signals real problems:** Persistent failures indicate code/config issues
- **Balances urgency:** Catches regressions quickly without alert fatigue

### Why Separate Health Check + Triage?

- **Health check** is per-repo, runs CI commands, creates issues
- **Triage** is per-repo, aggregates/prioritizes existing issues
- Separation allows independent schedules and clear responsibilities

### Why Manual Push Confirmation?

- **Safety:** Prevents untested code from reaching shared branches
- **Review:** Encourages local verification before pushing
- **Compliance:** Matches existing TokenBot workflow rules

## 🚀 Rollout Plan

### Phase 1: Test on 2-3 repos
1. app-dashboard (Next.js/npm)
2. rest-api (Node.js/TypeScript/npm)
3. monitor-v2 (Turborepo/pnpm)

### Phase 2: Expand to remaining repos
- Frontend: admin-dashboard, trading-bot-dashboard, market-maker-dashboard, status-page
- Backend: mcp-server, trading-bot, market-maker-bot, webhooks-service, data-models
- SDK/CLI: tokenbot-sdk-node, tokenbot-sdk-python, tokenbot-cli
- Static: tokenbot-landing

### Phase 3: Monitor and tune
- Review issue quality/noise ratio
- Adjust thresholds if needed
- Add custom checks for specific repos (e.g., drift detection for SDKs)

## 📚 Related

- [TokenBot GitHub Organization](https://github.com/tokenbot-org)
- [Workflow Syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [GitHub CLI](https://cli.github.com/)
