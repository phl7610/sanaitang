# 自动部署指南 · phl7610/sanaitang

仓库：https://github.com/phl7610/sanaitang  
站点：https://satform.netlify.app

采用 **Netlify 连接 GitHub**，每次 `git push` 到 `main` 自动部署。

---

## 一次性配置（Netlify 控制台）

1. https://app.netlify.com → 站点 **satform** → **Project configuration** → **Build & deploy** → **Continuous deployment**
2. 确认已关联仓库 **`phl7610/sanaitang`**，Production branch 为 **`main`**
3. 构建设置（与 `netlify.toml` 一致）：

| 项 | 值 |
|----|-----|
| Build command | `npm install` |
| Publish directory | `public` |
| Functions directory | `netlify/functions` |

4. **Environment variables**（Production）：

| Key | Value |
|-----|-------|
| `SUPABASE_URL` | `https://tbgwjtqpiavxbbjrtcyk.supabase.co` |
| `SUPABASE_SERVICE_KEY` | 项目 `tbgwjtqpiavxbbjrtcyk` 的 **service_role** |
| `ADMIN_PASSWORD` | 管理后台登录密码 |

5. Supabase 已执行 `supabase/schema.sql`（forms / leads 表）

---

## 日常更新（推送即部署）

```bash
cd "/Users/sanat/三艾堂/三伏推广/online-forms-platform"

git add .
git commit -m "更新说明"
git push origin main
```

或使用脚本（需 GitHub Token）：

```bash
GITHUB_TOKEN=你的token ./scripts/push-to-github.sh
```

推送后 Netlify → **Deploys** 约 1–2 分钟自动完成。

---

## 部署后访问

| 页面 | URL |
|------|-----|
| 表单首页 | https://satform.netlify.app/ |
| 三伏自测 | https://satform.netlify.app/forms/sanfu-quiz/ |
| 管理后台 | https://satform.netlify.app/admin/ |

---

## 检查清单

- [ ] Netlify 关联 `phl7610/sanaitang`（非旧仓库）
- [ ] 环境变量 URL 与 service_role 为同一 Supabase 项目
- [ ] `git push origin main` 后 Deploys 出现新记录且 Published
- [ ] 自测提交后 Supabase `leads` 表有数据
- [ ] `/admin/` 可登录

---

## 说明

- 本项目**不使用** GitHub Actions 部署 Netlify（避免与 Git 集成重复触发）。
- 构建配置以仓库根目录 `netlify.toml` 为准。
