# Modern Bank Secure Stack

Modern Bank now runs as an encrypted three-tier deployment with JavaScript frontend delivery, HTTPS backend APIs, and MongoDB over TLS.

## Topology

- Frontend: `10.0.10.105`
- Backend: `10.0.10.102`
- Database: `10.0.10.106`

```
Browser
  |
  | HTTPS (TLS 1.2+)
  v
Frontend (10.0.10.105)
Nginx "godproxy" + JS app
  |
  | HTTPS + X-Internal-Token
  v
Backend (10.0.10.102)
Node.js API (HTTPS only, JWT auth)
  |
  | MongoDB TLS (requireTLS)
  v
Database (10.0.10.106)
MongoDB 7 (auth enabled)
```

## What Changed

1. Frontend migrated to JavaScript app deployment (`frontend/app`) behind Nginx TLS edge.
2. Backend moved to HTTPS-only API with:
   - service-to-service token gate (`X-Internal-Token`)
   - user JWT auth (`Bearer`)
   - deterministic tokenization before MongoDB writes
3. Database tier moved to MongoDB with `requireTLS` and authentication.
4. Deployment scripts updated for encrypted defaults.

## Deployment Order

Run each step on its target machine.

The fixed lab IPs are already baked into the deployment scripts. In the standard environment, you can run the wrapper scripts with no IP arguments.

### 1) Database Tier (`10.0.10.106`)

```bash
cd /path/to/vulnerable-bankapp/database
powershell -ExecutionPolicy Bypass -File .\setup_mongo.ps1
```

Default DB app credentials used by scripts:

- `DB_USER=modernbank_app`
- `DB_PASS=ModernBankMongo!2026`
- `DB_NAME=modernbank`

## 2. Shared Internal API Token

This repo now includes a deployment-wide default token in `deployment.defaults.env`.

For this instance, backend, frontend, and verification scripts will all use that same value automatically if you do not pass a token argument.

You only need to pass a token manually if you want to override the repo default.

### 3) Backend Tier (`10.0.10.102`)

```bash
cd /path/to/vulnerable-bankapp/backend
sudo bash setup_node.sh
```

### 4) Frontend Tier (`10.0.10.105`)

```bash
cd /path/to/vulnerable-bankapp/frontend
sudo bash setup_nginx_proxy.sh
```

### 5) Verify

From an admin workstation:

```bash
bash verify_deployment.sh
```

## Runtime Endpoints

### Frontend

- `https://10.0.10.105/`

### Backend (direct)

- `https://10.0.10.102:8443/api/health` (requires `X-Internal-Token`)

### API through frontend proxy

- `POST /api/auth/login`
- `GET /api/auth/me`
- `GET /api/health`
- `GET /api/db-status`
- `GET /api/records`
- `POST /api/records`
- `GET /api/tokenization/example`

## JavaScript Migration Status

- Active frontend runtime: JavaScript app in `frontend/app`.
- Legacy PHP code under `frontend/www` is retained for reference but not used by the secure deployment scripts.

## Security Controls in Place

- TLS edge on frontend (`443`, HSTS, redirect from `80`).
- TLS backend API (`8443`) with local certificate.
- Frontend-to-backend calls proxied over HTTPS.
- Service-to-service token gate (`X-Internal-Token`) on backend routes.
- User session security via JWT bearer tokens.
- MongoDB `requireTLS` and authentication enabled.
- Sensitive values tokenized before persistence (deterministic HMAC tokenization).

## Notes

- Current scripts default to self-signed certs for bootstrap. Traffic is encrypted; certificate trust pinning can be tightened later by distributing CA files and enabling strict proxy verification.
- If you rotate DB credentials, pass updated values to backend setup via `MONGO_APP_USER` and `MONGO_APP_PASSWORD`.
