# 自动部署指南 · seadragon123/sanaitang-forms

仓库地址：https://github.com/seadragon123/sanaitang-forms（已创建，待推送代码）

---

## 方案 A：Netlify 连接 GitHub（推荐，最简单）

推送代码后，Netlify 每次 `git push` 自动部署。

### 1. 推送代码到 GitHub

**生成 Token：** https://github.com/settings/tokens/new → 勾选 `repo`

**终端执行：**

```bash
cd "/Users/sanat/三艾堂/三伏推广/online-forms-platform"
chmod +x scripts/push-to-github.sh
GITHUB_TOKEN=粘贴你的token ./scripts/push-to-github.sh
```

### 2. Netlify 导入仓库

1. https://app.netlify.com → **Add new site** → **Import an existing project**
2. **GitHub** → 授权 → 选择 `seadragon123/sanaitang-forms`
3. 构建设置（自动识别）：
   - Build command: `npm install`
   - Publish directory: `public`
   - Functions: `netlify/functions`
4. **Environment variables** 添加：

| Key | Value |
|-----|-------|
| `SUPABASE_URL` | Supabase Project URL |
| `SUPABASE_SERVICE_KEY` | service_role key |
| `ADMIN_PASSWORD` | 管理后台密码 |

5. **Deploy site**

之后每次 `git push`，Netlify **自动重新部署**。

---

## 方案 B：GitHub Actions 部署 Netlify

适合已在 Netlify 创建站点、想用 Actions 控制部署。

### 1. 获取 Netlify Token

Netlify → User settings → Applications → Personal access tokens → New token

### 2. 获取 Site ID

Netlify → Site → Site configuration → General → Site ID

### 3. GitHub Secrets

仓库 → Settings → Secrets and variables → Actions → New repository secret：

| Secret | 值 |
|--------|-----|
| `NETLIFY_AUTH_TOKEN` | Netlify token |
| `NETLIFY_SITE_ID` | 站点 ID |

Supabase 等运行时变量仍在 **Netlify 环境变量**中配置（Functions 读取）。

### 4. 推送代码

推送后 `.github/workflows/deploy-netlify.yml` 会在每次 push 到 `main` 时自动部署。

---

## 部署后访问

| 页面 | 路径 |
|------|------|
| 表单首页 | `/` |
| 三伏自测 | `/forms/sanfu-quiz/` |
| 管理后台 | `/admin/` |

---

## 日常更新流程

```bash
# 修改代码后
git add .
git commit -m "更新说明"
GITHUB_TOKEN=xxx ./scripts/push-to-github.sh
# 或已配置 git credential 后直接：git push
```

Netlify 约 1–2 分钟自动上线。

---

## 快速检查清单

- [ ] GitHub Token 已生成
- [ ] `./scripts/push-to-github.sh` 执行成功
- [ ] Supabase 已执行 `schema.sql`
- [ ] Netlify 环境变量已配置
- [ ] 自测提交后 Supabase `leads` 表有数据
- [ ] `/admin/` 可登录
