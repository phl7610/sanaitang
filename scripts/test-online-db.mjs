#!/usr/bin/env node
/**
 * 线上全链路数据库连接测试（不打印密钥）
 * 用法: node scripts/test-online-db.mjs
 */
import { readFileSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';
import { execSync } from 'child_process';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, '..');
const BASE = process.env.SITE_URL || 'https://sanaitang-phl7610.netlify.app';
const API = `${BASE}/.netlify/functions`;

function loadEnvLocal() {
  try {
    const text = readFileSync(resolve(ROOT, '.env.local'), 'utf8');
    const env = {};
    for (const line of text.split('\n')) {
      const m = line.match(/^([A-Z_]+)=(.*)$/);
      if (m) env[m[1]] = m[2];
    }
    return env;
  } catch {
    return {};
  }
}

function decodeJwtMeta(jwt) {
  try {
    return JSON.parse(Buffer.from(jwt.split('.')[1], 'base64url').toString());
  } catch {
    return null;
  }
}

async function request(path, options = {}) {
  const res = await fetch(`${API}${path}`, options);
  let body;
  try {
    body = await res.json();
  } catch {
    body = { _raw: await res.text() };
  }
  return { status: res.status, body };
}

function pass(name, detail = '') {
  console.log(`✅ ${name}${detail ? ` — ${detail}` : ''}`);
  results.push({ name, ok: true, detail });
}

function fail(name, detail = '') {
  console.log(`❌ ${name}${detail ? ` — ${detail}` : ''}`);
  results.push({ name, ok: false, detail });
}

const results = [];
const env = loadEnvLocal();
const adminPassword = process.env.ADMIN_PASSWORD || env.ADMIN_PASSWORD || '';
const expectedRef = env.SUPABASE_PROJECT_REF || 'jbwkkdinxtaryuwrhbti';
const probePhone = `139${String(Date.now()).slice(-8)}`;

console.log(`→ 测试站点: ${BASE}\n`);

function getNetlifyEnv(key) {
  try {
    return execSync(`npx netlify-cli env:get ${key} --context production`, {
      cwd: ROOT,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
  } catch {
    return '';
  }
}

// 0. Netlify 环境变量诊断（不打印密钥内容）
const remoteUrl = getNetlifyEnv('SUPABASE_URL');
const remoteKey = getNetlifyEnv('SUPABASE_SERVICE_KEY');
const remoteAdmin = getNetlifyEnv('ADMIN_PASSWORD');
const remoteKeyMeta = decodeJwtMeta(remoteKey);

if (!remoteUrl) fail('Netlify SUPABASE_URL', '未配置');
else if (remoteUrl === env.SUPABASE_URL) pass('Netlify SUPABASE_URL', '与本地一致');
else fail('Netlify SUPABASE_URL', '与本地不一致');

if (!remoteKey) fail('Netlify SUPABASE_SERVICE_KEY', '未配置');
else if (!remoteKeyMeta) fail('Netlify SUPABASE_SERVICE_KEY', '不是有效 JWT');
else if (remoteKeyMeta.role !== 'service_role') fail('Netlify SUPABASE_SERVICE_KEY', `role=${remoteKeyMeta.role}`);
else if (remoteKeyMeta.ref !== expectedRef) {
  fail('Netlify SUPABASE_SERVICE_KEY', `项目 ref=${remoteKeyMeta.ref}，与 URL 目标 ${expectedRef} 不匹配`);
} else pass('Netlify SUPABASE_SERVICE_KEY', `ref=${remoteKeyMeta.ref}`);

if (!remoteAdmin) fail('Netlify ADMIN_PASSWORD', '未配置');
else if (remoteAdmin === adminPassword) pass('Netlify ADMIN_PASSWORD', `长度=${remoteAdmin.length}`);
else fail('Netlify ADMIN_PASSWORD', `与本地不一致（remote=${remoteAdmin.length} local=${adminPassword.length}）`);

console.log('');

// 1. 静态页
for (const path of ['/forms/sanfu-quiz/', '/admin/']) {
  const res = await fetch(`${BASE}${path}`);
  if (res.status === 200) pass(`页面 ${path}`, `HTTP ${res.status}`);
  else fail(`页面 ${path}`, `HTTP ${res.status}`);
}

// 2. 本地 .env.local 密钥格式
const localKey = env.SUPABASE_SERVICE_KEY || '';
const localMeta = decodeJwtMeta(localKey);
if (!localKey) fail('本地 SUPABASE_SERVICE_KEY', '未配置');
else if (localKey.startsWith('ghp_')) fail('本地 SUPABASE_SERVICE_KEY', '误填 GitHub Token，应为 Supabase service_role');
else if (!localMeta) fail('本地 SUPABASE_SERVICE_KEY', '不是有效 JWT');
else if (localMeta.role !== 'service_role') fail('本地 SUPABASE_SERVICE_KEY', `role=${localMeta.role}`);
else if (localMeta.ref !== expectedRef) fail('本地 SUPABASE_SERVICE_KEY', `项目 ref=${localMeta.ref}，期望 ${expectedRef}`);
else pass('本地 SUPABASE_SERVICE_KEY', `ref=${localMeta.ref}`);

// 3. submit-lead 写库
const submit = await request('/submit-lead', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    formSlug: 'sanfu-quiz',
    name: '线上探针',
    phone: probePhone,
    gender: '女',
    primarySyndrome: '气虚质',
  }),
});

