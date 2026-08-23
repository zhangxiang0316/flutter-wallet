#!/usr/bin/env bash

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

failed=0

report_matches() {
  local label="$1"
  local pattern="$2"
  shift 2

  local matches
  matches="$(
    git grep -IlE "$pattern" -- "$@" ':!scripts/check_secrets.sh' 2>/dev/null || true
  )"
  if [[ -z "$matches" ]]; then
    return
  fi

  echo "Potential $label detected in tracked files:" >&2
  echo "$matches" >&2
  failed=1
}

tracked_sensitive_files="$(
  git ls-files |
    grep -E '(^|/)\.env($|\.)|\.(jks|keystore|p12|p8|mobileprovision)$|(^|/)(key\.properties|google-services\.json|GoogleService-Info\.plist|service-account[^/]*\.json)$' |
    grep -vE '^\.env\.example$' || true
)"
if [[ -n "$tracked_sensitive_files" ]]; then
  echo "Sensitive configuration files must not be tracked:" >&2
  echo "$tracked_sensitive_files" >&2
  failed=1
fi

report_matches \
  "private key PEM block" \
  '-----BEGIN ([A-Z0-9]+ )?PRIVATE KEY-----' \
  .
report_matches \
  "AWS access key" \
  '(AKIA|ASIA)[0-9A-Z]{16}' \
  .
report_matches \
  "GitHub access token" \
  'gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{40,}' \
  .
report_matches \
  "Google API key" \
  'AIza[0-9A-Za-z_-]{35}' \
  .
report_matches \
  "Slack token" \
  'xox[baprs]-[0-9A-Za-z-]{20,}' \
  .
report_matches \
  "live Stripe secret" \
  '[sr]k_live_[0-9A-Za-z]{16,}' \
  .
report_matches \
  "hard-coded wallet private key" \
  "(privateKeyHex|private[_-]?[Kk]ey|PRIVATE_KEY)[[:space:]]*[:=][[:space:]]*[\"'](0x)?[0-9a-fA-F]{64}[\"']" \
  lib android ios scripts
report_matches \
  "hard-coded wallet mnemonic" \
  "(mnemonic|seedPhrase)[[:space:]]*[:=][[:space:]]*[\"']([a-z]+[[:space:]]){11,23}[a-z]+[\"']" \
  lib android ios scripts

if ((failed != 0)); then
  echo "Sensitive information scan failed." >&2
  exit 1
fi

echo "Sensitive information scan passed."
