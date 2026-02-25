#!/usr/bin/env bash
set -euo pipefail

# Deploy CI health automation workflows to TokenBot repos
# Usage: bash scripts/deploy-to-repos.sh [repo-name]
# If no repo specified, prompts for each repo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Repo lists
BACKEND_REPOS=(
  "rest-api"
  "mcp-server"
  "trading-bot"
  "market-maker-bot"
  "webhooks-service"
  "data-models"
  "monitor-v2"
)

FRONTEND_REPOS=(
  "app-dashboard"
  "admin-dashboard"
  "trading-bot-dashboard"
  "market-maker-dashboard"
  "status-page"
)

SDK_CLI_REPOS=(
  "tokenbot-sdk-node"
  "tokenbot-sdk-python"
  "tokenbot-cli"
)

STATIC_REPOS=(
  "tokenbot-landing"
)

# Excluded: graphql-api (requires MongoDB/Redis services)

ALL_REPOS=(
  "${BACKEND_REPOS[@]}"
  "${FRONTEND_REPOS[@]}"
  "${SDK_CLI_REPOS[@]}"
  "${STATIC_REPOS[@]}"
)

# Required labels
LABELS=(
  "ci:0052CC:CI/CD related"
  "automated:1D76DB:Created by automation"
  "ci-health-state:FBCA04:State tracking for consecutive failures"
  "triage-report:0E8A16:Daily triage summary"
  "lint-failure:D93F0B:Lint errors"
  "typecheck-failure:D93F0B:TypeScript type errors"
  "test-failure:D93F0B:Unit/integration test failures"
  "build-failure:D93F0B:Build process errors"
  "deploy-failure:D93F0B:Deployment verification failures"
)

create_labels() {
  local repo="$1"
  echo "Creating labels in $repo..."
  
  for label_spec in "${LABELS[@]}"; do
    IFS=':' read -r name color description <<< "$label_spec"
    gh label create "$name" \
      --repo "tokenbot-org/$repo" \
      --color "$color" \
      --description "$description" \
      --force 2>/dev/null || echo "  ↳ $name already exists or create failed"
  done
}

deploy_workflows() {
  local repo="$1"
  local repo_path="$HOME/repos/$repo"
  
  if [ ! -d "$repo_path" ]; then
    echo "⚠️  Repo not found locally: $repo_path"
    return 1
  fi
  
  echo "Deploying workflows to $repo..."
  
  # Create workflows directory if needed
  mkdir -p "$repo_path/.github/workflows"
  
  # Copy workflow templates
  cp "$ROOT_DIR/workflow-templates/ci-health-check.yml" \
     "$repo_path/.github/workflows/ci-health-check.yml"
  
  cp "$ROOT_DIR/workflow-templates/issue-triage.yml" \
     "$repo_path/.github/workflows/issue-triage.yml"
  
  echo "✅ Workflows copied to $repo"
}

process_repo() {
  local repo="$1"
  echo ""
  echo "========================================="
  echo "REPO: $repo"
  echo "========================================="
  
  # Create labels
  create_labels "$repo"
  
  # Deploy workflows
  deploy_workflows "$repo"
  
  echo "✅ $repo setup complete"
}

# Main execution
if [ $# -eq 1 ]; then
  # Single repo mode
  process_repo "$1"
else
  # Interactive mode
  echo "TokenBot CI Health Automation Deployment"
  echo "========================================"
  echo ""
  echo "This will deploy ci-health-check.yml and issue-triage.yml"
  echo "to all TokenBot repos and create required labels."
  echo ""
  echo "Total repos: ${#ALL_REPOS[@]}"
  echo ""
  read -p "Deploy to all repos? (y/N): " -n 1 -r
  echo ""
  
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    for repo in "${ALL_REPOS[@]}"; do
      process_repo "$repo"
    done
    echo ""
    echo "========================================="
    echo "✅ Deployment complete!"
    echo "========================================="
    echo ""
    echo "Next steps:"
    echo "1. Review changes in each repo (git status)"
    echo "2. Commit locally with: git commit -m 'feat(ci): add health check automation'"
    echo "3. Test with manual dispatch: gh workflow run ci-health-check.yml --repo tokenbot-org/<repo>"
    echo "4. STOP - request push confirmation before: git push origin <branch>"
  else
    echo "Deployment cancelled."
  fi
fi