let leadId = null;
if (submit.status === 201 && submit.body?.ok) {
  leadId = submit.body.id;
  pass('submit-lead 写库', `id=${leadId}`);
} else {
  fail('submit-lead 写库', `${submit.body?.error || 'unknown'} (HTTP ${submit.status})`);
}

// 4. admin-login
if (!adminPassword) {
  fail('admin-login', '本地未配置 ADMIN_PASSWORD');
} else {
  const badLogin = await request('/admin-login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ password: 'wrong-password-probe' }),
  });
  if (badLogin.status === 401) pass('admin-login 拒绝错误密码');
  else fail('admin-login 拒绝错误密码', badLogin.body?.error || `HTTP ${badLogin.status}`);

  const goodLogin = await request('/admin-login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ password: adminPassword }),
  });
  if (goodLogin.status === 200 && goodLogin.body?.token) {
    pass('admin-login 正确密码');
  } else {
    fail('admin-login 正确密码', `${goodLogin.body?.error || 'unknown'} (HTTP ${goodLogin.status}, pwLen=${adminPassword.length})`);
  }

  if (goodLogin.status === 200 && goodLogin.body?.token) {
    const token = goodLogin.body.token;

    // 5. admin-leads 读库
    const leads = await request('/admin-leads?form=sanfu-quiz&limit=5', {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (leads.status === 200 && Array.isArray(leads.body?.leads)) {
      const total = leads.body.pagination?.total ?? leads.body.leads.length;
      pass('admin-leads 读库', `total=${total}`);
      if (leadId) {
        const found = leads.body.leads.some((l) => l.id === leadId);
        if (found) pass('admin-leads 回读探针', `找到 id=${leadId}`);
        else fail('admin-leads 回读探针', '列表中未找到刚写入的记录');
      }
    } else {
      fail('admin-leads 读库', leads.body?.error || `HTTP ${leads.status}`);
    }

    // 6. admin-forms
    const forms = await request('/admin-forms', {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (forms.status === 200 && Array.isArray(forms.body?.forms)) {
      const sanfu = forms.body.forms.find((f) => f.slug === 'sanfu-quiz');
      if (sanfu) pass('admin-forms 读库', `sanfu-quiz active=${sanfu.isActive ?? sanfu.is_active}`);
      else fail('admin-forms 读库', '缺少 sanfu-quiz');
    } else {
      fail('admin-forms 读库', forms.body?.error || `HTTP ${forms.status}`);
    }
  }
}

console.log('\n── 汇总 ──');
const ok = results.filter((r) => r.ok).length;
const bad = results.filter((r) => !r.ok).length;
console.log(`通过 ${ok} / 失败 ${bad} / 共 ${results.length}`);
process.exit(bad > 0 ? 1 : 0);
