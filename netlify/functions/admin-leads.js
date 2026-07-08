const { getSupabase, jsonResponse, corsPreflightResponse, maskPhone } = require('./lib/supabase');
const { requireAdmin } = require('./lib/auth');

exports.handler = async (event) => {
  if (event.httpMethod === 'OPTIONS') return corsPreflightResponse();

  const auth = requireAdmin(event);
  if (!auth.ok) {
    return { ...auth.response, headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } };
  }

  if (event.httpMethod === 'PATCH') {
    try {
      const { id, status, adminNote } = JSON.parse(event.body || '{}');
      if (!id) return jsonResponse(400, { error: '缺少 id' });

      const updates = {};
      if (status) updates.status = status;
      if (adminNote !== undefined) updates.admin_note = adminNote;

      const supabase = getSupabase();
      const { error } = await supabase.from('leads').update(updates).eq('id', id);
      if (error) throw error;
      return jsonResponse(200, { ok: true });
    } catch (err) {
      return jsonResponse(500, { error: err.message });
    }
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
    const page = Math.max(1, parseInt(params.page || '1', 10));
    const limit = Math.min(100, Math.max(1, parseInt(params.limit || '20', 10)));
    const offset = (page - 1) * limit;

    const supabase = getSupabase();

    let query = supabase
      .from('leads')
      .select(
        `
        id, name, phone, gender, birth_year, contact_time,
        result_summary, result_detail, status, admin_note,
        created_at, updated_at,
        forms!inner(slug, name)
      `,
        { count: 'exact' }
      )
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1);

    if (formSlug) query = query.eq('forms.slug', formSlug);
    if (status) query = query.eq('status', status);
    if (dateFrom) query = query.gte('created_at', dateFrom);
    if (dateTo) query = query.lte('created_at', dateTo + 'T23:59:59');

    const { data, error, count } = await query;
    if (error) throw error;

    const leads = (data || []).map((row) => ({
      id: row.id,
      formSlug: row.forms?.slug,
      formName: row.forms?.name,
      name: row.name,
      phone: row.phone,
      phoneMasked: maskPhone(row.phone),
      gender: row.gender,
      birthYear: row.birth_year,
      contactTime: row.contact_time,
      resultSummary: row.result_summary,
      resultDetail: row.result_detail,
      status: row.status,
      adminNote: row.admin_note,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    }));

    return jsonResponse(200, {
      leads,
      pagination: {
        page,
        limit,
        total: count || 0,
        totalPages: Math.ceil((count || 0) / limit),
      },
    });
  } catch (err) {
    console.error(err);
    return jsonResponse(500, { error: err.message });
  }
};
