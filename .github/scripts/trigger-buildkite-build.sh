#!/usr/bin/env bash
# Create a Buildkite build on a unionai/cloud pipeline via the REST API.
#
# Usage: trigger-buildkite-build.sh <pipeline-slug> [KEY=VALUE ...]
#
# Each KEY=VALUE becomes a build env var. TRIGGER_PROVENANCE is always added,
# as "ingress-nginx@<sha> by <actor>". The build runs cloud's main: the
# pipeline's repository is unionai/cloud.
#
# Requires BUILDKITE_API_TOKEN (write_builds scope), plus GITHUB_SHA and
# GITHUB_ACTOR (set by Actions).
set -euo pipefail

pipeline="${1:?pipeline slug required}"
shift

provenance="ingress-nginx@${GITHUB_SHA} by ${GITHUB_ACTOR}"
env_json='{}'
for kv in "$@"; do
  env_json="$(jq -c --arg k "${kv%%=*}" --arg v "${kv#*=}" '. + {($k): $v}' <<<"$env_json")"
done
env_json="$(jq -c --arg v "$provenance" '. + {TRIGGER_PROVENANCE: $v}' <<<"$env_json")"

body="$(jq -n --arg message "$provenance: trigger ${pipeline}" --argjson env "$env_json" \
  '{commit: "HEAD", branch: "main", message: $message, env: $env}')"

echo "Triggering unionai/${pipeline} with env: ${env_json}"
curl --fail --silent --show-error -X POST \
  -H "Authorization: Bearer ${BUILDKITE_API_TOKEN}" \
  "https://api.buildkite.com/v2/organizations/unionai/pipelines/${pipeline}/builds" \
  -d "$body" |
  jq -r '"Created build: \(.web_url)"'
