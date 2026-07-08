const { jsonResponse, corsPreflightResponse } = require('./lib/supabase');
const { getAdminPassword, createAdminToken } = require('./lib/auth');

exports.handler = async (event) => {
  if (event.httpMethod === 'OPTIONS') return corsPreflightResponse();
  if (event.httpMethod !== 'POST') {
    return jsonResponse(405, { error: 'Method not allowed' });
  }

  const adminPassword = getAdminPassword();
  if (!adminPassword) {
    return jsonResponse(500, { error: '服务端未配置 ADMIN_PASSWORD' });
  }

  try {
    const { password } = JSON.parse(event.body || '{}');
    if (password !== adminPassword) {
      return jsonResponse(401, { error: '密码错误' });
    }
    const token = createAdminToken();
    return jsonResponse(200, { ok: true, token });
  } catch {
    return jsonResponse(400, { error: '请求格式错误' });
  }
};
