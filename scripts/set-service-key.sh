#!/usr/bin/env bash
# 将 Supabase service_role 写入 Netlify（勿提交 Git）
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export CI=true

# shellcheck source=scripts/phl7610.config.sh
source "$ROOT/scripts/phl7610.config.sh"

if [[ -f .env.local ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env.local
  set +a
fi

EXPECTED_PROJECT_REF="$SUPABASE_PROJECT_REF"
NETLIFY_SITE_ID="${NETLIFY_SITE_ID:-}"

KEY="${1:-${SUPABASE_SERVICE_KEY:-}}"
if [[ -z "$KEY" ]]; then
  echo "请打开【本项目】Supabase API 设置，复制 service_role（不是 anon）："
  echo "https://supabase.com/dashboard/project/${EXPECTED_PROJECT_REF}/settings/api"
  echo ""
  read -rsp "粘贴 service_role key: " KEY
  echo ""
fi

if [[ -z "$KEY" ]]; then
  echo "❌ 未提供 key"
  exit 1
fi

read -r KEY_REF KEY_ROLE <<EOF
$(node -e "
  const p = JSON.parse(Buffer.from(process.argv[1].split('.')[1],'base64url'));
  console.log(p.ref + ' ' + p.role);
" "$KEY")
EOF

if [[ "$KEY_ROLE" != "service_role" ]]; then
  echo "❌ 这不是 service_role（当前: ${KEY_ROLE}），请重新复制"
  exit 1
fi

if [[ "$KEY_REF" != "$EXPECTED_PROJECT_REF" ]]; then
  echo "❌ 密钥与项目不匹配！"
  echo "   密钥来自: ${KEY_REF}，应使用: ${EXPECTED_PROJECT_REF}"
  exit 1
fi

if [[ -n "$NETLIFY_SITE_ID" ]]; then
  npx netlify-cli link --id "$NETLIFY_SITE_ID" 2>/dev/null || true
  npx netlify-cli env:set SUPABASE_SERVICE_KEY "$KEY" --context production,deploy-preview,branch-deploy --force
  npx netlify-cli env:set SUPABASE_URL "$SUPABASE_URL" --context production,deploy-preview,branch-deploy --force
  echo "✅ 已更新 Netlify 环境变量"
else
  echo "⚠️  未设置 NETLIFY_SITE_ID，跳过 Netlify。请写入 .env.local 后重试"
fi

export SUPABASE_URL SUPABASE_SERVICE_KEY="$KEY"
node scripts/setup-supabase.mjs

echo ""
echo "→ push 代码后 Netlify 会自动部署，或运行: ./scripts/setup-phl7610.sh"
