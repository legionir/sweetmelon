// Executes the real injected SDK (the template in bridge_sdk.dart) inside a
// Node VM context that stands in for a WebView page. No copy of the SDK source
// lives in this file, so the tests always exercise what the app ships.
//
// Run: node --test test/js/bridge_sdk.test.mjs

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import vm from 'node:vm';
import { webcrypto } from 'node:crypto';

const here = dirname(fileURLToPath(import.meta.url));
const dartSource = readFileSync(
  resolve(here, '../../lib/packages/core/lib/src/runtime/bridge_sdk.dart'),
  'utf8',
);
const match = dartSource.match(/const String kBridgeSdkTemplate = r'''([\s\S]*?)''';/);
if (!match) {
  throw new Error('kBridgeSdkTemplate not found in bridge_sdk.dart');
}
const TEMPLATE = match[1];
const TOKEN = 'tok_TEST-0123456789abcdef';

function createPage({ framed = false, token = TOKEN } = {}) {
  const posted = [];
  const logs = [];
  const windowObj = {
    flutterBridge: { postMessage: (msg) => posted.push({ channel: 'flutterBridge', msg }) },
    __bridgeInternal: { postMessage: (msg) => posted.push({ channel: '__bridgeInternal', msg }) },
  };
  windowObj.self = windowObj;
  windowObj.top = framed ? {} : windowObj;

  const context = vm.createContext({
    window: windowObj,
    crypto: webcrypto,
    console: {
      log: (...a) => logs.push(['log', a]),
      warn: (...a) => logs.push(['warn', a]),
      error: (...a) => logs.push(['error', a]),
    },
    setTimeout,
    clearTimeout,
    Promise,
    JSON,
    Date,
    Object,
    Array,
    Uint8Array,
    isFinite,
    TypeError,
  });

  const source = TEMPLATE.replace('__SM_SESSION_TOKEN__', JSON.stringify(token));
  vm.runInContext(source, context);

  return {
    window: windowObj,
    posted,
    logs,
    lastOutbound: () => posted[posted.length - 1].msg,
  };
}

test('installs the Native API and reports bridge_ready with the token', () => {
  const page = createPage();
  assert.equal(typeof page.window.Native.call, 'function');
  const ready = page.posted.find((p) => p.channel === '__bridgeInternal');
  assert.ok(ready, 'bridge_ready must be sent to the internal channel');
  const body = JSON.parse(ready.msg);
  assert.equal(body.type, 'bridge_ready');
  assert.equal(body.token, TOKEN);
});

test('does not install inside an iframe', () => {
  const page = createPage({ framed: true });
  assert.equal(page.window.Native, undefined);
  assert.equal(page.posted.length, 0);
});

test('does not install twice when executed again', () => {
  const page = createPage();
  const first = page.window.Native;
  vm.runInContext(
    TEMPLATE.replace('__SM_SESSION_TOKEN__', JSON.stringify(TOKEN)),
    vm.createContext({ window: page.window, crypto: webcrypto, console, setTimeout, clearTimeout, Promise, JSON, Date, Object, Array, Uint8Array, isFinite, TypeError }),
  );
  assert.equal(page.window.Native, first);
});

test('call sends token, plugin, method and resolves on success', async () => {
  const page = createPage();
  const promise = page.window.Native.call({ plugin: 'storage', method: 'get', args: { key: 'a' } });
  const out = JSON.parse(page.lastOutbound());
  assert.equal(out.token, TOKEN);
  assert.equal(out.plugin, 'storage');
  assert.equal(out.method, 'get');
  assert.deepEqual(out.args, { key: 'a' });
  assert.match(out.requestId, /^[0-9a-f-]{36}$/);

  page.window.__resolveCall(out.requestId, JSON.stringify({ success: true, data: 42 }));
  assert.equal(await promise, 42);
});

test('call rejects with the native error and the requestId', async () => {
  const page = createPage();
  const promise = page.window.Native.call({ plugin: 'camera', method: 'takePhoto' });
  const out = JSON.parse(page.lastOutbound());
  page.window.__resolveCall(
    out.requestId,
    JSON.stringify({ success: false, error: { code: 'CANCELLED', message: 'User cancelled', retryable: false } }),
  );
  await assert.rejects(promise, (err) => {
    assert.equal(err.code, 'CANCELLED');
    assert.equal(err.requestId, out.requestId);
    return true;
  });
});

