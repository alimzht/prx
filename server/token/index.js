// Token endpoint in the format LiveKit's EndpointTokenSource expects:
// POST /token {"room_name","participant_name"} -> {"server_url","participant_token",...}
import http from 'node:http';
import { randomUUID } from 'node:crypto';
import { AccessToken } from 'livekit-server-sdk';

const { LIVEKIT_API_KEY, LIVEKIT_API_SECRET, LIVEKIT_URL, PORT = '3000' } = process.env;
if (!LIVEKIT_API_KEY || !LIVEKIT_API_SECRET || !LIVEKIT_URL) {
  console.error('LIVEKIT_API_KEY, LIVEKIT_API_SECRET and LIVEKIT_URL are required');
  process.exit(1);
}

const ROOM = /^[A-Za-z0-9-]{1,32}$/;
const MAX_BODY = 4096;

// Returns {status, body}; exported so the self-check can call it without a socket.
export async function issueToken(input) {
  const room = typeof input?.room_name === 'string' ? input.room_name.trim() : '';
  const name = typeof input?.participant_name === 'string' ? input.participant_name.trim() : '';
  if (!ROOM.test(room)) return { status: 400, body: { error: 'room_name: 1-32 letters, digits or -' } };
  if (name.length < 1 || name.length > 20) return { status: 400, body: { error: 'participant_name: 1-20 characters' } };

  // Random identity: two friends with the same name must not kick each other out of the room.
  const at = new AccessToken(LIVEKIT_API_KEY, LIVEKIT_API_SECRET, { identity: randomUUID(), name, ttl: '6h' });
  at.addGrant({ roomJoin: true, room, canPublish: true, canSubscribe: true, canPublishData: true });
  return {
    status: 200,
    body: { server_url: LIVEKIT_URL, participant_token: await at.toJwt(), participant_name: name, room_name: room },
  };
}

function send(res, status, body) {
  res.writeHead(status, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(body));
}

// shortcut: no auth or rate limit, so anyone who finds the URL can get a token (same as the dev token server);
// add a per-IP limit or an app key header before sharing the app widely.
const server = http.createServer((req, res) => {
  if (req.method !== 'POST' || req.url !== '/token') return send(res, 404, { error: 'not found' });
  let raw = '';
  req.on('data', (chunk) => {
    raw += chunk;
    if (raw.length > MAX_BODY) {
      send(res, 413, { error: 'body too large' });
      req.destroy();
    }
  });
  req.on('end', async () => {
    if (res.writableEnded) return;
    let input;
    try {
      input = JSON.parse(raw);
    } catch {
      return send(res, 400, { error: 'invalid JSON' });
    }
    try {
      const { status, body } = await issueToken(input);
      send(res, status, body);
    } catch (err) {
      console.error(err);
      send(res, 500, { error: 'token generation failed' });
    }
  });
});

if (process.env.TOKEN_SELF_CHECK !== '1') {
  // Only Caddy on the same host should reach this.
  server.listen(Number(PORT), '127.0.0.1', () => console.log(`token server on 127.0.0.1:${PORT}`));
}
