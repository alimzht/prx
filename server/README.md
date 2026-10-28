# Self-hosted LiveKit for prx

One VPS runs three containers:

| Container | What it does |
|---|---|
| `livekit` | Voice server (SFU). Host networking for the WebRTC UDP range |
| `token` | `POST /token` → LiveKit access token (Node, `token/`) |
| `caddy` | HTTPS with an automatic Let's Encrypt certificate; `/token` → token server, everything else → LiveKit |

The app talks to `https://<domain>/token` for a token and to `wss://<domain>` for the room.

## 1. Server
- Any VPS with a public IPv4, e.g. Hetzner CX22 (2 vCPU, 4 GB). Ubuntu 24.04.
- Install Docker: `curl -fsSL https://get.docker.com | sh`
- Firewall (provider firewall and/or `ufw`), inbound:
  - TCP 80, 443 — HTTPS and certificate issuance
  - TCP 7881 — WebRTC over TCP when UDP is blocked
  - UDP 50000–60000 — WebRTC media

## 2. Domain
Create an `A` record, e.g. `lk.yourdomain.com` → VPS IP. Wait until `ping lk.yourdomain.com` shows the VPS IP; Caddy needs it to get the certificate.

## 3. Start
```sh
git clone https://github.com/alimzht/prx.git && cd prx/server
docker run --rm livekit/livekit-server:v1.13.11 generate-keys   # prints an API key and secret
cp .env.example .env && nano .env                                # domain, key, secret
docker compose up -d --build
docker compose logs -f caddy                                     # wait for "certificate obtained"
```

Check:
```sh
curl -X POST https://lk.yourdomain.com/token \
  -H 'Content-Type: application/json' \
  -d '{"room_name":"TEST01","participant_name":"me"}'
# → {"server_url":"wss://lk.yourdomain.com","participant_token":"eyJ...",...}
```

## 4. Point the app at it
GitHub → Settings → Secrets → Actions → add `LK_TOKEN_URL` = `https://lk.yourdomain.com/token`, then re-run the iOS build. When `LK_TOKEN_URL` is set the app uses this server; otherwise it falls back to LiveKit Cloud's development token server (`LK_SANDBOX_ID`).

## Updating
```sh
git pull && docker compose up -d --build
```

## Limits
- No TURN server: networks that block both UDP and TCP 7881 (some corporate/university Wi-Fi) can't connect.
- `/token` has no auth or rate limit; anyone with the URL can get a token. Fine for friends; add a limit before sharing widely.
- Max 10 people per room (`livekit.yaml`).

Token server self-check: `cd token && npm ci && npm test`.
