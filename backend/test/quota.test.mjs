import test from 'node:test';
import assert from 'node:assert/strict';
import { Miniflare } from 'miniflare';
import { fileURLToPath } from 'node:url';

test('real Durable Object SQL serializes concurrent reservations and enforces global quota', async () => {
  const runtime = new Miniflare({
    modules: true, scriptPath: fileURLToPath(new URL('../src/worker.mjs', import.meta.url)),
    compatibilityDate: '2026-01-15',
    bindings: { GLOBAL_DAILY_LIMIT: '12' },
    durableObjects: { QUOTA: { className: 'QuotaGate', useSQLite: true } },
  });
  try {
    const namespace = await runtime.getDurableObjectNamespace('QUOTA');
    const quota = namespace.get(namespace.idFromName('test'));
    const reserve = client => quota.fetch('https://quota/reserve', { method: 'POST', body: JSON.stringify({ client }) });
    const results = await Promise.all(Array.from({ length: 15 }, () => reserve('a'.repeat(64))));
    assert.equal(results.filter(r => r.status === 204).length, 10);
    assert.equal(results.filter(r => r.status === 429).length, 5);
    assert.equal((await reserve('b'.repeat(64))).status, 204);
    assert.equal((await reserve('b'.repeat(64))).status, 204);
    assert.equal((await reserve('c'.repeat(64))).status, 429);
    const malformed = await reserve('invalid');
    assert.equal(malformed.status, 400);
  } finally { await runtime.dispose(); }
});
