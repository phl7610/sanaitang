#!/usr/bin/env node
/**
 * Supabase 初始化：检查表结构，验证 service_role，测试写入
 * 用法：SUPABASE_URL=... SUPABASE_SERVICE_KEY=... node scripts/setup-supabase.mjs
 * SQL 建表需在 Supabase SQL Editor 执行 schema.sql（或使用 service_role + pg 连接）
 */
import { createClient } from '@supabase/supabase-js';

const url = process.env.SUPABASE_URL;
const key = process.env.SUPABASE_SERVICE_KEY;

if (!url || !key) {
  console.error('❌ 需要 SUPABASE_URL 和 SUPABASE_SERVICE_KEY');
  process.exit(1);
}

function decodeRole(jwt) {
  try {
    const payload = JSON.parse(Buffer.from(jwt.split('.')[1], 'base64url').toString());
    return payload.role;
  } catch {
    return 'unknown';
  }
}

async function main() {
  const role = decodeRole(key);
  console.log('→ Supabase URL:', url);
  console.log('→ Key role:', role);

  if (role !== 'service_role') {
    console.error('\n❌ SUPABASE_SERVICE_KEY 不是 service_role，而是', role);
    console.error('   请到 Supabase → Settings → API → service_role → Reveal');
    console.error('   更新 Netlify 环境变量后重新运行本脚本\n');
    process.exit(1);
  }

  const supabase = createClient(url, key);

  const { data: forms, error: formsErr } = await supabase.from('forms').select('slug, name');
  if (formsErr) {
    if (formsErr.message.includes('does not exist') || formsErr.code === '42P01') {
      console.error('\n❌ 数据表未创建');
      console.error('   请在 Supabase SQL Editor 执行: supabase/schema.sql');
      console.error('   或访问:', url.replace('.supabase.co', '.supabase.co/project/default/sql/new'));
      process.exit(1);
    }
    console.error('❌ 查询 forms 失败:', formsErr.message);
    process.exit(1);
  }

  console.log('✅ forms 表 OK，记录数:', forms.length);
  forms.forEach((f) => console.log('   -', f.slug, f.name));

  const { count, error: leadsErr } = await supabase
    .from('leads')
    .select('*', { count: 'exact', head: true });
  if (leadsErr) {
    console.error('❌ leads 表异常:', leadsErr.message);
    process.exit(1);
  }
  console.log('✅ leads 表 OK，当前线索数:', count ?? 0);

  // 写入探针（立即删除）
  const formId = forms.find((f) => f.slug === 'sanfu-quiz')?.slug;
  if (!formId && forms.length === 0) {
    console.error('❌ 缺少 sanfu-quiz 预置数据，请重新执行 schema.sql');
    process.exit(1);
  }

  const sanfu = forms.find((f) => f.slug === 'sanfu-quiz');
  if (!sanfu) {
    const { error: insFormErr } = await supabase.from('forms').insert({
      slug: 'sanfu-quiz',
      name: '三伏体质自测',
      description: '90秒测出三伏调理证型 + 五运六气先天体质评估',
    });
    if (insFormErr) {
      console.error('❌ 插入 sanfu-quiz 失败:', insFormErr.message);
      process.exit(1);
    }
    console.log('✅ 已补插 sanfu-quiz 表单记录');
  }

  const { data: formRow } = await supabase.from('forms').select('id').eq('slug', 'sanfu-quiz').single();
  const probePhone = '19900000000';
  const { data: inserted, error: insertErr } = await supabase
    .from('leads')
    .insert({
      form_id: formRow.id,
      name: '系统探针',
      phone: probePhone,
      gender: '女',
      result_summary: '探针测试',
      status: 'invalid',
    })
    .select('id')
    .single();

  if (insertErr) {
    console.error('❌ 写入测试失败:', insertErr.message);
    process.exit(1);
  }

  await supabase.from('leads').delete().eq('id', inserted.id);
  console.log('✅ 写入/删除探针成功，数据库完全就绪');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
