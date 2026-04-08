# Quick Start (Secure Deployment)

This guide brings up the encrypted Modern Bank stack with the default node layout:

- Backend: `10.0.10.102`
- Frontend: `10.0.10.105`
- Database: `10.0.10.106`

Those IPs are already embedded in the deployment scripts, so the standard path does not require passing IP arguments.

## 1. Database Node (`10.0.10.106`)

```bash
cd /path/to/vulnerable-bankapp/database
powershell -ExecutionPolicy Bypass -File .\setup_mongo.ps1
```

This configures:

- MongoDB with `authorization: enabled`
- `requireTLS` on port `27017`
- firewall rule allowing backend node to reach MongoDB

## 2. Shared Internal Token

This repo ships with a deployment-wide default token in `deployment.defaults.env`.

If you run the setup scripts without a token argument, backend, frontend, and verification will all use that same shared value automatically.

## 3. Backend Node (`10.0.10.102`)

```bash
cd /path/to/vulnerable-bankapp/backend
sudo bash setup_node.sh
```

This configures:

- HTTPS-only Node API on `8443`
- service token validation (`X-Internal-Token`)
- JWT auth endpoints
- tokenization before MongoDB writes

## 4. Frontend Node (`10.0.10.105`)

```bash
cd /path/to/vulnerable-bankapp/frontend
sudo bash setup_nginx_proxy.sh
```

This configures:

- Nginx TLS edge (`443`) with HTTP redirect from `80`
- JS frontend from `frontend/app`
- reverse-proxy route `/api/*` to backend HTTPS
- automatic `X-Internal-Token` forwarding

## 5. Verify End-To-End

```bash
cd /path/to/vulnerable-bankapp
bash verify_deployment.sh
```

## 6. Login Test

Open:

- `https://10.0.10.105/`

Use:

- Username: `julia.ross`
- Password: `BankDemo!2026`

## 7. Expected Results

- Frontend page loads only over HTTPS.
- API health works through frontend proxy.
- JWT login succeeds.
- Database status returns `"mongo_transport":"tls"`.
- Creating a record stores tokenized values (token starts with `tok_`).
