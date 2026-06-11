#!/usr/bin/env bash
# Enable merge blocking on main: PRs must pass the "PR merge gate" check (6 core CI jobs).
#
# Prerequisites:
#   - GitHub CLI: brew install gh && gh auth login
#   - Admin access to the repository
#
# Usage:
#   ./scripts/setup-branch-protection.sh
#   ./scripts/setup-branch-protection.sh --dry-run

set -euo pipefail

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI (gh) is required. Install: brew install gh" >&2
  exit 1
fi

REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
DEFAULT_BRANCH="$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)"

echo "Repository: $REPO"
echo "Default branch: $DEFAULT_BRANCH"
echo "Required status check: PR merge gate (6 core CI jobs)"
echo ""

RULESET_PAYLOAD="$(cat <<EOF
{
  "name": "Protect $DEFAULT_BRANCH - require PR merge gate",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/$DEFAULT_BRANCH"],
      "exclude": []
    }
  },
  "rules": [
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": false,
        "require_code_owner_review": false,
        "require_last_push_approval": false
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": true,
        "required_status_checks": [
          {
            "context": "PR merge gate"
          }
        ]
      }
    }
  ]
}
EOF
)"

if $DRY_RUN; then
  echo "Dry run — ruleset payload:"
  echo "$RULESET_PAYLOAD"
  exit 0
fi

echo "Creating repository ruleset..."
gh api "repos/$REPO/rulesets" --method POST --input - <<<"$RULESET_PAYLOAD"

echo ""
echo "Done. Pull requests targeting $DEFAULT_BRANCH are blocked until:"
echo "  1. All 6 core CI jobs pass, and"
echo "  2. The PR merge gate check is green."
echo ""
echo "Verify under: GitHub → Settings → Rules → Rulesets"
