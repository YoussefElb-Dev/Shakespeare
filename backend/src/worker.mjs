import { DurableObject } from 'cloudflare:workers';
import { handleRequest } from './handler.mjs';
import { quotaDecision } from './core.mjs';

export class QuotaGate extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);
    ctx.storage.sql.exec(`CREATE TABLE IF NOT EXISTS usage (
      key TEXT PRIMARY KEY, minute INTEGER, minute_count INTEGER, day INTEGER, day_count INTEGER)`);
  }
  async fetch(request) {
    const { client } = await request.json();
    if (typeof client !== 'string' || !/^[a-f0-9]{64}$/.test(client)) return new Response(null, { status: 400 });
    const now = Date.now();
    const minute = Math.floor(now / 60_000);
    const day = Math.floor(now / 86_400_000);
    const allowed = this.ctx.storage.transactionSync(() => {
      const sql = this.ctx.storage.sql;
      const user = sql.exec('SELECT * FROM usage WHERE key = ?', client).toArray()[0];
      const total = sql.exec("SELECT * FROM usage WHERE key = 'global'").toArray()[0];
      const minuteCount = user?.minute === minute ? user.minute_count : 0;
      const dayCount = user?.day === day ? user.day_count : 0;
      const globalCount = total?.day === day ? total.day_count : 0;
      if (!quotaDecision({ minute: minuteCount, day: dayCount, global: globalCount, limit: Number(this.env.GLOBAL_DAILY_LIMIT) })) return false;
      sql.exec('INSERT OR REPLACE INTO usage VALUES (?, ?, ?, ?, ?)', client, minute, minuteCount + 1, day, dayCount + 1);
      sql.exec("INSERT OR REPLACE INTO usage VALUES ('global', ?, 0, ?, ?)", minute, day, globalCount + 1);
      sql.exec('DELETE FROM usage WHERE day < ?', day);
      return true;
    });
    return new Response(null, { status: allowed ? 204 : 429 });
  }
}

export default {
  async fetch(request, env) {
    try { return await handleRequest(request, env); }
    catch { return Response.json({ error: 'Service temporarily unavailable.' }, { status: 503,
      headers: { 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' } }); }
  },
};
