#!/usr/bin/env bash
# 将 GitHub 仓库关联到 Netlify 站点（实现 push 自动部署）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
REPO="phl7610/sanaitang"
BRANCH="main"

if [[ -f .env.local ]]; then
  set -a
  source .env.local
  set +a
fi

: "${NETLIFY_AUTH_TOKEN:?请先在 .env.local 设置 NETLIFY_AUTH_TOKEN}"

SITE_ID="${NETLIFY_SITE_ID:-}"
if [[ -z "$SITE_ID" && -f .netlify/state.json ]]; then
  SITE_ID=$(node -e "console.log(JSON.parse(require('fs').readFileSync('.netlify/state.json')).siteId||'')")
fi

if [[ -z "$SITE_ID" ]]; then
  echo "❌ 未找到 Site ID，请先运行 ./scripts/deploy-netlify.sh"
  exit 1
fi

echo "→ 关联 GitHub 仓库 ${REPO} 到站点 ${SITE_ID}…"

RESP=$(curl -sf -X PUT "https://api.netlify.com/api/v1/sites/${SITE_ID}" \
  -H "Authorization: Bearer ${NETLIFY_AUTH_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"repo\": {
      \"provider\": \"github\",
      \"repo_path\": \"${REPO}\",
      \"repo_branch\": \"${BRANCH}\",
      \"cmd\": \"npm install\",
      \"dir\": \"public\",
      \"functions_dir\": \"netlify/functions\"
    }
  }" 2>&1) || {
  echo "❌ API 关联失败（通常需先在 Netlify 安装 GitHub App）"
  echo ""
  echo "请手动操作（约 2 分钟）："
  echo "1. https://app.netlify.com/sites/${SITE_NAME:-sanaitang-forms}/configuration/deploys"
  echo "2. Link repository → GitHub → ${REPO}"
  echo "3. Branch: ${BRANCH} · Build: npm install · Publish: public"
  exit 1
}

echo "$RESP" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{const j=JSON.parse(d);console.log('✅ 已关联:', j.ssl_url||j.url||j.name)})"
