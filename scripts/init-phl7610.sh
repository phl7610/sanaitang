#!/usr/bin/env bash
# phl7610 首次自动配置向导（交互式，约 5 分钟）
# 用法: ./scripts/init-phl7610.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export CI=true

# shellcheck source=scripts/phl7610.config.sh
source "$ROOT/scripts/phl7610.config.sh"

ENV_FILE="$ROOT/.env.local"
NETLIFY_ACCOUNT_SLUG="${NETLIFY_ACCOUNT_SLUG:-sanaitang}"

echo "╔══════════════════════════════════════════════╗"
echo "║  phl7610 首次自动配置向导                      ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# ── 0. 确认 Netlify 登录 phl7610 ──
NETLIFY_EMAIL=$(npx netlify-cli status 2>&1 | sed -n 's/^Email: //p' | head -1 || true)
if [[ "$NETLIFY_EMAIL" != "phl7610@163.com" ]]; then
  echo "⚠️  Netlify CLI 当前不是 phl7610，正在切换…"
  npx netlify-cli logout 2>/dev/null || true
  npx netlify-cli login --new
fi
echo "✅ Netlify: ${NETLIFY_EMAIL:-phl7610@163.com}"

# ── 1. 创建 / 更新 .env.local ──
if [[ ! -f "$ENV_FILE" ]]; then
  ADMIN_PW="Sanaitang@$(openssl rand -hex 3)"
  cat > "$ENV_FILE" <<EOF
# phl7610 自动配置 $(date '+%Y-%m-%d')
GITHUB_USER=${GITHUB_USER}
GITHUB_TOKEN=

SUPABASE_PROJECT_REF=${SUPABASE_PROJECT_REF}
SUPABASE_URL=${SUPABASE_URL}
SUPABASE_SERVICE_KEY=

NETLIFY_SITE_ID=
NETLIFY_SITE_NAME=${NETLIFY_SITE_NAME}
NETLIFY_ACCOUNT_SLUG=${NETLIFY_ACCOUNT_SLUG}

ADMIN_PASSWORD=${ADMIN_PW}
EOF
  chmod 600 "$ENV_FILE"
  echo "✅ 已创建 .env.local（管理后台密码已自动生成）"
else
  echo "→ 使用已有 .env.local"
fi

set -a
# shellcheck disable=SC1091
source "$ENV_FILE"
set +a

# ── 2. GitHub Token ──
if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo ""
  echo "【1/4】GitHub Token（phl7610）"
  echo "  打开: https://github.com/settings/tokens/new?scopes=repo&description=sanaitang-deploy"
  read -rsp "  粘贴 GITHUB_TOKEN: " GITHUB_TOKEN
  echo ""
  if [[ "$(uname)" == "Darwin" ]]; then
    sed -i.bak "s|^GITHUB_TOKEN=.*|GITHUB_TOKEN=${GITHUB_TOKEN}|" "$ENV_FILE" && rm -f "$ENV_FILE.bak"
  else
    sed -i "s|^GITHUB_TOKEN=.*|GITHUB_TOKEN=${GITHUB_TOKEN}|" "$ENV_FILE"
  fi
fi

# ── 3. Supabase service_role ──
if [[ -z "${SUPABASE_SERVICE_KEY:-}" ]]; then
  echo ""
  echo "【2/4】Supabase service_role"
  echo "  打开: https://supabase.com/dashboard/project/${SUPABASE_PROJECT_REF}/settings/api"
  echo "  复制 service_role（不是 anon）"
  echo ""
  echo "  若尚未建表，请先在 SQL Editor 执行 supabase/schema.sql："
  echo "  https://supabase.com/dashboard/project/${SUPABASE_PROJECT_REF}/sql/new"
  read -rsp "  粘贴 SUPABASE_SERVICE_KEY: " SUPABASE_SERVICE_KEY
  echo ""
  if [[ "$(uname)" == "Darwin" ]]; then
    sed -i.bak "s|^SUPABASE_SERVICE_KEY=.*|SUPABASE_SERVICE_KEY=${SUPABASE_SERVICE_KEY}|" "$ENV_FILE" && rm -f "$ENV_FILE.bak"
  else
    sed -i "s|^SUPABASE_SERVICE_KEY=.*|SUPABASE_SERVICE_KEY=${SUPABASE_SERVICE_KEY}|" "$ENV_FILE"
  fi
