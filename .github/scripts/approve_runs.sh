#!/usr/bin/env bash
set -euo pipefail

branch="${1:?usage: approve_runs.sh <branch> <head sha>}"
head="${2:?usage: approve_runs.sh <branch> <head sha>}"
: "${GITHUB_REPOSITORY:?}"
[[ "$head" =~ ^[0-9a-f]{40}$ ]] || {
  echo "not a commit hash: $head" >&2
  exit 1
}

approved=0
quiet=0
for _ in $(seq 1 30); do
  ids="$(gh api "repos/$GITHUB_REPOSITORY/actions/runs?head_sha=$head&event=pull_request&status=action_required" \
    --jq ".workflow_runs[] | select(.head_branch == \"$branch\" and .head_repository.full_name == \"$GITHUB_REPOSITORY\") | .id")"
  if [[ -n "$ids" ]]; then
    for id in $ids; do
      gh api -X POST "repos/$GITHUB_REPOSITORY/actions/runs/$id/approve"
      approved=$((approved + 1))
    done
    quiet=0
  else
    quiet=$((quiet + 1))
    if ((approved > 0 && quiet >= 6)); then
      break
    fi
  fi
  sleep 10
done
echo "approved $approved runs"
