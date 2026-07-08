const { getSupabase, jsonResponse, corsPreflightResponse } = require('./lib/supabase');
const { requireAdmin } = require('./lib/auth');

exports.handler = async (event) => {
  if (event.httpMethod === 'OPTIONS') return corsPreflightResponse();

  const auth = requireAdmin(event);
  if (!auth.ok) {
    return { ...auth.response, headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } };
  }

  if (event.httpMethod !== 'GET') {
    return jsonResponse(405, { error: 'Method not allowed' });
  }

  try {
    const params = event.queryStringParameters || {};
    const formSlug = params.form || params.formSlug;
    const status = params.status;
    const dateFrom = params.from;
    const dateTo = params.to;

    const supabase = getSupabase();

    let query = supabase
      .from('leads')
      .select(
        `
        name, phone, gender, birth_year, contact_time,
        result_summary, result_detail, status, admin_note, created_at,
        forms!inner(slug, name)
      `
      )
      .order('created_at', { ascending: false })
      .limit(5000);

    if (formSlug) query = query.eq('forms.slug', formSlug);
    if (status) query = query.eq('status', status);
    if (dateFrom) query = query.gte('created_at', dateFrom);
    if (dateTo) query = query.lte('created_at', dateTo + 'T23:59:59');

    const { data, error } = await query;
    if (error) throw error;

    const BOM = '\uFEFF';
    const headers = [
      '表单', '姓名', '手机', '性别', '出生年', '联系时段',
      '主结果', '兼夹证型', '匹配度', '干支', '岁运',
      '状态', '备注', '提交时间',
    ];

    const rows = (data || []).map((row) => {
      const d = row.result_detail || {};
      const w = d.wylqReport || {};
      return [
        row.forms?.name || '',
        row.name,
        row.phone,
        row.gender || '',
        row.birth_year || '',
        row.contact_time || '',
        row.result_summary || '',
        d.secondarySyndrome || '',
        w.matchScore != null ? w.matchScore + '%' : '',
        w.ganzhi || '',
        w.wuyun || '',
        row.status || '',
        row.admin_note || '',
        row.created_at ? new Date(row.created_at).toLocaleString('zh-CN') : '',
      ];
    });

    const escapeCsv = (val) => {
      const s = String(val ?? '');
      if (/[",\n\r]/.test(s)) return `"${s.replace(/"/g, '""')}"`;
      return s;
    };

    const csv = BOM + [headers, ...rows].map((r) => r.map(escapeCsv).join(',')).join('\n');

    const filename = `leads_${formSlug || 'all'}_${new Date().toISOString().slice(0, 10)}.csv`;

    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'text/csv; charset=utf-8',
        'Content-Disposition': `attachment; filename="${filename}"`,
        'Access-Control-Allow-Origin': '*',
      },
      body: csv,
    };
  } catch (err) {
    console.error(err);
    return jsonResponse(500, { error: err.message });
  }
};
