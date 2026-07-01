# Backend Agent — Kaizen

## Read these first (in order)
1. /CLAUDE.md — project overview, principles, phase plan
2. /docs/api-spec.yaml — OpenAPI 3.0, implement endpoints **exactly** as specified
3. /docs/data-model.md — Prisma schema, use **as-is**, do not modify column names

---

## Stack
Node.js 22 · Fastify 4 · Prisma 5 · TypeScript 5 · PostgreSQL 15

## Project structure
```
backend/
├── src/
│   ├── ai/         ← Claude API calls ONLY here — never elsewhere
│   ├── engine/     ← rule-based redistribution logic (no AI, no API calls)
│   ├── models/     ← Prisma repositories / query helpers
│   └── routes/     ← Fastify route handlers
├── prisma/
│   └── schema.prisma
├── .env            ← never commit to git
└── CLAUDE.md
```

---

## MVP implementation order

### Step 1 — Init
```bash
npm init -y
npm install fastify @fastify/jwt @fastify/cors @prisma/client bcrypt zod
npm install -D typescript ts-node @types/node @types/bcrypt prisma
npx tsc --init
```

### Step 2 — Prisma schema
Copy schema from `/docs/data-model.md` into `prisma/schema.prisma`
```bash
npx prisma migrate dev --name init
```

### Step 3 — Routes (implement in this order)
```
a. POST /api/v1/auth/register   → bcrypt hash, check duplicate (409), return JWT
b. POST /api/v1/auth/login      → compare hash, return JWT
c. GET  /api/v1/auth/me         → verify JWT middleware, return user
d. GET  /api/v1/items           → filter by userId + scheduledAt range
e. POST /api/v1/items           → insert, if priority=main → is_protected=true
f. PATCH /api/v1/items/:id      → partial update, verify ownership
g. DELETE /api/v1/items/:id     → verify ownership, return 204
h. GET  /api/v1/streaks         → upsert if not exists, return streak
i. POST /api/v1/sync            → last-write-wins by updatedAt
```

### Step 4 — Rule engine (`src/engine/redistributor.ts`)
```
Input:  userId: string, date: Date (today)
Logic:
  1. Fetch all Items where userId=userId, status=pending, scheduledAt < today
  2. Sort by priority: main(3) > high(2) > medium(1) > low(0)
  3. Fetch today's items to find occupied time slots
  4. Fill free 30-min slots with pending items (skip is_protected=true)
  5. Return: { proposed: Item[], skipped: Item[] }
Output: proposed plan — do NOT auto-save (user confirms via PATCH)
```

---

## Streak logic (`src/engine/streaks.ts`)
```
On item status change to "done":
  1. Check if all Items with priority=main for today are done
  2. If yes:
     a. If streak.lastCompletedDate = yesterday → streak.current += 1
     b. If streak.lastCompletedDate < yesterday AND freeze_count > 0 → freeze_count -= 1 (streak stays)
     c. If streak.lastCompletedDate < yesterday AND freeze_count = 0 → streak.current = 1
     d. Update streak.longest if current > longest
     e. Update streak.lastCompletedDate = today
```

---

## Rules

| Rule | Detail |
|------|--------|
| Secrets | JWT_SECRET, ANTHROPIC_API_KEY, DATABASE_URL from `.env` ONLY |
| Claude API | ONLY in `src/ai/` — never in routes or engine |
| Passwords | bcrypt saltRounds=12 |
| HTTP codes | 201 created · 200 ok · 401 unauth · 403 forbidden · 404 not found · 409 conflict · 204 deleted |
| Ownership | Always verify item.userId === req.user.id before update/delete |
| Schema | All responses must match `/docs/api-spec.yaml` component schemas exactly |
| Types | No `any` — use Zod for input validation, Prisma types for DB |

---

## Environment variables (from `.env`)
> Neon: `DATABASE_URL` — pooled-строка (хост с `-pooler`, `?pgbouncer=true&connection_limit=...`), её использует рантайм.
> `DIRECT_URL` — прямая строка (без pooler), Prisma берёт её только для миграций (`prisma migrate`). См. `.env.example`.
```
DATABASE_URL=postgresql://...
DIRECT_URL=postgresql://...   # прямая строка Neon (без -pooler) — только для миграций
# AI provider is chosen by whichever key is set (see src/ai/provider.ts),
# priority order: GROQ_API_KEY → GEMINI_API_KEY → ANTHROPIC_API_KEY:
#   GROQ_API_KEY present → Groq (GROQ_MODEL / GROQ_MODEL_SMART), checked BEFORE
#     Gemini — dev/test fallback while Gemini is flaky (see decisions.md ADR)
#   else GEMINI_API_KEY present → Gemini (GEMINI_MODEL, default gemini-2.5-flash-lite)
#   else ANTHROPIC_API_KEY → Claude (haiku/sonnet)
GROQ_API_KEY=gsk_...
GROQ_MODEL=llama-3.1-8b-instant
GROQ_MODEL_SMART=llama-3.3-70b-versatile
GEMINI_API_KEY=AIza...
GEMINI_MODEL=gemini-2.0-flash-lite
ANTHROPIC_API_KEY=sk-ant-...
JWT_SECRET=...
PORT=3000
NODE_ENV=development
# Email delivery for password reset (ADR-059, Resend HTTP API).
# Without RESEND_API_KEY, forgot-password keeps returning dev_code (dev/test only).
RESEND_API_KEY=re_...
RESEND_FROM="Kaizen <noreply@yourdomain.com>"
```
