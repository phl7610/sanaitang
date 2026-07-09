#!/usr/bin/env bash
# 从 Netlify 读取 Supabase 配置 → 验证/初始化 → 部署 satform
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export CI=true

echo "═══ 1/4 链接 Netlify 站点 satform ═══"
npx netlify-cli link --id ffe2761b-4b16-451c-a002-fd6f81e1f17d 2>/dev/null || true

echo ""
echo "═══ 2/4 读取 Netlify 环境变量 ═══"
export SUPABASE_URL=$(npx netlify-cli env:get SUPABASE_URL --context production 2>/dev/null || true)
export SUPABASE_SERVICE_KEY=$(npx netlify-cli env:get SUPABASE_SERVICE_KEY --context production 2>/dev/null || true)
ADMIN_PW=$(npx netlify-cli env:get ADMIN_PASSWORD --context production 2>/dev/null || true)

if [[ -z "$SUPABASE_URL" || -z "$SUPABASE_SERVICE_KEY" ]]; then
  echo "❌ Netlify 未配置 SUPABASE_URL / SUPABASE_SERVICE_KEY"
  echo "   请到 https://app.netlify.com/projects/satform/configuration/env 添加"
  exit 1
fi

if [[ -z "$ADMIN_PW" ]]; then
  echo "→ 设置 ADMIN_PASSWORD…"
  ADMIN_PW="Sanaitang@${RANDOM}"
  npx netlify-cli env:set ADMIN_PASSWORD "$ADMIN_PW" --context production,deploy-preview --force
  echo "   已设置 ADMIN_PASSWORD（请记录，或在 Netlify 控制台修改）"
fi

echo ""
echo "═══ 3/4 验证 Supabase 数据库 ═══"
if ! node scripts/setup-supabase.mjs; then
  echo ""
  echo "┌─────────────────────────────────────────────────────────┐"
  echo "│ 若提示「数据表未创建」，请手动执行一次 SQL：              │"
  echo "│ 1. 打开 https://supabase.com/dashboard/project/tbgwjtqpiavxbbjrtcyk/sql/new │"
  echo "│ 2. 粘贴 supabase/schema.sql 全部内容 → Run              │"
  echo "│ 3. 若 service_role 填错，在 Netlify 更新 SUPABASE_SERVICE_KEY │"
  echo "│ 4. 重新运行: ./scripts/full-setup.sh                      │"
  echo "└─────────────────────────────────────────────────────────┘"
  exit 1
fi

echo ""
echo "═══ 4/4 部署到 satform.netlify.app ═══"
npm install --silent 2>/dev/null || npm install
npx netlify-cli deploy --prod --dir=public --functions=netlify/functions --message="Full setup deploy $(date '+%Y-%m-%d %H:%M')"

echo ""
echo "✅ 全部完成"
echo "   站点: https://satform.netlify.app"
echo "   自测: https://satform.netlify.app/forms/sanfu-quiz/"
echo "   后台: https://satform.netlify.app/admin/"
npx netlify-cli status 2>/dev/null || true
