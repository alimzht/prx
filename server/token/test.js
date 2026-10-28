// Self-check: node test.js
import assert from 'node:assert/strict';
process.env.TOKEN_SELF_CHECK = '1'; // import without opening a port
process.env.LIVEKIT_API_KEY = 'devkey';
process.env.LIVEKIT_API_SECRET = 'secret-secret-secret-secret-secret';
process.env.LIVEKIT_URL = 'wss://lk.example.com';
const { issueToken } = await import('./index.js');

const ok = await issueToken({ room_name: 'K7Q2XP', participant_name: ' Даурен ' });
assert.equal(ok.status, 200);
assert.equal(ok.body.server_url, 'wss://lk.example.com');
assert.equal(ok.body.participant_name, 'Даурен');
const claims = JSON.parse(Buffer.from(ok.body.participant_token.split('.')[1], 'base64url'));
assert.equal(claims.video.room, 'K7Q2XP');
assert.equal(claims.video.roomJoin, true);
assert.equal(claims.name, 'Даурен');

assert.equal((await issueToken({ room_name: '../x', participant_name: 'a' })).status, 400);
assert.equal((await issueToken({ room_name: 'K7Q2XP', participant_name: '' })).status, 400);
assert.equal((await issueToken({ room_name: 'K7Q2XP', participant_name: 'x'.repeat(21) })).status, 400);
assert.equal((await issueToken(null)).status, 400);
console.log('token server ok');
