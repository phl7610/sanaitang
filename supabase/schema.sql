-- 三艾堂 · 在线测试多表单平台
-- 在 Supabase SQL Editor 中执行

-- 表单注册表
CREATE TABLE IF NOT EXISTS forms (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug        TEXT UNIQUE NOT NULL,
  name        TEXT NOT NULL,
  description TEXT,
  is_active   BOOLEAN DEFAULT true,
  created_at  TIMESTAMPTZ DEFAULT now()
);

-- 统一线索表
CREATE TABLE IF NOT EXISTS leads (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  form_id           UUID NOT NULL REFERENCES forms(id),
  name              TEXT NOT NULL,
  phone             TEXT NOT NULL,
  gender            TEXT,
  birth_year        INT,
  contact_time      TEXT,
  result_summary    TEXT,
  result_detail     JSONB DEFAULT '{}',
  raw_payload       JSONB DEFAULT '{}',
  status            TEXT DEFAULT 'new' CHECK (status IN ('new', 'contacted', 'booked', 'visited', 'invalid')),
  admin_note        TEXT,
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_leads_form_id ON leads(form_id);
CREATE INDEX IF NOT EXISTS idx_leads_created_at ON leads(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_leads_phone ON leads(phone);
CREATE INDEX IF NOT EXISTS idx_leads_status ON leads(status);
CREATE INDEX IF NOT EXISTS idx_leads_result_summary ON leads(result_summary);

-- 自动更新 updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS leads_updated_at ON leads;
CREATE TRIGGER leads_updated_at
  BEFORE UPDATE ON leads
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- 预置：三伏自测（第一个表单）
INSERT INTO forms (slug, name, description) VALUES
  ('sanfu-quiz', '三伏体质自测', '90秒测出三伏调理证型 + 五运六气先天体质评估')
ON CONFLICT (slug) DO NOTHING;

-- Row Level Security：仅 service_role 可读写（API 通过 Netlify Functions 使用 service key）
ALTER TABLE forms ENABLE ROW LEVEL SECURITY;
ALTER TABLE leads ENABLE ROW LEVEL SECURITY;

-- 禁止 anon/authenticated 直接访问（所有操作走 Netlify Functions）
-- 不创建 public policy，默认拒绝
