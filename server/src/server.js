import { createServer } from 'node:http';
import { createHmac, randomInt, timingSafeEqual } from 'node:crypto';

const port = Number(process.env.PORT ?? 10000);
const appOrigin = requiredEnv('APP_ORIGIN');
const supabaseUrl = requiredEnv('SUPABASE_URL').replace(/\/+$/, '');
const serviceRoleKey = requiredEnv('SUPABASE_SERVICE_ROLE_KEY');
const adminUsername = requiredEnv('ADMIN_USERNAME');
const adminPassword = requiredEnv('ADMIN_PASSWORD');
const tokenSecret = requiredEnv('ADMIN_TOKEN_SECRET');
const sellerIdHashSecret = requiredEnv('SELLER_ID_HASH_SECRET');
if (
  Buffer.byteLength(tokenSecret) < 32 ||
  Buffer.byteLength(sellerIdHashSecret) < 32
) {
  throw new Error('Admin and seller ID secrets must be at least 32 bytes long.');
}
const tokenLifetimeSeconds = 60 * 60;
const allowedOrigin = new URL(appOrigin).origin;
const loginAttempts = new Map();
const signupAttempts = new Map();

const server = createServer(async (request, response) => {
  applySecurityHeaders(response);
  const origin = request.headers.origin;
  if (origin && origin !== allowedOrigin) {
    return sendJson(response, 403, { error: 'Origin not allowed.' });
  }
  if (origin) {
    response.setHeader('Access-Control-Allow-Origin', allowedOrigin);
    response.setHeader('Vary', 'Origin');
  }
  response.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  response.setHeader(
    'Access-Control-Allow-Headers',
    'Content-Type, Authorization',
  );
  if (request.method === 'OPTIONS') {
    response.writeHead(204);
    return response.end();
  }

  const route = new URL(request.url ?? '/', 'http://localhost').pathname;
  try {
    if (request.method === 'GET' && route === '/health') {
      return sendJson(response, 200, { status: 'ok' });
    }
    if (request.method === 'POST' && route === '/admin/login') {
      return await handleAdminLogin(request, response);
    }
    if (request.method === 'POST' && route === '/admin/seller-ids') {
      return await handleCreateSellerId(request, response);
    }
    if (request.method === 'POST' && route === '/seller-signup') {
      return await handleSellerSignup(request, response);
    }
    return sendJson(response, 404, { error: 'Not found.' });
  } catch (error) {
    console.error('Seller admin API request failed:', error);
    return sendJson(response, error.status ?? 500, {
      error: error.status
        ? error.message
        : 'The request could not be completed.',
    });
  }
});

server.listen(port, '0.0.0.0', () => {
  console.log(`Mecho seller admin API listening on port ${port}`);
});

async function handleAdminLogin(request, response) {
  const address = clientAddress(request);
  if (!takeRateLimit(loginAttempts, address, 10, 15 * 60_000)) {
    return sendJson(response, 429, { error: 'Too many login attempts. Try again later.' });
  }
  const body = await readJson(request);
  if (
    !constantTimeEquals(body.username, adminUsername) ||
    !constantTimeEquals(body.password, adminPassword)
  ) {
    return sendJson(response, 401, { error: 'Invalid admin credentials.' });
  }
  const issuedAt = Math.floor(Date.now() / 1000);
  const token = signAdminToken({
    sub: 'mecho-admin',
    iat: issuedAt,
    exp: issuedAt + tokenLifetimeSeconds,
  });
  return sendJson(response, 200, {
    token,
    expiresIn: tokenLifetimeSeconds,
  });
}

