#!/usr/bin/env bash
set -euo pipefail

failures=0

check_absent() {
  local label="$1"
  local pattern="$2"
  shift 2

  if command -v rg >/dev/null 2>&1; then
    if rg -n -I --hidden --glob '!.git/**' --glob '!scripts/public-readiness-check.sh' "$pattern" "$@"; then
      echo "public-readiness-check: found ${label}" >&2
      failures=$((failures + 1))
    fi
    return
  fi

  if grep -R -E -n -I --exclude-dir=.git --exclude=public-readiness-check.sh "$pattern" "$@"; then
    echo "public-readiness-check: found ${label}" >&2
    failures=$((failures + 1))
  fi
}

contains_fixed_string() {
  local pattern="$1"
  local file="$2"

  if command -v rg >/dev/null 2>&1; then
    rg -q --fixed-strings "$pattern" "$file"
    return
  fi

  grep -F -q "$pattern" "$file"
}

mac_users='/(Us''ers|home)/[A-Za-z0-9_.-]+'
win_users='[A-Z]:\\Us''ers\\[A-Za-z0-9_.-]+'
local_path_pattern="${mac_users}|${win_users}"
email_pattern='[A-Za-z0-9._%+-]+''@''[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
gh_classic='gh''p_'
gh_fine_grained='github''_pat_'
openai_key='s''k-''[A-Za-z0-9]'
aws_key='AK''IA[0-9A-Z]{16}'
private_key='BEGIN (RSA|OPENSSH|PRIVATE) K''EY'
context7_key='CONTEXT7''_API_KEY'
secret_pattern="${gh_classic}|${gh_fine_grained}|${openai_key}|${aws_key}|${private_key}|${context7_key}"
chat_marker='Chat''GPT'
claude_marker='C''laude Code'
research_marker='deep''-research|Deep'' Research'
citation_prefix="$(printf '\357\210\200')"
citation_marker="${citation_prefix}|file''cite|turn[0-9]+"
ai_trace_pattern="${chat_marker}|${claude_marker}|${research_marker}|${citation_marker}"

check_absent "local absolute path" "$local_path_pattern" .
check_absent "personal email or non-noreply email" "$email_pattern" .
check_absent "secret-like token" "$secret_pattern" .
check_absent "AI transcript artifact" "$ai_trace_pattern" .

required_files=(
  README.md
  LICENSE
  SECURITY.md
  CODE_OF_CONDUCT.md
  assets/readme/header.png
  fictional-drug-and-disease-ref/openapi.json
)

for file in "${required_files[@]}"; do
  if [ ! -f "$file" ]; then
    echo "public-readiness-check: missing required file: $file" >&2
    failures=$((failures + 1))
  fi
done

required_readme_sections=(
  '## DISCLAIMER'
  '## 主な特徴'
  '## 仕様の置き場所'
  '## 現在の関連リポジトリ'
  '## ライセンス'
)

for section in "${required_readme_sections[@]}"; do
  if ! contains_fixed_string "$section" README.md; then
    echo "public-readiness-check: README is missing section: $section" >&2
    failures=$((failures + 1))
  fi
done

if [ "$failures" -ne 0 ]; then
  exit 1
fi

echo "public-readiness-check: OK"
