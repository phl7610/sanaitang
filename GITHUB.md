# 推送到 GitHub · seadragon123

仓库地址（推送目标）：

**https://github.com/seadragon123/sanaitang-forms**

---

## 第一步：在 GitHub 创建空仓库

1. 打开 https://github.com/new
2. 填写：
   - Repository name: `sanaitang-forms`
   - Description: `三艾堂在线测试多表单平台`
   - 选择 **Public** 或 Private
   - **不要**勾选 "Add a README"（本地已有代码）
3. 点击 **Create repository**

---

## 第二步：在本机终端推送

```bash
cd "/Users/sanat/三艾堂/三伏推广/online-forms-platform"

# 远程已配置为：
# origin → https://github.com/seadragon123/sanaitang-forms.git

git push -u origin main
```

首次推送会要求 GitHub 登录：
- 推荐用 **Personal Access Token** 作为密码
- 或配置 SSH：`git remote set-url origin git@github.com:seadragon123/sanaitang-forms.git`

### 生成 Token（若 HTTPS 登录失败）

1. GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Generate new token → 勾选 `repo`
3. 复制 token，`git push` 时密码处粘贴 token

---

## 第三步：Netlify 连接此仓库

1. https://app.netlify.com → Add new site → Import an existing project
2. 选 **GitHub** → 授权 → 选择 `seadragon123/sanaitang-forms`
3. 构建设置（一般自动识别）：
   - Build command: `npm install`
   - Publish directory: `public`
4. 添加环境变量（见 `supabase/SETUP.md`）
5. Deploy site

---

## 验证 remote 配置

```bash
git remote -v
# 应显示：
# origin  https://github.com/seadragon123/sanaitang-forms.git (fetch)
# origin  https://github.com/seadragon123/sanaitang-forms.git (push)
```

---

## 之后每次更新

```bash
git add .
git commit -m "描述你的修改"
git push
```

Netlify 会自动重新部署。
