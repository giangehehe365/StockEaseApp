// Runs only against an ephemeral local emulator with a demo project.
// No npm dependencies, production credentials or Firebase deployment are used.
import { spawn } from 'node:child_process';
import assert from 'node:assert/strict';
import { setTimeout as delay } from 'node:timers/promises';
import { resolve } from 'node:path';
import { createServer } from 'node:net';
import { createHash } from 'node:crypto';

const jar = process.env.FIRESTORE_EMULATOR_JAR;
assert(jar, 'Set FIRESTORE_EMULATOR_JAR to the cached Firestore emulator JAR.');
const java = process.env.FIRESTORE_JAVA || 'java';
// Reserve an available local port before starting; never reuse another emulator.
const probe = createServer();
await new Promise((ready, reject) => {
  probe.once('error', reject);
  probe.listen(Number(process.env.FIRESTORE_TEST_PORT || 0), '127.0.0.1', ready);
});
const port = probe.address().port;
await new Promise(ready => probe.close(ready));
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
    signal: AbortSignal.timeout(15000),
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

const selectedRules = process.argv.slice(2);
const rulesFiles = selectedRules.length ? selectedRules : ['firestore.rules', 'firestore.merged.rules'];
assert(rulesFiles.every(file => ['firestore.rules', 'firestore.merged.rules'].includes(file)), 'Choose a project Rules file.');
for (const rules of rulesFiles) {
  let logs = '';
  const child = spawn(java, ['-Xmx512m', '-XX:ActiveProcessorCount=2', '-Dio.netty.eventLoopThreads=2', '-jar', jar, '--host', '127.0.0.1', '--port', String(port),
    '--project_id', project, '--rules', resolve(rules)], { windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'] });
  child.stdout.on('data', chunk => { logs += chunk; });
  child.stderr.on('data', chunk => { logs += chunk; });
  child.on('error', error => { logs += error.message; });
  const stop = () => { child.kill(); process.exitCode = 130; };
  process.once('SIGINT', stop);
  try {
    let ready = false;
    for (let attempt = 0; attempt < 300; attempt++) {
      if (child.exitCode != null) break;
      try { await fetch(`http://127.0.0.1:${port}/`, { signal: AbortSignal.timeout(1000) }); ready = true; break; } catch {}
      await delay(200);
    }
    assert(ready, `Emulator did not start: ${logs}`);
    console.log(`Started emulator for ${rules}`);
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
    // Test fixtures below validate purchase fields; they are not live API rates.
    await expectStatus(await request('/users/owner/productSkus/BV001', {
      method: 'PATCH', admin: true, body: { fields: { productId: s('p') } },
    }), 200);
    const usdPurchase = {
      purchasePriceOriginal: n(2), purchaseCurrency: s('USD'),
      exchangeRate: { doubleValue: 100.25 }, exchangeRateDate: s('2025-01-02'), purchasePriceVnd: n(201),
    };
    const editPurchase = fields => ({
      update: { name: `${prefix}/${productPath}`, fields },
      updateMask: { fieldPaths: Object.keys(fields) },
      updateTransforms: [{ fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' }],
    });
    await expectStatus(await commit([editPurchase(usdPurchase)]), 200);
    await verifyStock(12);
    let persisted = await request(`/${productPath}`);
    assert.equal(persisted.body.fields.price.integerValue, '10000');
    assert.equal(persisted.body.fields.purchasePriceVnd.integerValue, '201');
    assert.equal(persisted.body.fields.exchangeRateDate.stringValue, '2025-01-02');
    checks += 3;
    for (const invalid of [
      { ...usdPurchase, purchasePriceVnd: n(200) },
      { ...usdPurchase, purchasePriceOriginal: n(-1) },
      { ...usdPurchase, exchangeRate: n(0) },
      { ...usdPurchase, purchaseCurrency: s('EUR') },
      { ...usdPurchase, exchangeRateDate: s('not-a-date') },
    ]) {
      await expectStatus(await commit([editPurchase(invalid)]), 403);
    }
    await expectStatus(await commit([editPurchase({ purchasePriceVnd: n(9) })]), 403);
    await expectStatus(await commit([editPurchase(usdPurchase)], { user: 'other' }), 403);
    // Valid VND needs no API date, with identity conversion.
    await expectStatus(await commit([editPurchase({
      purchasePriceOriginal: n(12500), purchaseCurrency: s('VND'),
      exchangeRate: n(1), exchangeRateDate: { nullValue: null }, purchasePriceVnd: n(12500),
    })]), 200);
    const withPurchaseMovement = 'J'.repeat(20);
    await expectStatus(await commit([stockWrite(13, withPurchaseMovement), movementWrite(withPurchaseMovement, 'IN', 1, past)]), 200);
    await verifyStock(13);
    persisted = await request(`/${productPath}`);
    assert.equal(persisted.body.fields.price.integerValue, '10000');
    assert.equal(persisted.body.fields.purchasePriceVnd.integerValue, '12500');
    checks += 2;
    // Creating a new product pairs its SKU reservation and purchase snapshot.
    const newProduct = 'users/owner/products/purchase';
    const createdFields = { ...seed, ...usdPurchase, sku: s('PURCHASE') };
    delete createdFields.createdAt;
    delete createdFields.updatedAt;
    await expectStatus(await commit([
      { update: { name: `${prefix}/${newProduct}`, fields: createdFields },
        updateTransforms: [
          { fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' },
          { fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' },
        ] },
      { update: { name: `${prefix}/users/owner/productSkus/PURCHASE`, fields: { productId: s('purchase') } } },
    ]), 200);
    const newRead = await request(`/${newProduct}`);
    await expectStatus(newRead, 200);
    assert.equal(newRead.body.fields.purchasePriceVnd.integerValue, '201');
    checks++;
    // Archived products reject stock changes without producing history.
    await expectStatus(await request(`/${productPath}`, { method: 'PATCH', admin: true, body: { fields: {
      ...seed, quantity: n(12), isArchived: { booleanValue: true },
    } } }), 200);
    const archived = 'H'.repeat(20);
    await expectStatus(await commit([stockWrite(13, archived), movementWrite(archived, 'IN', 1, past)]), 403);
    await verifyStock(12);
    await verifyAbsent(archived);
    // Profile data remains on its existing document, and never contains credentials.
    const profilePath = 'users/owner/stockease/profile';
    await expectStatus(await request(`/${profilePath}`, { method: 'PATCH', admin: true, body: { fields: {
      name: s('Legacy owner'), storeName: s('Legacy store'),
    } } }), 200);
    await expectStatus(await request(`/${profilePath}`), 200);
    await expectStatus(await request(`/${profilePath}`, { user: 'other' }), 403);
    await expectStatus(await request(`/${profilePath}`, { user: null }), 403);
    const profileFields = { name: s('Updated owner'), storeName: s('Updated store'), phoneNumber: s('+84901234567'), storeAddress: s('123 Test Street') };
    const profileWrite = (fields, created = false, path = profilePath) => ({
      update: { name: `${prefix}/${path}`, fields },
      updateMask: { fieldPaths: Object.keys(fields) },
      updateTransforms: [
        ...(created ? [{ fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' }] : []),
        { fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' },
      ],
    });
    await expectStatus(await commit([profileWrite({ ...profileFields, createdAt: { nullValue: null } })]), 200);
    const profileRead = await request(`/${profilePath}`);
    await expectStatus(profileRead, 200);
    assert.equal(profileRead.body.fields.phoneNumber.stringValue, '+84901234567');
    const profileCreated = profileRead.body.fields.createdAt;
    checks++;
    await expectStatus(await commit([profileWrite({ ...profileFields, storeName: s('Renamed store') })]), 200);
    assert.deepEqual((await request(`/${profilePath}`)).body.fields.createdAt, profileCreated);
    checks++;
    for (const invalid of [
      { ...profileFields, name: s('') }, { ...profileFields, storeName: s('') },
      { ...profileFields, phoneNumber: s('abc') }, { ...profileFields, password: s('must-never-be-stored') },
      { ...profileFields, email: s('cannot-change-login@example.com') },
    ]) await expectStatus(await commit([profileWrite(invalid)]), 403);
    await expectStatus(await commit([profileWrite(profileFields)], { user: 'other' }), 403);
    await expectStatus(await commit([profileWrite(profileFields, true)]), 403);
    await expectStatus(await commit([profileWrite(profileFields, true, 'users/fresh/stockease/profile')], { user: 'fresh' }), 200);
    await expectStatus(await request('/users/fresh/stockease/profile', { user: 'fresh' }), 200);
    // Barcode uniqueness must hold in Rules as well as in the Flutter service.
    const barcodeKey = code => createHash('sha256').update(/^[0-9]{12}$/.test(code) ? `0${code}` : code).digest('hex');
    const barcodePath = (uid, code) => `users/${uid}/productBarcodes/${barcodeKey(code)}`;
    const barcodeReservation = (uid, id, code, key = barcodeKey(code)) => ({
      update: { name: `${prefix}/users/${uid}/productBarcodes/${key}`, fields: { productId: s(id), barcode: s(code) } },
    });
    const barcodeProduct = (uid, id, sku, code) => ({
      update: { name: `${prefix}/users/${uid}/products/${id}`, fields: {
        ...seed, userId: s(uid), sku: s(sku), barcode: code,
      } },
      updateTransforms: [{ fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' }, { fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' }],
    });
    const skuWrite = (uid, id, sku) => ({ update: { name: `${prefix}/users/${uid}/productSkus/${sku}`, fields: { productId: s(id) } } });
    const newBarcodeProduct = (uid, id, sku, code) => [barcodeProduct(uid,id,sku,s(code)), skuWrite(uid,id,sku), barcodeReservation(uid,id,code)];
    const barcodeEdit = (id, code) => ({
      update: { name: `${prefix}/users/owner/products/${id}`, fields: { barcode: s(code) } },
      updateMask: { fieldPaths: ['barcode'] },
      updateTransforms: [{ fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' }],
    });
    const code = '0012345678905';
    await expectStatus(await commit(newBarcodeProduct('owner', 'barcode1', 'BAR1', code)), 200);
    const barcodeRead = await request('/users/owner/products/barcode1');
    await expectStatus(barcodeRead, 200);
    assert.equal(barcodeRead.body.fields.barcode.stringValue, code); checks++;
    await expectStatus(await request(`/${barcodePath('owner',code)}`), 200);
    await expectStatus(await request(`/${barcodePath('owner',code)}`, { user: 'other' }), 403);
    await expectStatus(await request('/users/owner/products/barcode1', { user: 'other' }), 403);
    await expectStatus(await commit(newBarcodeProduct('owner', 'barcode2', 'BAR2', code)), 403);
    await expectStatus(await commit(newBarcodeProduct('other', 'barcode1', 'BAR1', code), { user: 'other' }), 200);
    await expectStatus(await commit([barcodeProduct('owner','numeric','NUM',n(123)), skuWrite('owner','numeric','NUM')]), 403);
    await expectStatus(await commit([barcodeProduct('owner','missing','MISS',s('not-reserved')), skuWrite('owner','missing','MISS')]), 403);
    await expectStatus(await commit([barcodeReservation('owner','barcode1',code,'wrong-key')]), 403);
    // Changing barcode must release the old reservation and reserve the new one.
    const code128 = 'Ab/Code-128';
    await expectStatus(await commit([barcodeEdit('barcode1',code128), barcodeReservation('owner','barcode1',code128)]), 403);
    await expectStatus(await commit([
      barcodeEdit('barcode1',code128), barcodeReservation('owner','barcode1',code128),
      { delete: `${prefix}/${barcodePath('owner',code)}` },
    ]), 200);
    await expectStatus(await commit(newBarcodeProduct('owner', 'barcode2', 'BAR2', code)), 200);
    await expectStatus(await commit([barcodeEdit('barcode1','')]), 403);
    await expectStatus(await commit([barcodeEdit('barcode1',''), { delete: `${prefix}/${barcodePath('owner',code128)}` }]), 200);
    // Barcode can be attached to a pre-existing legacy product without a migration.
    const legacyBarcodeEdit = { ...barcodeEdit('purchase','00000001') };
    await expectStatus(await commit([legacyBarcodeEdit, barcodeReservation('owner','purchase','00000001')]), 200);
    // Two simultaneous different products cannot claim one barcode.
    const races = await Promise.all([
      commit(newBarcodeProduct('owner', 'race1', 'RACE1', 'RACE/128')),
      commit(newBarcodeProduct('owner', 'race2', 'RACE2', 'RACE/128')),
    ]);
    assert.deepEqual(races.map(r=>r.status).sort(), [200,403]); checks++;
    // Archiving must release both indices while retaining the product/history.
    const archiveBarcode = {
      update: { name: `${prefix}/users/owner/products/barcode2`, fields: { isArchived: { booleanValue: true } } },
      updateMask: { fieldPaths:['isArchived'] },
      updateTransforms: [{ fieldPath:'updatedAt',setToServerValue:'REQUEST_TIME' }],
    };
    await expectStatus(await commit([archiveBarcode,{delete:`${prefix}/users/owner/productSkus/BAR2`}]),403);
    await expectStatus(await commit([archiveBarcode,{delete:`${prefix}/users/owner/productSkus/BAR2`},{delete:`${prefix}/${barcodePath('owner',code)}`}]),200);
    await expectStatus(await commit(newBarcodeProduct('owner','barcode3','BAR3',code)),200);
    await expectStatus(await commit([{ delete: `${prefix}/${barcodePath('owner',code)}` }]),403);
    await expectStatus(await commit(newBarcodeProduct('owner','upc','UPC','036000291452')),200);
    await expectStatus(await commit(newBarcodeProduct('owner','eanAlias','EALIAS','0036000291452')),403);
    await expectStatus(await commit([barcodeEdit('upc','0036000291452'),barcodeReservation('owner','upc','0036000291452')]),200);
    const barcodeStock = (next, id) => {
      const write = stockWrite(next, id);
      write.update.name = `${prefix}/users/owner/products/barcode3`;
      return write;
    };
    const barcodeMovement = (id, type, amount) => {
      const write = movementWrite(id,type,amount,past);
      write.update.fields.productId=s('barcode3'); write.update.fields.sku=s('BAR3');
      return write;
    };
    await expectStatus(await commit([barcodeStock(14,'K'.repeat(20)),barcodeMovement('K'.repeat(20),'IN',4)]),200);
    await expectStatus(await commit([barcodeStock(11,'L'.repeat(20)),barcodeMovement('L'.repeat(20),'OUT',3)]),200);
    await expectStatus(await commit([barcodeStock(-1,'M'.repeat(20)),barcodeMovement('M'.repeat(20),'OUT',12)]),403);
    const barcodeAfterStock=await request('/users/owner/products/barcode3');
    await expectStatus(barcodeAfterStock,200);
    assert.equal(barcodeAfterStock.body.fields.quantity.integerValue,'11');
    assert.equal(barcodeAfterStock.body.fields.barcode.stringValue,code); checks+=2;
    console.log(`PASS ${rules}: inventory, purchase prices, profile and barcode uniqueness/legacy/ownership/races`);
  } catch (error) {
    console.error(logs.slice(-6000));
    throw error;
  } finally {
    process.removeListener('SIGINT', stop);
    child.kill();
    await new Promise(resolveExit => child.exitCode != null ? resolveExit() : child.once('exit', resolveExit));
  }
}
console.log(`PASS ${checks} assertions against Firestore Emulator`);