async function handleCreateSellerId(request, response) {
  if (!isValidAdminToken(request.headers.authorization)) {
    return sendJson(response, 401, { error: 'Admin sign-in is required.' });
  }
  const body = await readJson(request);
  const count = body.count === undefined ? 1 : Number(body.count);
  if (!Number.isInteger(count) || count < 1 || count > 10) {
    return sendJson(response, 400, { error: 'Choose between 1 and 10 IDs.' });
  }

  const ids = [];
  for (let index = 0; index < count; index += 1) {
    let createdId;
    for (let attempt = 0; attempt < 5; attempt += 1) {
      const sellerId = String(randomInt(0, 10_000_000_000)).padStart(10, '0');
      const result = await supabaseRpc('create_spare_part_seller_id', {
        p_id_hash: hashSellerId(sellerId),
      });
      if (!result.ok) {
        return sendJson(response, 502, {
          error: 'Could not create seller ID. Check the Supabase setup.',
        });
      }
      if (result.data === true) {
        createdId = sellerId;
        break;
      }
    }
    if (!createdId) {
      return sendJson(response, 503, {
        error: 'Could not find a unique seller ID. Please try again.',
      });
    }
    ids.push(createdId);
  }

  return sendJson(response, 201, { ids });
}

async function handleSellerSignup(request, response) {
  const address = clientAddress(request);
  if (!takeRateLimit(signupAttempts, address, 10, 60 * 60_000)) {
    return sendJson(response, 429, { error: 'Too many signup attempts. Try again later.' });
  }
  const body = await readJson(request);
  const sellerId = String(body.sellerId ?? '').trim();
  const fullName = String(body.fullName ?? '').trim();
  const email = String(body.email ?? '').trim().toLowerCase();
  const phoneNumber = String(body.phoneNumber ?? '').trim();
  const password = String(body.password ?? '');
  if (!/^\d{10}$/.test(sellerId)) {
    return sendJson(response, 400, { error: 'Enter the 10-digit seller ID from the admin.' });
  }
  if (fullName.length < 2 || fullName.length > 120) {
    return sendJson(response, 400, { error: 'Enter your name or business name.' });
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 254) {
    return sendJson(response, 400, { error: 'Enter a valid email address.' });
  }
  if (phoneNumber.length < 7 || phoneNumber.length > 40) {
    return sendJson(response, 400, { error: 'Enter a valid contact phone number.' });
  }
  if (password.length < 8 || password.length > 128) {
    return sendJson(response, 400, { error: 'Password must be between 8 and 128 characters.' });
  }

  const idHash = hashSellerId(sellerId);
  const validation = await supabaseRpc('is_spare_part_seller_id_available', {
    p_id_hash: idHash,
  });
  if (!validation.ok) {
    return sendJson(response, 502, {
      error: 'Could not validate seller ID. Check the Supabase setup.',
    });
  }
  if (validation.data !== true) {
    return sendJson(response, 400, {
      error: 'This seller ID is invalid, already used, or no longer available.',
    });
  }

  const created = await createSupabaseUser({ email, password });
  if (!created.ok) {
    return sendJson(response, created.status === 422 ? 409 : 502, {
      error: created.status === 422
        ? 'An account already uses this email.'
        : 'Could not create the seller account.',
    });
  }
  const userId = created.data?.id ?? created.data?.user?.id;
  if (typeof userId !== 'string') {
    return sendJson(response, 502, { error: 'Supabase returned an invalid account response.' });
  }

  const redeemed = await supabaseRpc('redeem_spare_part_seller_id', {
    p_id_hash: idHash,
    p_user_id: userId,
    p_full_name: fullName,
    p_email: email,
    p_phone_number: phoneNumber,
  });
  if (!redeemed.ok) {
    const deleted = await deleteSupabaseUser(userId);
    if (!deleted) {
      console.error(`Could not clean up unregistered Auth user ${userId}`);
    }
    if (redeemed.status === 409) {
      return sendJson(response, 409, {
        error: 'This seller ID was just used. Ask the admin for another ID.',
      });
    }
    return sendJson(response, 502, {
      error: 'Could not finish seller registration. Please contact the admin.',
    });
  }
  return sendJson(response, 201, { message: 'Seller account created.' });
}

async function createSupabaseUser({ email, password }) {
  return supabaseRequest('/auth/v1/admin/users', {
    method: 'POST',
    body: {
      email,
      password,
      email_confirm: true,
    },
  });
}

async function deleteSupabaseUser(userId) {
  const result = await supabaseRequest(
    `/auth/v1/admin/users/${encodeURIComponent(userId)}`,
    { method: 'DELETE' },
  );
  return result.ok;
}

