const {
  getSupabase,
  jsonResponse,
  corsPreflightResponse,
  getFormBySlug,
} = require('./lib/supabase');

function validatePhone(phone) {
  return /^1[3-9]\d{9}$/.test(phone);
}

exports.handler = async (event) => {
  if (event.httpMethod === 'OPTIONS') return corsPreflightResponse();
  if (event.httpMethod !== 'POST') {
    return jsonResponse(405, { error: 'Method not allowed' });
  }

  try {
    const body = JSON.parse(event.body || '{}');
    const formSlug = body.formSlug || body.form_slug;
    const name = (body.name || '').trim();
    const phone = (body.phone || '').trim();
    const gender = body.gender || null;
    const birthYear = body.birthYear || body.birth_year || null;
    const contactTime = body.contactTime || body.contact_time || null;

    if (!formSlug) return jsonResponse(400, { error: '缺少 formSlug' });
    if (!name) return jsonResponse(400, { error: '请填写姓名' });
    if (!validatePhone(phone)) return jsonResponse(400, { error: '手机号格式不正确' });

    const supabase = getSupabase();
    const form = await getFormBySlug(supabase, formSlug);
    if (!form) return jsonResponse(404, { error: '表单不存在' });
    if (!form.is_active) return jsonResponse(403, { error: '表单已停用' });

    const resultSummary =
      body.primarySyndrome ||
      body.result_summary ||
      body.resultSummary ||
      null;

    const resultDetail = {
      primarySyndrome: body.primarySyndrome,
      primaryScore: body.primaryScore,
      secondarySyndrome: body.secondarySyndrome,
      allScores: body.allScores,
      wylqReport: body.wylqReport,
    };

    const { data, error } = await supabase
      .from('leads')
      .insert({
        form_id: form.id,
        name,
        phone,
        gender,
        birth_year: birthYear ? parseInt(birthYear, 10) : null,
        contact_time: contactTime,
        result_summary: resultSummary,
        result_detail: resultDetail,
        raw_payload: body,
        status: 'new',
      })
      .select('id, created_at')
      .single();

    if (error) {
      console.error('insert error', error);
      return jsonResponse(500, { error: '保存失败，请稍后重试' });
    }

    return jsonResponse(201, {
      ok: true,
      id: data.id,
      createdAt: data.created_at,
    });
  } catch (err) {
    console.error(err);
    return jsonResponse(500, { error: err.message || '服务器错误' });
  }
};
