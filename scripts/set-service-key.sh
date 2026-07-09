#!/usr/bin/env bash
# 将 Supabase service_role 写入 Netlify（勿提交 Git）
# 用法：
#   ./scripts/set-service-key.sh
#   ./scripts/set-service-key.sh 'eyJhbGci...service_role...'
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export CI=true

# 与 supabase/schema.sql 注释、Netlify 环境变量保持一致
EXPECTED_PROJECT_REF="tbgwjtqpiavxbbjrtcyk"
SUPABASE_URL="https://${EXPECTED_PROJECT_REF}.supabase.co"

KEY="${1:-}"
if [[ -z "$KEY" ]]; then
  echo "请打开【本项目】Supabase API 设置，复制 service_role（不是 anon）："
  echo "https://supabase.com/dashboard/project/${EXPECTED_PROJECT_REF}/settings/api"
  echo ""
  echo "⚠️  project ref 必须是: ${EXPECTED_PROJECT_REF}"
  echo "    （forms/leads 表已建在这个项目里）"
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
  echo "   密钥来自项目: ${KEY_REF}"
  echo "   应使用项目:   ${EXPECTED_PROJECT_REF}"
  echo ""
  echo "请到正确项目复制 service_role："
  echo "https://supabase.com/dashboard/project/${EXPECTED_PROJECT_REF}/settings/api"
  exit 1
fi

npx netlify-cli link --id ffe2761b-4b16-451c-a002-fd6f81e1f17d 2>/dev/null || true
npx netlify-cli env:set SUPABASE_SERVICE_KEY "$KEY" --context production,deploy-preview,branch-deploy --force
npx netlify-cli env:set SUPABASE_URL "$SUPABASE_URL" --context production,deploy-preview,branch-deploy --force

echo ""
echo "✅ 已更新 Netlify 环境变量（URL + service_role 已对齐）"
echo "→ 验证数据库连接…"
export SUPABASE_URL
export SUPABASE_SERVICE_KEY="$KEY"
node scripts/setup-supabase.mjs

echo ""
echo "→ 请重新部署 Netlify 使 Functions 生效："
echo "   CI=true npx netlify-cli deploy --prod"
