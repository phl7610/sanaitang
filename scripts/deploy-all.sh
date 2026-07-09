#!/usr/bin/env bash
# 一键：GitHub 推送 + 验证 Supabase + 提示 Netlify
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export CI=true

PROJECT_REF="${SUPABASE_PROJECT_REF:-jbwkkdinxtaryuwrhbti}"
SUPABASE_URL="https://${PROJECT_REF}.supabase.co"
REPO="phl7610/sanaitang"
BRANCH="main"

echo "═══ 1/4 Git 提交 ═══"
git add -A
if git diff --cached --quiet; then
  echo "→ 无新改动，跳过 commit"
else
  git commit -m "deploy: $(date '+%Y-%m-%d %H:%M') 同步配置"
fi

echo ""
echo "═══ 2/4 推送到 GitHub (${REPO}) ═══"
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  git push "https://x-access-token:${GITHUB_TOKEN}@github.com/${REPO}.git" "${BRANCH}"
  echo "✅ GitHub 推送成功"
else
  echo "⚠️  未设置 GITHUB_TOKEN，尝试 git push origin ${BRANCH}…"
  git push -u origin "${BRANCH}" || {
    echo ""
    echo "❌ 推送失败。请使用 phl7610 账号 Token："
    echo "   GITHUB_TOKEN=你的token ./scripts/deploy-all.sh"
    exit 1
  }
fi

echo ""
echo "═══ 3/4 Supabase 环境变量（Netlify）═══"
npx netlify-cli link --id ffe2761b-4b16-451c-a002-fd6f81e1f17d 2>/dev/null || true
npx netlify-cli env:set SUPABASE_URL "$SUPABASE_URL" --context production,deploy-preview,branch-deploy --force

if [[ -n "${SUPABASE_SERVICE_KEY:-}" ]]; then
  ROLE=$(node -e "console.log(JSON.parse(Buffer.from(process.argv[1].split('.')[1],'base64url')).role)" "$SUPABASE_SERVICE_KEY")
  REF=$(node -e "console.log(JSON.parse(Buffer.from(process.argv[1].split('.')[1],'base64url')).ref)" "$SUPABASE_SERVICE_KEY")
  if [[ "$ROLE" != "service_role" || "$REF" != "$PROJECT_REF" ]]; then
    echo "❌ SUPABASE_SERVICE_KEY 须为 ${PROJECT_REF} 的 service_role"
    exit 1
  fi
  npx netlify-cli env:set SUPABASE_SERVICE_KEY "$SUPABASE_SERVICE_KEY" --context production,deploy-preview,branch-deploy --force
  export SUPABASE_URL SUPABASE_SERVICE_KEY
  node scripts/setup-supabase.mjs
else
  echo "⚠️  未设置 SUPABASE_SERVICE_KEY，跳过写库探针"
  echo "   请运行: ./scripts/set-service-key.sh"
fi

echo ""
echo "═══ 4/4 Netlify 部署 ═══"
echo "→ 若已连接 GitHub，push 后 Netlify 会自动部署（方案 A）"
echo "   站点: https://satform.netlify.app"
echo ""
echo "若需手动触发: CI=true npx netlify-cli deploy --prod"
echo ""
echo "数据库建表（若未执行）:"
echo "   https://supabase.com/dashboard/project/${PROJECT_REF}/sql/new"
echo "   粘贴 supabase/schema.sql → Run"
