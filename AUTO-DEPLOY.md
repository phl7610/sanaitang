# 全自动部署 · phl7610 统一账号

GitHub、Netlify、Supabase 均使用 **GitHub 账号 phl7610**（phl7610@163.com）。

| 服务 | 地址 |
|------|------|
| GitHub 仓库 | https://github.com/phl7610/sanaitang |
| Supabase 项目 | `jbwkkdinxtaryuwrhbti` |
| Netlify | Import `phl7610/sanaitang` 后自动部署 |

---

## 首次配置（约 15 分钟，仅一次）

### 1. 本地密钥文件

```bash
cd online-forms-platform
cp .env.example .env.local
```

填写 `.env.local`：

| 变量 | 获取方式 |
|------|----------|
| `GITHUB_TOKEN` | https://github.com/settings/tokens/new → **repo** |
| `SUPABASE_SERVICE_KEY` | Supabase → Settings → API → **service_role** |
| `ADMIN_PASSWORD` | 自设管理后台密码 |
| `NETLIFY_SITE_ID` | 完成步骤 3 后填入 |

### 2. Supabase 建表（仅一次）

https://supabase.com/dashboard/project/jbwkkdinxtaryuwrhbti/sql/new

粘贴 `supabase/schema.sql` → **Run**

### 3. Netlify 导入 GitHub（仅一次）

1. 用 **GitHub phl7610** 登录 https://app.netlify.com  
2. **Add new site** → **Import an existing project** → **GitHub**  
3. 选 **`phl7610/sanaitang`**（先运行一次 `./scripts/setup-phl7610.sh` 创建并推送仓库）  
4. 构建设置：

| 项 | 值 |
|----|-----|
| Build command | `npm install` |
| Publish directory | `public` |
| Functions | `netlify/functions` |

5. **Site configuration → General → Site ID** → 复制到 `.env.local` 的 `NETLIFY_SITE_ID`  
6. 再运行一次 `./scripts/setup-phl7610.sh` 写入环境变量  

### 4. Netlify CLI 登录 phl7610（可选）

```bash
npx netlify-cli logout
npx netlify-cli login   # 浏览器选 GitHub phl7610
```

---

## 日常全自动部署

```bash
./scripts/setup-phl7610.sh
```

脚本自动完成：

1. 创建 GitHub 仓库（若不存在）  
2. `git commit` + `push` 到 `phl7610/sanaitang`  
3. 验证 Supabase 连接  
4. 更新 Netlify 环境变量  
5. **Netlify 监听 GitHub push，自动构建上线**  

---

## 访问地址

部署完成后（站点 URL 以 Netlify 为准）：

| 页面 | 路径 |
|------|------|
| 三伏自测 | `/forms/sanfu-quiz/` |
| 管理后台 | `/admin/` |

---

## 检查清单

- [ ] `.env.local` 已配置且未提交 Git  
- [ ] `SUPABASE_SERVICE_KEY` 为 **service_role**（不是 anon）  
- [ ] Supabase `forms` / `leads` 表已创建  
- [ ] Netlify 关联 `phl7610/sanaitang`，Production branch = `main`  
- [ ] push 后 Deploys 显示 Published  
- [ ] 自测提交后 `leads` 表有数据  

---

## 说明

- 不使用 GitHub Actions 部署（避免与 Netlify Git 集成重复）。  
- 构建配置以根目录 `netlify.toml` 为准。  
- 旧账号 seadragon123 / phl0 的 satform 站点不再使用，统一迁移到 phl7610 Netlify。
