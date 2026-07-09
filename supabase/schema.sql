# Supabase 一键建表 SQL
# 打开后直接 Run：https://supabase.com/dashboard/project/jbwkkdinxtaryuwrhbti/sql/new

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

INSERT INTO forms (slug, name, description) VALUES
  ('sanfu-quiz', '三伏体质自测', '90秒测出三伏调理证型 + 五运六气先天体质评估')
ON CONFLICT (slug) DO NOTHING;

ALTER TABLE forms ENABLE ROW LEVEL SECURITY;
ALTER TABLE leads ENABLE ROW LEVEL SECURITY;