async function supabaseRpc(functionName, body) {
  return supabaseRequest(`/rest/v1/rpc/${functionName}`, {
    method: 'POST',
    body,
  });
}

async function supabaseRequest(path, { method, body }) {
  const result = await fetch(`${supabaseUrl}${path}`, {
    method,
    headers: {
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
      'Content-Type': 'application/json',
    },
    body: body === undefined ? undefined : JSON.stringify(body),
    signal: AbortSignal.timeout(10_000),
  });
  const text = await result.text();
  let data;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = null;
  }
  return { ok: result.ok, status: result.status, data };
}

async function readJson(request) {
  let size = 0;
  const chunks = [];
  for await (const chunk of request) {
    size += chunk.length;
    if (size > 16 * 1024) {
      throw Object.assign(new Error('Request body too large.'), { status: 413 });
    }
    chunks.push(chunk);
  }
  try {
    const body = JSON.parse(Buffer.concat(chunks).toString('utf8'));
    if (!body || typeof body !== 'object' || Array.isArray(body)) {
      throw new Error('Request body must be an object.');
    }
    return body;
  } catch {
    throw Object.assign(new Error('Invalid JSON body.'), { status: 400 });
  }
}

function takeRateLimit(store, key, max, windowMs) {
  const now = Date.now();
  const current = store.get(key);
  if (!current || current.resetAt <= now) {
    store.set(key, { count: 1, resetAt: now + windowMs });
    return true;
  }
  if (current.count >= max) return false;
  current.count += 1;
  return true;
}

function signAdminToken(payload) {
  const header = base64Url(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const data = `${header}.${base64Url(JSON.stringify(payload))}`;
  const signature = createHmac('sha256', tokenSecret).update(data).digest();
  return `${data}.${base64Url(signature)}`;
}

function isValidAdminToken(authorization) {
  if (typeof authorization !== 'string' || !authorization.startsWith('Bearer ')) {
    return false;
  }
  const token = authorization.slice(7);
  const parts = token.split('.');
  if (parts.length !== 3) return false;
  const data = `${parts[0]}.${parts[1]}`;
  const expected = createHmac('sha256', tokenSecret).update(data).digest();
  let supplied;
  let payload;
  try {
    supplied = Buffer.from(parts[2], 'base64url');
    payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
  } catch {
    return false;
  }
  return (
    supplied.length === expected.length &&
    timingSafeEqual(supplied, expected) &&
    payload.sub === 'mecho-admin' &&
    Number.isInteger(payload.exp) &&
    payload.exp > Math.floor(Date.now() / 1000)
  );
}

function constantTimeEquals(actual, expected) {
  if (typeof actual !== 'string') return false;
  const actualBytes = Buffer.from(actual);
  const expectedBytes = Buffer.from(expected);
  if (actualBytes.length !== expectedBytes.length) return false;
  return timingSafeEqual(actualBytes, expectedBytes);
}

function hashSellerId(value) {
  return createHmac('sha256', sellerIdHashSecret).update(value).digest('hex');
}

function clientAddress(request) {
  const forwardedFor = request.headers['x-forwarded-for'];
  if (typeof forwardedFor === 'string') {
    const addresses = forwardedFor.split(',').map((address) => address.trim());
    const address = addresses.at(-1);
    if (address) return address;
  }
  return request.socket.remoteAddress ?? 'unknown';
}

function base64Url(value) {
  return Buffer.from(value).toString('base64url');
}

function applySecurityHeaders(response) {
  response.setHeader('X-Content-Type-Options', 'nosniff');
  response.setHeader('X-Frame-Options', 'DENY');
  response.setHeader('Referrer-Policy', 'no-referrer');
  response.setHeader('Cache-Control', 'no-store');
}

function sendJson(response, status, body) {
  response.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8' });
  response.end(JSON.stringify(body));
}

function requiredEnv(name) {
  const value = process.env[name];
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
}

server.on('clientError', (_error, socket) => {
  socket.end('HTTP/1.1 400 Bad Request\r\n\r\n');
});