test('call rejects with TIMEOUT when no response arrives', async () => {
  const page = createPage();
  await assert.rejects(
    page.window.Native.call({ plugin: 'storage', method: 'get', args: {}, timeout: 5 }),
    (err) => err.code === 'TIMEOUT' && err.retryable === true,
  );
});

test('call with invalid options rejects without posting', async () => {
  const page = createPage();
  const before = page.posted.length;
  await assert.rejects(page.window.Native.call({ plugin: 1, method: 'x' }), { code: 'INVALID_ARGS' });
  assert.equal(page.posted.length, before);
});

test('an unknown requestId is ignored without throwing', () => {
  const page = createPage();
  assert.doesNotThrow(() => page.window.__resolveCall('no-such-id', '{"success":true}'));
});

test('batch posts a batch envelope with the token and resolves in order', async () => {
  const page = createPage();
  const promise = page.window.Native.batch([
    { plugin: 'storage', method: 'get', args: { key: 'a' } },
    { plugin: 'storage', method: 'has', args: { key: 'b' } },
  ]);
  const out = JSON.parse(page.lastOutbound());
  assert.equal(out.type, 'batch');
  assert.equal(out.token, TOKEN);
  assert.equal(out.requests.length, 2);
  assert.equal(out.options.parallel, true);
  assert.equal(out.options.stopOnError, false);

  const results = [{ requestId: out.requests[0].requestId, success: true, data: 1 }];
  page.window.__resolveBatch(out.batchId, JSON.stringify({ results }));
  assert.deepEqual(await promise, results);
});

test('batch error settles the promise with a rejection (regression: BUG-002)', async () => {
  const page = createPage();
  const promise = page.window.Native.batch([{ plugin: 'storage', method: 'get', args: {} }]);
  const out = JSON.parse(page.lastOutbound());
  page.window.__resolveBatch(
    out.batchId,
    JSON.stringify({ results: [], error: { code: 'EXECUTION_ERROR', message: 'x', retryable: false } }),
  );
  await assert.rejects(promise, (err) => err.code === 'EXECUTION_ERROR' && err.requestId === out.batchId);
});

test('batch times out instead of waiting forever (regression: BUG-002)', async () => {
  const page = createPage();
  await assert.rejects(
    page.window.Native.batch([{ plugin: 'storage', method: 'get', args: {} }], { timeout: 5 }),
    (err) => err.code === 'TIMEOUT',
  );
});

test('events reach listeners with decoded payloads and can be removed', () => {
  const page = createPage();
  const received = [];
  const off = page.window.Native.on('geolocation.position', (data) => received.push(data));
  // Native sends the payload as a JS string literal whose value is JSON text
  // (see MessageBridge.emitEvent), so the SDK receives JSON text here.
  page.window.__emitEvent('geolocation.position', JSON.stringify({ latitude: 1.5 }));
  assert.deepEqual(received, [{ latitude: 1.5 }]);
  off();
  page.window.__emitEvent('geolocation.position', '"{}"');
  assert.equal(received.length, 1);
});

test('a throwing listener does not break other listeners', () => {
  const page = createPage();
  const received = [];
  page.window.Native.on('x.y', () => { throw new Error('boom'); });
  page.window.Native.on('x.y', (d) => received.push(d));
  page.window.__emitEvent('x.y', JSON.stringify('ok'));
  assert.deepEqual(received, ['ok']);
  assert.ok(page.logs.some(([level]) => level === 'error'));
});

test('malformed event payload is dropped without calling listeners', () => {
  const page = createPage();
  let called = false;
  page.window.Native.on('x.y', () => { called = true; });
  page.window.__emitEvent('x.y', '{not json');
  assert.equal(called, false);
});

test('on() rejects non-string events and non-function callbacks', () => {
  const page = createPage();
  assert.throws(() => page.window.Native.on(1, () => {}), TypeError);
  assert.throws(() => page.window.Native.on('x', 'nope'), TypeError);
});

test('info() reports pending request counts', () => {
  const page = createPage();
  page.window.Native.call({ plugin: 'storage', method: 'get', args: {}, timeout: 0 });
  const info = page.window.Native.info();
  assert.equal(info.initialized, true);
  assert.equal(info.pendingRequests, 1);
  assert.equal(info.totalRequests, 1);
});
