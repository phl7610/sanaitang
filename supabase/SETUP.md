# Supabase 配置清单（约 10 分钟）

## 第一步：创建项目

1. 打开 https://supabase.com 并登录
2. 点击 **New project**
3. 填写：
   - Name: `sanaitang-forms`
   - Database Password: **记下来**（仅 Supabase 内部用）
   - Region: 选 **Singapore** 或 **Tokyo**（离国内较近）

等待约 2 分钟项目创建完成。

---

## 第二步：执行建表 SQL

1. 左侧菜单 → **SQL Editor**
2. 点击 **New query**
3. 打开本仓库 `supabase/schema.sql`，全选复制粘贴
4. 点击 **Run**

成功后会创建：
- `forms` 表（含 `sanfu-quiz` 预置记录）
- `leads` 表（统一线索库）

验证：左侧 **Table Editor** → 应看到 `forms` 有 1 条「三伏体质自测」。

---

## 第三步：复制 API 密钥

1. 左侧 **Project Settings**（齿轮）→ **API**
2. 复制以下两项（稍后填入 Netlify）：

| 名称 | 位置 | 填入 Netlify 变量 |
|------|------|-------------------|
| Project URL | Project URL | `SUPABASE_URL` |
| service_role | Project API keys → service_role → Reveal | `SUPABASE_SERVICE_KEY` |

⚠️ **切勿**把 `service_role` 写入前端 HTML 或提交到 GitHub。

---

## 第四步：填入 Netlify 环境变量

Netlify 站点 → **Site configuration** → **Environment variables** → **Add a variable**：

```
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_SERVICE_KEY=eyJhbGciOi...
ADMIN_PASSWORD=你设置的强密码
```

保存后 **Trigger deploy** 重新部署。

---

## 第五步：验证

1. 打开 `https://你的站点.netlify.app/forms/sanfu-quiz/`
2. 完成一次自测并提交
3. Supabase **Table Editor** → `leads` 应出现 1 条记录
4. 打开 `https://你的站点.netlify.app/admin/` 用密码登录查看

---

## 常见问题

**提交后 leads 表没数据？**
- 检查 Netlify Functions 日志（Netlify → Functions → submit-lead）
- 确认环境变量已配置且已重新部署

**admin 登录失败？**
- 确认 `ADMIN_PASSWORD` 与输入一致
- 部署后环境变量才生效，需重新 deploy

**新增表单？**
```sql
INSERT INTO forms (slug, name, description) VALUES
  ('your-slug', '表单名称', '描述');
```
