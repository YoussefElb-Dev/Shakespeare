import { InputError, validateInput, providerRequest, parseProviderResponse } from './core.mjs';

const MAX_BODY = 12_000;
export async function readJson(request) {
  if (!request.headers.get('content-type')?.toLowerCase().startsWith('application/json')) {
    throw new InputError('Use application/json.');
  }
  if (Number(request.headers.get('content-length')) > MAX_BODY) throw new InputError('Request is too large.');
  const reader = request.body?.getReader();
  if (!reader) throw new InputError('Missing request body.');
  const parts = [];
  let size = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > MAX_BODY) { await reader.cancel(); throw new InputError('Request is too large.'); }
    parts.push(value);
  }
  const all = new Uint8Array(size);
  let offset = 0;
  for (const part of parts) { all.set(part, offset); offset += part.length; }
  try { return JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(all)); }
  catch { throw new InputError('Invalid JSON.'); }
}

export async function handleRequest(request, env, fetchProvider = fetch) {
  const origin = request.headers.get('origin');
  const allowed = (env.ALLOWED_ORIGINS ?? '').split(',').map(x => x.trim()).filter(Boolean);
  const headers = { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store',
    'X-Content-Type-Options': 'nosniff', 'Vary': 'Origin' };
  if (origin && !allowed.includes(origin)) return Response.json({ error: 'Origin not allowed.' }, { status: 403, headers });
  if (origin) headers['Access-Control-Allow-Origin'] = origin;
  const respond = (status, body, extra = {}) => Response.json(body, { status, headers: { ...headers, ...extra } });
  const path = new URL(request.url).pathname;
  if (path === '/health' && request.method === 'GET') return respond(200, { status: 'ok' });
  if (path !== '/v1/quotes') return respond(404, { error: 'Not found.' });
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: { ...headers,
    'Access-Control-Allow-Methods': 'POST, OPTIONS', 'Access-Control-Allow-Headers': 'Content-Type', 'Access-Control-Max-Age': '600' } });
  if (request.method !== 'POST') return respond(405, { error: 'Use POST.' }, { Allow: 'POST, OPTIONS' });
  if (!env.GEMINI_API_KEY || !env.RATE_LIMIT_SALT || env.RATE_LIMIT_SALT.length < 32
      || !/^gemini-[a-z0-9.-]+$/.test(env.GEMINI_MODEL ?? '')) {
    return respond(503, { error: 'Writing service is not configured.' });
  }
  let input;
  try { input = validateInput(await readJson(request)); }
  catch (error) { if (error instanceof InputError) return respond(400, { error: error.message }); throw error; }
  // CF-Connecting-IP is set by Cloudflare's edge, not trusted from a client proxy header.
  const ip = request.headers.get('CF-Connecting-IP');
  if (!ip) return respond(503, { error: 'Client identity unavailable.' });
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(env.RATE_LIMIT_SALT),
    { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const day = Math.floor(Date.now() / 86_400_000);
  const digest = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(`${day}:${ip}`));
  const client = [...new Uint8Array(digest)].map(b => b.toString(16).padStart(2, '0')).join('');
  const quota = env.QUOTA.get(env.QUOTA.idFromName('global-quota-v1'));
  const reservation = await quota.fetch('https://quota/reserve', { method: 'POST',
    body: JSON.stringify({ client }) });
  if (!reservation.ok) return respond(reservation.status === 429 ? 429 : 503,
    { error: 'Creation limit reached. Please try again later.' }, { 'Retry-After': '60' });
  try {
    const response = await fetchProvider(`https://generativelanguage.googleapis.com/v1beta/models/${env.GEMINI_MODEL}:generateContent`, { method: 'POST',
      headers: { 'x-goog-api-key': env.GEMINI_API_KEY, 'Content-Type': 'application/json' },
      body: JSON.stringify(providerRequest(input)), signal: AbortSignal.timeout(30_000) });
    if (response.status === 429) return respond(429, { error: 'The free AI quota is busy. Please try again later.' }, { 'Retry-After': '60' });
    if (!response.ok) {
      // Status metadata only: never log prompts, credentials, or provider messages.
      let detail;
      try { detail = (await response.json()).error; } catch { /* Non-JSON upstream failure. */ }
      console.warn('Gemini rejected generation', response.status,
        /^[A-Z_]+$/.test(detail?.status ?? '') ? detail.status : 'UNKNOWN',
        (detail?.details ?? []).map(item => item.reason).filter(reason => /^[A-Z_]+$/.test(reason ?? '')));
      return respond(502, { error: 'The writing provider is unavailable.' });
    }
    const quote = parseProviderResponse(await response.json(), input.language);
    return respond(200, { id: crypto.randomUUID(), ...quote });
  } catch {
    return respond(502, { error: 'The writing provider could not complete this quote.' });
  }
}