fi

# ── 4. 推送 GitHub ──
echo ""
echo "【3/4】推送 GitHub + 验证 Supabase…"
# shellcheck disable=SC1091
source "$ENV_FILE"
export GITHUB_TOKEN SUPABASE_SERVICE_KEY ADMIN_PASSWORD SUPABASE_URL

HTTP=$(curl -sS -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  "https://api.github.com/repos/${GITHUB_REPO}" 2>/dev/null || echo "000")

if [[ "$HTTP" == "404" ]]; then
  echo "→ 创建 GitHub 仓库 ${GITHUB_REPO}…"
  curl -sS -X POST \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/user/repos" \
    -d '{"name":"sanaitang","description":"三艾堂三伏自测","private":false}' > /dev/null
fi

git remote set-url origin "https://github.com/${GITHUB_REPO}.git"
git add -A
git diff --cached --quiet || git commit -m "deploy: phl7610 init $(date '+%Y-%m-%d %H:%M')" || true
git push "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPO}.git" "${GITHUB_BRANCH}"

echo "✅ GitHub: https://github.com/${GITHUB_REPO}"

node scripts/setup-supabase.mjs && echo "✅ Supabase 连接正常" || {
  echo "⚠️  Supabase 探针失败，请确认已执行 schema.sql"
}

# ── 5. Netlify 站点 ──
echo ""
echo "【4/4】Netlify 站点 + 环境变量…"
# shellcheck disable=SC1091
source "$ENV_FILE"

if [[ -z "${NETLIFY_SITE_ID:-}" ]]; then
  if [[ -f .netlify/state.json ]] && node -e "const j=require('./.netlify/state.json'); process.exit(j.siteId?0:1)" 2>/dev/null; then
    NETLIFY_SITE_ID=$(node -e "console.log(require('./.netlify/state.json').siteId||'')")
    echo "→ 使用已链接站点 ${NETLIFY_SITE_ID}"
  else
    echo "→ 创建 Netlify 站点 ${NETLIFY_SITE_NAME}（团队 ${NETLIFY_ACCOUNT_SLUG}）…"
    npx netlify-cli sites:create --name "$NETLIFY_SITE_NAME" --account-slug "$NETLIFY_ACCOUNT_SLUG"
    NETLIFY_SITE_ID=$(node -e "console.log(require('./.netlify/state.json').siteId||'')")
  fi
  if [[ "$(uname)" == "Darwin" ]]; then
    sed -i.bak "s|^NETLIFY_SITE_ID=.*|NETLIFY_SITE_ID=${NETLIFY_SITE_ID}|" "$ENV_FILE" && rm -f "$ENV_FILE.bak"
  else
    sed -i "s|^NETLIFY_SITE_ID=.*|NETLIFY_SITE_ID=${NETLIFY_SITE_ID}|" "$ENV_FILE"
  fi
fi

export NETLIFY_SITE_ID
# shellcheck disable=SC1091
source "$ENV_FILE"
./scripts/setup-phl7610.sh

SITE_URL=$(npx netlify-cli status 2>&1 | sed -n 's/^Site URL:     //p' | head -1 || true)

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║  ✅ phl7610 配置完成！                         ║"
echo "╠══════════════════════════════════════════════╣"
echo "║  GitHub:  https://github.com/${GITHUB_REPO}"
echo "║  站点:    ${SITE_URL:-（见 Netlify 控制台）}"
echo "║  自测:    /forms/sanfu-quiz/"
echo "║  后台:    /admin/"
echo "║  密码:    见 .env.local ADMIN_PASSWORD"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "提示: Netlify 站点若未连 GitHub，请到控制台 Link repository → ${GITHUB_REPO}"
