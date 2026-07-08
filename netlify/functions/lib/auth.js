const crypto = require('crypto');

function getAdminPassword() {
  return process.env.ADMIN_PASSWORD || '';
}

function verifyAdminToken(authHeader) {
  if (!authHeader || !authHeader.startsWith('Bearer ')) return false;
  const token = authHeader.slice(7);
  const secret = process.env.ADMIN_TOKEN_SECRET || getAdminPassword();
  if (!secret || !token) return false;

  try {
    const [payloadB64, sig] = token.split('.');
    if (!payloadB64 || !sig) return false;
    const expected = crypto
      .createHmac('sha256', secret)
      .update(payloadB64)
      .digest('base64url');
    if (sig !== expected) return false;

    const payload = JSON.parse(Buffer.from(payloadB64, 'base64url').toString());
    if (!payload.exp || Date.now() > payload.exp) return false;
    return true;
  } catch {
    return false;
  }
}

function createAdminToken() {
  const secret = process.env.ADMIN_TOKEN_SECRET || getAdminPassword();
  const payload = {
    role: 'admin',
    exp: Date.now() + 7 * 24 * 60 * 60 * 1000,
  };
  const payloadB64 = Buffer.from(JSON.stringify(payload)).toString('base64url');
  const sig = crypto.createHmac('sha256', secret).update(payloadB64).digest('base64url');
  return `${payloadB64}.${sig}`;
}

function requireAdmin(event) {
  const auth = event.headers.authorization || event.headers.Authorization || '';
  if (!verifyAdminToken(auth)) {
    return { ok: false, response: { statusCode: 401, body: JSON.stringify({ error: '未授权' }) } };
  }
  return { ok: true };
}

module.exports = {
  getAdminPassword,
  verifyAdminToken,
  createAdminToken,
  requireAdmin,
};
