const { getSupabase, jsonResponse, corsPreflightResponse } = require('./lib/supabase');
const { requireAdmin } = require('./lib/auth');

exports.handler = async (event) => {
  if (event.httpMethod === 'OPTIONS') return corsPreflightResponse();

  const auth = requireAdmin(event);
  if (!auth.ok) {
    return { ...auth.response, headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } };
  }

  try {
    const supabase = getSupabase();
    const { data: forms, error } = await supabase
      .from('forms')
      .select('id, slug, name, description, is_active, created_at')
      .order('created_at', { ascending: true });

    if (error) throw error;

    const { data: counts } = await supabase.from('leads').select('form_id');
    const countMap = {};
    (counts || []).forEach((row) => {
      countMap[row.form_id] = (countMap[row.form_id] || 0) + 1;
    });

    const result = (forms || []).map((f) => ({
      ...f,
      leadCount: countMap[f.id] || 0,
    }));

    return jsonResponse(200, { forms: result });
  } catch (err) {
    console.error(err);
    return jsonResponse(500, { error: err.message });
  }
};
