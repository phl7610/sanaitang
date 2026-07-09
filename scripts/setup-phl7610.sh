#!/usr/bin/env bash
# phl7610 全自动部署：GitHub 推送 + Supabase 配置 + Netlify 环境变量
#
# 首次使用前：
#   1. 复制 .env.example → .env.local，填入 GITHUB_TOKEN、SUPABASE_SERVICE_KEY、ADMIN_PASSWORD
#   2. Netlify 用 GitHub(phl7610) 登录 → Import phl7610/sanaitang（见 AUTO-DEPLOY.md）
#   3. Supabase SQL Editor 执行 supabase/schema.sql（仅首次）
#
# 日常更新：
#   ./scripts/setup-phl7610.sh
#
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

GITHUB_TOKEN="${GITHUB_TOKEN:-}"
SUPABASE_SERVICE_KEY="${SUPABASE_SERVICE_KEY:-}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"
NETLIFY_SITE_ID="${NETLIFY_SITE_ID:-}"

echo "╔══════════════════════════════════════════════╗"
echo "║  phl7610 全自动部署 · ${GITHUB_REPO}          "
echo "╚══════════════════════════════════════════════╝"
echo ""

# ── 0. 检查 Token ──
if [[ -z "$GITHUB_TOKEN" ]]; then
  echo "❌ 请在 .env.local 设置 GITHUB_TOKEN"
  echo "   生成: https://github.com/settings/tokens/new → 勾选 repo"
  echo "   cp .env.example .env.local"
  exit 1
fi

# ── 1. 创建 GitHub 仓库（若不存在）──
echo "═══ 1/5 GitHub 仓库 ${GITHUB_REPO} ═══"
HTTP=$(curl -sS -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  "https://api.github.com/repos/${GITHUB_REPO}")

if [[ "$HTTP" == "404" ]]; then
  echo "→ 创建仓库 ${GITHUB_REPO}…"
  curl -sS -X POST \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/user/repos" \
    -d "{\"name\":\"sanaitang\",\"description\":\"三艾堂三伏自测多表单平台\",\"private\":false,\"auto_init\":false}" \
    > /dev/null
  echo "✅ 仓库已创建"
elif [[ "$HTTP" == "200" ]]; then
  echo "✅ 仓库已存在"
else
  echo "❌ 无法访问仓库 HTTP ${HTTP}，请确认 Token 属于 ${GITHUB_USER}"
  exit 1
fi

git remote set-url origin "https://github.com/${GITHUB_REPO}.git"

# ── 2. 提交并推送 ──
echo ""
echo "═══ 2/5 推送代码 ═══"
git add -A
if git diff --cached --quiet; then
  echo "→ 无新改动，跳过 commit"
else
  git commit -m "deploy: $(date '+%Y-%m-%d %H:%M') phl7610 自动部署"
fi

git push "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPO}.git" "${GITHUB_BRANCH}"
echo "✅ 已推送到 https://github.com/${GITHUB_REPO}"

# ── 3. Supabase 验证 ──
echo ""
echo "═══ 3/5 Supabase (${SUPABASE_PROJECT_REF}) ═══"
if [[ -z "$SUPABASE_SERVICE_KEY" ]]; then
  echo "⚠️  .env.local 未设置 SUPABASE_SERVICE_KEY，跳过数据库探针"
  echo "   获取: https://supabase.com/dashboard/project/${SUPABASE_PROJECT_REF}/settings/api"
  echo "   然后: ./scripts/set-service-key.sh 'service_role'"
else
  ROLE=$(node -e "console.log(JSON.parse(Buffer.from(process.argv[1].split('.')[1],'base64url')).role)" "$SUPABASE_SERVICE_KEY")
  REF=$(node -e "console.log(JSON.parse(Buffer.from(process.argv[1].split('.')[1],'base64url')).ref)" "$SUPABASE_SERVICE_KEY")
  if [[ "$ROLE" != "service_role" || "$REF" != "$SUPABASE_PROJECT_REF" ]]; then
    echo "❌ SUPABASE_SERVICE_KEY 须为 ${SUPABASE_PROJECT_REF} 的 service_role（当前 ref=${REF} role=${ROLE}）"
    exit 1
  fi
  export SUPABASE_URL SUPABASE_SERVICE_KEY
  if node scripts/setup-supabase.mjs; then
    echo "✅ Supabase 连接正常"
  else
    echo ""
    echo "⚠️  若提示表不存在，请先在 SQL Editor 执行 supabase/schema.sql："
    echo "   https://supabase.com/dashboard/project/${SUPABASE_PROJECT_REF}/sql/new"
    exit 1
  fi
fi

# ── 4. Netlify 环境变量 ──
echo ""
echo "═══ 4/5 Netlify 环境变量 ═══"
if [[ -z "$NETLIFY_SITE_ID" ]]; then
  echo "⚠️  未设置 NETLIFY_SITE_ID（.env.local）"
  echo "   请先在 phl7610 Netlify 导入 GitHub 仓库，然后："
  echo "   1. Site configuration → General → Site ID → 写入 .env.local"
  echo "   2. 重新运行本脚本"
  echo ""
  echo "   导入地址: https://app.netlify.com/start"
  echo "   仓库: ${GITHUB_REPO} · Build: npm install · Publish: public"
else
  npx netlify-cli link --id "$NETLIFY_SITE_ID" 2>/dev/null || true
  npx netlify-cli env:set SUPABASE_URL "$SUPABASE_URL" \
    --context production,deploy-preview,branch-deploy --force
  if [[ -n "$SUPABASE_SERVICE_KEY" ]]; then
    npx netlify-cli env:set SUPABASE_SERVICE_KEY "$SUPABASE_SERVICE_KEY" \
      --context production,deploy-preview,branch-deploy --force
  fi
  if [[ -n "$ADMIN_PASSWORD" ]]; then
    npx netlify-cli env:set ADMIN_PASSWORD "$ADMIN_PASSWORD" \
      --context production,deploy-preview,branch-deploy --force
  fi
  echo "✅ Netlify 环境变量已更新（站点 ${NETLIFY_SITE_ID}）"
fi

# ── 5. 部署说明 ──
echo ""
echo "═══ 5/5 部署 ═══"
if [[ -n "$NETLIFY_SITE_ID" ]]; then
  echo "→ Netlify 已连接 GitHub 时，本次 push 会自动触发部署"
  echo "   查看: https://app.netlify.com/projects/${NETLIFY_SITE_NAME}/deploys"
else
  echo "→ 完成 Netlify Import 后，每次 push 将自动部署"
fi
echo ""
echo "访问路径："
echo "   自测: /forms/sanfu-quiz/"
echo "   后台: /admin/"
echo ""
echo "✅ phl7610 全自动流程完成"
