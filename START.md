# How to start (orchestrator session)

The "orchestra" is a Claude Code chat opened **inside this folder**.
Read order for any new session: `/CLAUDE.md` → `/AGENTS.md` → subdir `CLAUDE.md` → `/docs/`.
Current status and phase: `/docs/BOARD.md`.

> The original bootstrap prompt that lived here is obsolete — the MVP build order
> from AGENTS.md has long been completed. The orchestrator system prompt is now
> provided in-chat by the user.

## Running locally

- **Backend:** `cd backend && npm run dev` (Fastify on `PORT` from `backend/.env`, default 3000; DB = Neon PostgreSQL via `DATABASE_URL`).
- **App (desktop/web):** `cd app && flutter run` (backend URL defaults to `http://localhost:3000`).
- **App on a real phone (USB):** `powershell -ExecutionPolicy Bypass -File scripts\run-phone.ps1`
  — detects the laptop's LAN IP and runs flutter with `--dart-define=API_BASE_URL=http://<LAN_IP>:3000`.
  Extra args go to flutter run: `... run-phone.ps1 -- -d <device-id>`.
  Phone and laptop must be on the same Wi-Fi; backend listens on 0.0.0.0 already.
  If the phone can't reach the backend, allow inbound TCP 3000 in Windows Firewall once:
  `New-NetFirewallRule -DisplayName "Kaizen backend 3000" -Direction Inbound -Protocol TCP -LocalPort 3000 -Action Allow` (admin PowerShell).
- **Backend tests:** `cd backend && npx jest --runInBand`.
- **App analyze/tests:** `cd app && flutter analyze && flutter test`.

## Secrets (backend/.env — never commit)

- `DATABASE_URL` — Neon PostgreSQL ✓
- `JWT_SECRET` ✓
- `GEMINI_API_KEY` — **empty; required to make AI features live** (provider abstraction, ADR-022)
- `ANTHROPIC_API_KEY` — placeholder; alternative AI provider
