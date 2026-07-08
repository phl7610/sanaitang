# 三艾堂 · 在线测试多表单平台

GitHub + Netlify + Supabase 架构，支持多个 H5 自测表单统一收集线索、后台管理与 CSV 导出。

## 项目结构

```
online-forms-platform/
├── public/                    # 静态站点（Netlify 发布目录）
│   ├── index.html             # 表单入口页
│   └── forms/
│       └── sanfu-quiz/        # 三伏自测（第一个表单）
├── admin/index.html             # 管理后台源码（同步至 public/admin/）
├── netlify/functions/         # Serverless API
│   ├── submit-lead.js         # 提交线索
│   ├── admin-login.js         # 后台登录
│   ├── admin-forms.js         # 表单列表
│   ├── admin-leads.js         # 线索列表 / 更新状态
│   └── export-leads.js        # CSV 导出
├── supabase/schema.sql        # 数据库建表
└── netlify.toml
```

## 快速部署（约 30 分钟）

### 1. Supabase 数据库

1. 打开 [supabase.com](https://supabase.com) 注册并新建项目
2. 进入 **SQL Editor**，粘贴执行 `supabase/schema.sql`
3. 在 **Settings → API** 复制：
   - `Project URL` → `SUPABASE_URL`
   - `service_role` key → `SUPABASE_SERVICE_KEY`（⚠️ 仅用于服务端，勿暴露给前端）

### 2. GitHub 仓库

```bash
cd online-forms-platform
git init
git add .
git commit -m "init: 三艾堂在线测试多表单平台"
# 在 GitHub 创建仓库后：
git remote add origin https://github.com/你的用户名/sanaitang-forms.git
git push -u origin main
```

### 3. Netlify 部署

1. 登录 [netlify.com](https://netlify.com) → **Add new site** → **Import from Git**
2. 选择 GitHub 仓库
3. Build settings（通常自动识别）：
   - Build command: `npm install`
   - Publish directory: `public`
   - Functions directory: `netlify/functions`
4. **Site settings → Environment variables** 添加：

| 变量 | 值 |
|------|-----|
| `SUPABASE_URL` | Supabase Project URL |
| `SUPABASE_SERVICE_KEY` | service_role key |
| `ADMIN_PASSWORD` | 管理后台登录密码 |

5. 部署完成后访问：
   - 首页：`https://你的站点.netlify.app/`
   - 三伏自测：`https://你的站点.netlify.app/forms/sanfu-quiz/`
   - 管理后台：`https://你的站点.netlify.app/admin/`

### 4. 本地开发（可选）

```bash
npm install
cp .env.example .env   # 填入 Supabase 和密码
npx netlify dev        # 本地 http://localhost:8888
```

## API 说明

| 接口 | 方法 | 说明 |
|------|------|------|
| `/.netlify/functions/submit-lead` | POST | 提交线索，body 需含 `formSlug` |
| `/.netlify/functions/admin-login` | POST | 登录，返回 token |
| `/.netlify/functions/admin-forms` | GET | 表单列表（需 Authorization） |
| `/.netlify/functions/admin-leads` | GET/PATCH | 线索列表 / 更新状态 |
| `/.netlify/functions/export-leads` | GET | 导出 CSV |

## 新增一个测试表单

### 1. 注册表单（Supabase SQL）

```sql
INSERT INTO forms (slug, name, description) VALUES
  ('constitution-test', '九型体质测试', '了解您的中医体质类型');
```

### 2. 创建 H5 页面

```
public/forms/constitution-test/index.html
```

在页面 CONFIG 中设置：

```javascript
const CONFIG = {
  FORM_SLUG: 'constitution-test',
  API_URL: '/.netlify/functions/submit-lead',
};
```

提交时 POST 相同 API，带上 `formSlug` 和结果字段即可。

### 3. 添加入口链接

编辑 `public/index.html`，增加一张卡片链接到新表单。

后台会自动出现新 Tab，无需改 API 或管理页代码。

## 管理后台功能

- 按表单类型筛选（全部 / 三伏自测 / …）
- 按状态、日期筛选
- 线索详情（含五运六气、回访话术）
- 更新跟进状态与备注
- 一键导出 CSV（Excel 可直接打开）

## 安全说明

- Supabase `service_role` 仅存在于 Netlify 环境变量
- 管理 API 需 Bearer Token 认证
- 列表页手机号默认脱敏显示，详情页显示完整号码
- 生产环境请使用强密码

## 国内访问

Netlify 服务器在境外，微信内打开可能偏慢。正式推广建议：
- 绑定国内 CDN 加速静态页
- 或使用 Cloudflare 代理

---

三艾堂 · 彭海龙医师
