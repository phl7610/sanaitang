#!/usr/bin/env bash
# phl7610 首次自动配置向导（交互式，约 5 分钟）
# 用法: ./scripts/init-phl7610.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# shellcheck source=scripts/phl7610.config.sh
source "$ROOT/scripts/phl7610.config.sh"

ENV_FILE="$ROOT/.env.local"

echo "╔══════════════════════════════════════════════╗"
echo "║  phl7610 首次自动配置向导                      ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

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
NETLIFY_AUTH_TOKEN=

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
  echo "【1/3】GitHub Token（phl7610）"
  echo "  打开: https://github.com/settings/tokens/new?scopes=repo&description=sanaitang-deploy"
  read -rsp "  粘贴 GITHUB_TOKEN: " GITHUB_TOKEN
  echo ""
  sed -i.bak "s|^GITHUB_TOKEN=.*|GITHUB_TOKEN=${GITHUB_TOKEN}|" "$ENV_FILE" && rm -f "$ENV_FILE.bak"
fi

# ── 3. Supabase service_role ──
if [[ -z "${SUPABASE_SERVICE_KEY:-}" ]]; then
  echo ""
  echo "【2/3】Supabase service_role"
  echo "  打开: https://supabase.com/dashboard/project/${SUPABASE_PROJECT_REF}/settings/api"
  echo "  复制 service_role（不是 anon）"
  echo ""
  echo "  若尚未建表，请先在 SQL Editor 执行 supabase/schema.sql："
  echo "  https://supabase.com/dashboard/project/${SUPABASE_PROJECT_REF}/sql/new"
  read -rsp "  粘贴 SUPABASE_SERVICE_KEY: " SUPABASE_SERVICE_KEY
  echo ""
  sed -i.bak "s|^SUPABASE_SERVICE_KEY=.*|SUPABASE_SERVICE_KEY=${SUPABASE_SERVICE_KEY}|" "$ENV_FILE" && rm -f "$ENV_FILE.bak"
fi

# ── 4. 推送 GitHub ──
echo ""
echo "【3/3】推送 GitHub + 验证 Supabase…"
export GITHUB_TOKEN SUPABASE_SERVICE_KEY ADMIN_PASSWORD
source "$ENV_FILE"
export GITHUB_TOKEN SUPABASE_SERVICE_KEY ADMIN_PASSWORD

# 先推送（不需要 NETLIFY_SITE_ID）
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
git push "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPO}.git" "${GITHUB_BRANCH}" 2>/dev/null \
  || git push "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPO}.git" "${GITHUB_BRANCH}" --force

echo "✅ GitHub: https://github.com/${GITHUB_REPO}"

export SUPABASE_URL
node scripts/setup-supabase.mjs && echo "✅ Supabase 连接正常" || {
  echo "⚠️  Supabase 探针失败，请确认已执行 schema.sql"
}

# ── 5. Netlify ──
echo ""
if [[ -z "${NETLIFY_SITE_ID:-}" ]]; then
  echo "══════════════════════════════════════════════"
  echo "  Netlify 一次性手动步骤（约 2 分钟）"
  echo "══════════════════════════════════════════════"
  echo "  1. 用 GitHub phl7610 登录: https://app.netlify.com/start"
  echo "  2. Import → 选 ${GITHUB_REPO}"
  echo "  3. Build: npm install · Publish: public · Functions: netlify/functions"
  echo "  4. Deploy 完成后 → Site configuration → General → 复制 Site ID"
  echo ""
  read -rp "  粘贴 NETLIFY_SITE_ID: " NETLIFY_SITE_ID
  sed -i.bak "s|^NETLIFY_SITE_ID=.*|NETLIFY_SITE_ID=${NETLIFY_SITE_ID}|" "$ENV_FILE" && rm -f "$ENV_FILE.bak"
fi

echo ""
echo "→ 写入 Netlify 环境变量…"
export NETLIFY_SITE_ID
source "$ENV_FILE"
./scripts/setup-phl7610.sh

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║  ✅ phl7610 配置完成！                         ║"
echo "╠══════════════════════════════════════════════╣"
echo "║  GitHub:  https://github.com/${GITHUB_REPO}"
  echo "║  自测:    /forms/sanfu-quiz/"
echo "║  后台:    /admin/"
echo "║  密码:    见 .env.local ADMIN_PASSWORD"
echo "╚══════════════════════════════════════════════╝"
