#!/usr/bin/env bash
# 一键推送到 GitHub（首次运行前需配置 Token）
set -euo pipefail

REPO="seadragon123/sanaitang-forms"
BRANCH="main"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

cd "$ROOT"

# 从 .env.local 读取（可选）
if [[ -f .env.local ]]; then
  # shellcheck disable=SC2046
  export $(grep -v '^#' .env.local | grep GITHUB_TOKEN | xargs) 2>/dev/null || true
fi

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo "❌ 未设置 GITHUB_TOKEN"
  echo ""
  echo "请按以下步骤操作："
  echo "1. 打开 https://github.com/settings/tokens/new"
  echo "2. Note 填 sanaitang-forms，勾选 repo + workflow 权限"
  echo "3. 生成并复制 token，然后执行："
  echo ""
  echo "   GITHUB_TOKEN=你的token ./scripts/push-to-github.sh"
  echo ""
  echo "或写入 .env.local："
  echo "   GITHUB_TOKEN=你的token"
  exit 1
fi

echo "→ 推送到 https://github.com/${REPO} (${BRANCH})"
# GitHub 要求：用户名用 x-access-token，密码才是 PAT（不能写成 https://TOKEN@...）
export GIT_TERMINAL_PROMPT=0
git push "https://x-access-token:${GITHUB_TOKEN}@github.com/${REPO}.git" "${BRANCH}"

echo ""
echo "✅ 推送成功！"
echo "   仓库：https://github.com/${REPO}"
echo ""
echo "下一步（Netlify 自动部署）："
echo "   1. Netlify → Import from Git → 选 ${REPO}"
echo "   或在 GitHub Secrets 配置 NETLIFY_AUTH_TOKEN + NETLIFY_SITE_ID"
echo "   详见 AUTO-DEPLOY.md"
