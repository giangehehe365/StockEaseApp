// Runs only against an ephemeral local emulator with a demo project.
// No npm dependencies, production credentials or Firebase deployment are used.
import { spawn } from 'node:child_process';
import assert from 'node:assert/strict';
import { setTimeout as delay } from 'node:timers/promises';
import { resolve } from 'node:path';

const jar = process.env.FIRESTORE_EMULATOR_JAR;
assert(jar, 'Set FIRESTORE_EMULATOR_JAR to the cached Firestore emulator JAR.');
const java = process.env.FIRESTORE_JAVA || 'java';
const port = Number(process.env.FIRESTORE_TEST_PORT || 8187);
const project = 'demo-stockease-inventory';
const root = `http://127.0.0.1:${port}/v1/projects/${project}/databases/(default)/documents`;
const prefix = `projects/${project}/databases/(default)/documents`;
const productPath = 'users/owner/products/p';
let checks = 0;
const s = stringValue => ({ stringValue });
const n = value => ({ integerValue: String(value) });
const t = date => ({ timestampValue: date.toISOString() });
const jwt = uid => {
  const encode = value => Buffer.from(JSON.stringify(value)).toString('base64url');
  return `${encode({ alg: 'none', typ: 'JWT' })}.${encode({
    sub: uid, user_id: uid, aud: project,
    iss: `https://securetoken.google.com/${project}`,
    iat: Math.floor(Date.now() / 1000) - 60,
    exp: Math.floor(Date.now() / 1000) + 3600,
    firebase: { sign_in_provider: 'password' },
  })}.`;
};
async function request(path, { method = 'GET', body, user = 'owner', admin = false } = {}) {
  const response = await fetch(`${root}${path}`, {
    method,
    headers: {
      'content-type': 'application/json',
      ...(user == null ? {} : { authorization: `Bearer ${admin ? 'owner' : jwt(user)}` }),
    },
    body: body == null ? undefined : JSON.stringify(body),
  });
  return { status: response.status, body: await response.json() };
}
async function expectStatus(response, status) {
  assert.equal(response.status, status, JSON.stringify(response.body));
  checks++;
}
const stockWrite = (quantity, id) => ({
  update: { name: `${prefix}/${productPath}`, fields: {
    quantity: n(quantity), lastMovementId: s(id),
  } },
  updateMask: { fieldPaths: ['quantity', 'lastMovementId'] },
  updateTransforms: [{ fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' }],
});
function movementWrite(id, type, quantity, date, user = 'owner') {
  return {
    update: { name: `${prefix}/users/${user}/stockMovements/${id}`, fields: {
      movementId: s(id), userId: s(user), productId: s('p'), productName: s('Coca-Cola'),
      sku: s('BV001'), type: s(type), quantity: n(quantity), note: s('Kiểm thử'),
      transactionDate: t(date),
    } },
    currentDocument: { exists: false },
    updateTransforms: [{ fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' }],
  };
}
async function verifyStock(quantity) {
  const result = await request(`/${productPath}`);
  await expectStatus(result, 200);
  assert.equal(Number(result.body.fields.quantity.integerValue), quantity);
  checks++;
}
async function verifyAbsent(id) {
  await expectStatus(await request(`/users/owner/stockMovements/${id}`, { admin: true }), 404);
}

for (const rules of ['firestore.rules', 'firestore.merged.rules']) {
  let logs = '';
  const child = spawn(java, ['-jar', jar, '--host', '127.0.0.1', '--port', String(port),
    '--project_id', project, '--rules', resolve(rules)], { windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'] });
  child.stdout.on('data', chunk => { logs += chunk; });
  child.stderr.on('data', chunk => { logs += chunk; });
  child.on('error', error => { logs += error.message; });
  try {
    let ready = false;
    for (let attempt = 0; attempt < 100; attempt++) {
      if (child.exitCode != null) break;
      try { await fetch(`http://127.0.0.1:${port}/`); ready = true; break; } catch {}
      await delay(200);
    }
    assert(ready, `Emulator did not start: ${logs}`);
    const seed = {
      userId: s('owner'), name: s('Coca-Cola'), sku: s('BV001'), category: s('Đồ uống'),
      price: n(10000), quantity: n(10), minStock: n(2), unit: s('box'),
      isArchived: { booleanValue: false },
      createdAt: t(new Date('2025-01-01T00:00:00Z')),
      updatedAt: t(new Date('2025-01-01T00:00:00Z')),
    };
    await expectStatus(await request(`/${productPath}`, { method: 'PATCH', admin: true, body: { fields: seed } }), 200);
    const past = new Date('2025-02-01T08:30:00Z');
    const commit = (writes, options = {}) => request(':commit', { method: 'POST', body: { writes }, ...options });
    const first = 'A'.repeat(20);
    await expectStatus(await commit([stockWrite(15, first), movementWrite(first, 'IN', 5, past)]), 200);
    await verifyStock(15);
    const history = await request(`/users/owner/stockMovements/${first}`);
    await expectStatus(history, 200);
    assert.equal(Date.parse(history.body.fields.transactionDate.timestampValue), past.getTime());
    assert(Date.parse(history.body.fields.createdAt.timestampValue) > past.getTime());
    checks += 2;
    const second = 'B'.repeat(20);
    await expectStatus(await commit([stockWrite(12, second), movementWrite(second, 'OUT', 3, past)]), 200);
    await verifyStock(12);
    for (const [id, next, type, quantity, date] of [
      ['C'.repeat(20), -1, 'OUT', 13, past],
      ['D'.repeat(20), 13, 'IN', 1, new Date(Date.now() + 86400000)],
      ['E'.repeat(20), 99, 'IN', 1, past],
    ]) {
      await expectStatus(await commit([stockWrite(next, id), movementWrite(id, type, quantity, date)]), 403);
      await verifyStock(12);
      await verifyAbsent(id);
    }
    const solo = 'F'.repeat(20);
    await expectStatus(await commit([stockWrite(13, solo)]), 403);
    await expectStatus(await commit([movementWrite(solo, 'IN', 1, past)]), 403);
    await verifyStock(12);
    await verifyAbsent(solo);
    await expectStatus(await request(`/${productPath}`, { user: 'other' }), 403);
    await expectStatus(await request(`/users/owner/stockMovements/${first}`, { user: 'other' }), 403);
    await expectStatus(await request(`/${productPath}`, { user: null }), 403);
    const foreign = 'G'.repeat(20);
    await expectStatus(await commit([stockWrite(13, foreign), movementWrite(foreign, 'IN', 1, past)], { user: 'other' }), 403);
    await verifyStock(12);
    await verifyAbsent(foreign);
    // History is immutable and cannot be removed even by its owner.
    await expectStatus(await request(`/users/owner/stockMovements/${first}`, { method: 'DELETE' }), 403);
    // Existing history remains readable without any of the newly introduced fields.
    await expectStatus(await request('/users/owner/stockMovements/legacy', { method: 'PATCH', admin: true, body: { fields: {
      userId: s('owner'), productId: s('p'), productName: s('Coca-Cola'), type: s('IN'),
      quantity: n(2), note: s(''), createdAt: t(past),
    } } }), 200);
    await expectStatus(await request('/users/owner/stockMovements/legacy'), 200);
    // Archived products reject stock changes without producing history.
    await expectStatus(await request(`/${productPath}`, { method: 'PATCH', admin: true, body: { fields: {
      ...seed, quantity: n(12), isArchived: { booleanValue: true },
    } } }), 200);
    const archived = 'H'.repeat(20);
    await expectStatus(await commit([stockWrite(13, archived), movementWrite(archived, 'IN', 1, past)]), 403);
    await verifyStock(12);
    await verifyAbsent(archived);
    console.log(`PASS ${rules}: atomic writes, invalid/future/archived rejection, ownership, legacy reads`);
  } catch (error) {
    console.error(logs.slice(-6000));
    throw error;
  } finally {
    child.kill();
    await new Promise(resolveExit => child.exitCode != null ? resolveExit() : child.once('exit', resolveExit));
  }
}
console.log(`PASS ${checks} assertions against Firestore Emulator`);
