# How to start (orchestrator session)

The "orchestra" is a Claude Code chat opened **inside this folder**.
Read order for any new session: `/CLAUDE.md` → `/AGENTS.md` → subdir `CLAUDE.md` → `/docs/`.
Current status and phase: `/docs/BOARD.md`.

> The original bootstrap prompt that lived here is obsolete — the MVP build order
> from AGENTS.md has long been completed. The orchestrator system prompt is now
> provided in-chat by the user.

## Running locally

- **Backend:** `cd backend && npm run dev` (Fastify on `PORT` from `backend/.env`, default 3000; DB = Neon PostgreSQL via `DATABASE_URL`).
- **App:** `cd app && flutter run` (pass the backend URL via `--dart-define` — see app/CLAUDE.md; on a real phone use the laptop's LAN IP, not localhost).
- **Backend tests:** `cd backend && npx jest --runInBand`.
- **App analyze/tests:** `cd app && flutter analyze && flutter test`.

## Secrets (backend/.env — never commit)

- `DATABASE_URL` — Neon PostgreSQL ✓
- `JWT_SECRET` ✓
- `GEMINI_API_KEY` — **empty; required to make AI features live** (provider abstraction, ADR-022)
- `ANTHROPIC_API_KEY` — placeholder; alternative AI provider
