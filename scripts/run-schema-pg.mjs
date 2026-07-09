#!/usr/bin/env node
/** 用数据库直连执行 schema.sql（需 SUPABASE_DB_URL） */
const fs = require('fs');
const path = require('path');

async function main() {
  const dbUrl = process.env.SUPABASE_DB_URL;
  if (!dbUrl) {
    console.error('❌ 需要 SUPABASE_DB_URL');
    console.error('   Supabase → Settings → Database → Connection string → URI');
    console.error('   格式: postgresql://postgres.[ref]:[密码]@aws-0-xxx.pooler.supabase.com:6543/postgres');
    process.exit(1);
  }

  let pg;
  try {
    pg = require('pg');
  } catch {
    console.error('→ 安装 pg…');
    require('child_process').execSync('npm install pg --no-save', { stdio: 'inherit' });
    pg = require('pg');
  }

  const sql = fs.readFileSync(path.join(__dirname, '../supabase/schema.sql'), 'utf8');
  const client = new pg.Client({ connectionString: dbUrl, ssl: { rejectUnauthorized: false } });
  await client.connect();
  await client.query(sql);
  await client.end();
  console.log('✅ schema.sql 执行成功');
}

main().catch((e) => {
  console.error('❌', e.message);
  process.exit(1);
});
