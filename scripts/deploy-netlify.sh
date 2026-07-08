#!/usr/bin/env bash
# Netlify 一键部署（需 NETLIFY_AUTH_TOKEN）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
SITE_NAME="${NETLIFY_SITE_NAME:-sanaitang-forms}"

if [[ -f .env.local ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env.local
  set +a
fi

if [[ -z "${NETLIFY_AUTH_TOKEN:-}" ]]; then
  echo "❌ 未设置 NETLIFY_AUTH_TOKEN"
  echo ""
  echo "1. 打开 https://app.netlify.com/user/applications#personal-access-tokens"
  echo "2. New access token → 复制"
  echo "3. 创建 .env.local（参考 .env.example）填入 token 和 Supabase 配置"
  echo "4. 重新运行：./scripts/deploy-netlify.sh"
  exit 1
fi

export NETLIFY_AUTH_TOKEN

echo "→ 安装依赖…"
npm install

DEPLOY_ARGS=(--prod --dir=public --functions=netlify/functions --message "Deploy $(date '+%Y-%m-%d %H:%M')")

if [[ -n "${NETLIFY_SITE_ID:-}" ]]; then
  DEPLOY_ARGS+=(--site "$NETLIFY_SITE_ID")
else
  DEPLOY_ARGS+=(--create-site "$SITE_NAME")
fi

echo "→ 部署到 Netlify…"
npx netlify-cli deploy "${DEPLOY_ARGS[@]}"

# 同步环境变量（Functions 需要）
if [[ -n "${SUPABASE_URL:-}" ]]; then
  echo "→ 同步环境变量…"
  npx netlify-cli env:set SUPABASE_URL "$SUPABASE_URL" --context production,deploy-preview 2>/dev/null || true
  npx netlify-cli env:set SUPABASE_SERVICE_KEY "$SUPABASE_SERVICE_KEY" --context production,deploy-preview 2>/dev/null || true
  npx netlify-cli env:set ADMIN_PASSWORD "${ADMIN_PASSWORD:-changeme}" --context production,deploy-preview 2>/dev/null || true
fi

echo ""
echo "✅ 部署完成！"
npx netlify-cli status 2>/dev/null || true
echo ""
echo "📌 连接 GitHub 实现 push 自动部署："
echo "   https://app.netlify.com → 你的站点 → Site configuration → Build & deploy → Link repository"
echo "   选择 seadragon123/sanaitang-forms · main · build: npm install · publish: public"
