import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { once } from 'node:events';
import { after, before, test } from 'node:test';

const appOrigin = 'https://mecho-os.onrender.com';
const adminUsername = 'test-admin';
const adminPassword = 'test-password';
const usedHashes = new Set();
let supabaseServer;
let apiProcess;
let apiUrl;

before(async () => {
  supabaseServer = createServer(async (request, response) => {
    const body = await readBody(request);
    const route = new URL(request.url, 'http://localhost').pathname;
    response.setHeader('Content-Type', 'application/json');
    if (route.endsWith('/create_spare_part_seller_id')) {
      const { p_id_hash: hash } = body;
      if (usedHashes.has(hash)) {
        response.end('false');
      } else {
        usedHashes.add(hash);
        response.end('true');
      }
      return;
    }
    if (route.endsWith('/is_spare_part_seller_id_available')) {
      response.end(usedHashes.has(body.p_id_hash) ? 'true' : 'false');
      return;
    }
    if (route.endsWith('/redeem_spare_part_seller_id')) {
      if (!usedHashes.has(body.p_id_hash)) {
        response.writeHead(409);
        response.end(JSON.stringify({ message: 'invalid ID' }));
        return;
      }
      usedHashes.delete(body.p_id_hash);
      response.end('null');
      return;
    }
    if (route === '/auth/v1/admin/users' && request.method === 'POST') {
      response.writeHead(201);
      response.end(JSON.stringify({ id: '00000000-0000-4000-8000-000000000001' }));
      return;
    }
    if (route.startsWith('/auth/v1/admin/users/')) {
      response.writeHead(204);
      response.end();
      return;
    }
    response.writeHead(404);
    response.end(JSON.stringify({ message: 'not found' }));
  });
  const supabasePort = await listenOnAvailablePort(supabaseServer);
  const apiPort = await getAvailablePort();
  apiUrl = `http://127.0.0.1:${apiPort}`;
  apiProcess = spawn(
    process.execPath,
    ['src/server.js'],
    {
      cwd: new URL('..', import.meta.url),
      env: {
        ...process.env,
        PORT: String(apiPort),
        APP_ORIGIN: appOrigin,
        SUPABASE_URL: `http://127.0.0.1:${supabasePort}`,
        SUPABASE_SERVICE_ROLE_KEY: 'test-service-role-key',
        ADMIN_USERNAME: adminUsername,
        ADMIN_PASSWORD: adminPassword,
        ADMIN_TOKEN_SECRET: 'short-token-key',
        SELLER_ID_HASH_SECRET: 'different-length-hash-key',
        PUSH_WEBHOOK_SECRET: 'test-push-webhook-secret',
        WEB_PUSH_VAPID_PUBLIC_KEY: '',
        WEB_PUSH_VAPID_PRIVATE_KEY: '',
      },
      stdio: 'ignore',
    },
  );
  await waitForHealth(apiProcess, apiUrl);
});

after(async () => {
  apiProcess?.kill();
  if (apiProcess) await once(apiProcess, 'exit');
  if (supabaseServer?.listening) {
    await new Promise((resolve, reject) =>
      supabaseServer.close((error) => error ? reject(error) : resolve()),
    );
  }
});

test('admin IDs require admin authentication and register only once', async () => {
  const denied = await fetch(`${apiUrl}/admin/seller-ids`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ count: 1 }),
  });
  assert.equal(denied.status, 401);

  const invalidLogin = await fetch(`${apiUrl}/admin/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Origin: appOrigin },
    body: JSON.stringify({ username: adminUsername, password: 'wrong' }),
  });
  assert.equal(invalidLogin.status, 401);

  const login = await fetch(`${apiUrl}/admin/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Origin: appOrigin },
    body: JSON.stringify({ username: adminUsername, password: adminPassword }),
  });
  assert.equal(login.status, 200);
  const { token } = await login.json();
  assert.equal(typeof token, 'string');

  const generated = await fetch(`${apiUrl}/admin/seller-ids`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Origin: appOrigin,
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify({ count: 1 }),
  });
  assert.equal(generated.status, 201);
  const [sellerId] = (await generated.json()).ids;
  assert.match(sellerId, /^\d{10}$/);

  const signup = await fetch(`${apiUrl}/seller-signup`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Origin: appOrigin },
    body: JSON.stringify({
      sellerId,
      fullName: 'Test Seller',
      email: 'seller@example.com',
      phoneNumber: '08012345678',
      password: 'strong-password',
    }),
  });
  assert.equal(signup.status, 201);
  assert.equal((await signup.json()).message, 'Seller account created.');

  const reusedId = await fetch(`${apiUrl}/seller-signup`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Origin: appOrigin },
    body: JSON.stringify({
      sellerId,
      fullName: 'Another Seller',
      email: 'another@example.com',
      phoneNumber: '08012345678',
      password: 'strong-password',
    }),
  });
  assert.equal(reusedId.status, 400);
});

test('rejects invalid seller IDs and requests from other web origins', async () => {
  const invalidId = await fetch(`${apiUrl}/seller-signup`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Origin: appOrigin },
    body: JSON.stringify({
      sellerId: '123',
      fullName: 'Test Seller',
      email: 'seller@example.com',
      phoneNumber: '08012345678',
      password: 'strong-password',
    }),
  });
  assert.equal(invalidId.status, 400);

  const deniedOrigin = await fetch(`${apiUrl}/seller-signup`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Origin: 'https://example.com',
    },
    body: '{}',
  });
  assert.equal(deniedOrigin.status, 403);
});

test('push delivery requires the webhook secret and VAPID configuration', async () => {
  const unauthorized = await fetch(`${apiUrl}/notifications/push`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ notificationId: '00000000-0000-4000-8000-000000000001' }),
  });
  assert.equal(unauthorized.status, 401);

  const notConfigured = await fetch(`${apiUrl}/notifications/push`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Mecho-Push-Secret': 'test-push-webhook-secret',
    },
    body: JSON.stringify({ notificationId: '00000000-0000-4000-8000-000000000001' }),
  });
  assert.equal(notConfigured.status, 503);
});

async function listenOnAvailablePort(server) {
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  return server.address().port;
}

async function getAvailablePort() {
  const server = createServer();
  const port = await listenOnAvailablePort(server);
  await new Promise((resolve, reject) =>
    server.close((error) => error ? reject(error) : resolve()),
  );
  return port;
}

async function waitForHealth(child, baseUrl) {
  const deadline = Date.now() + 10_000;
  while (Date.now() < deadline) {
    if (child.exitCode !== null) {
      throw new Error(`Seller admin API exited with code ${child.exitCode}.`);
    }
    try {
      const response = await fetch(`${baseUrl}/health`);
      if (response.ok) return;
    } catch {
      await new Promise((resolve) => setTimeout(resolve, 100));
    }
  }
  throw new Error('Seller admin API did not become ready.');
}

async function readBody(request) {
  let contents = '';
  for await (const chunk of request) contents += chunk.toString();
  return contents ? JSON.parse(contents) : {};
}
