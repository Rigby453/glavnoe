# QA Agent — Kaizen

## Read these first
1. /CLAUDE.md — architecture, offline-first principle
2. /docs/api-spec.yaml — every endpoint needs at least one test
3. /docs/data-model.md — DB constraints to verify
4. /docs/agents/qa-tasks.md — detailed test scenarios

---

## Stack
- Backend: **Jest** + **Supertest** + **ts-jest** + test PostgreSQL DB
- Flutter: **flutter_test** + **mockito** (mock Drift + Dio)

## Test structure
```
tests/
├── integration/
│   ├── auth.test.ts       ← register, login, /me
│   ├── items.test.ts      ← CRUD, ownership, date filters
│   ├── streak.test.ts     ← increment, freeze, reset
│   └── sync.test.ts       ← conflict resolution
└── unit/
    ├── engine.test.ts     ← redistribution logic
    └── streak-logic.test.ts
```

---

## Setup
- Use a separate test DB: `DATABASE_URL_TEST` in `.env.test`
- Each test file creates its own user (via register endpoint) — tests are independent
- Mock `backend/src/ai/` entirely — no real Claude API calls in tests
- Run with: `npx jest --runInBand` (serial for DB tests)

---

## Priority scenarios for MVP

### Auth
- Register → 201 + JWT
- Same email → 409
- Login correct → 200 + JWT
- Login wrong password → 401
- /me with valid JWT → user object (no passwordHash exposed)
- /me without JWT → 401

### Items
- Create task → is_protected = false by default
- Create with priority=main → is_protected = true
- Get items with date range → only items in range returned
- PATCH status=done → status updated
- PATCH another user's item → 404
- DELETE item → 204; subsequent GET returns nothing

### Streaks
- Complete all main items → streak.current += 1
- Complete partial main items → streak NOT incremented
- Miss a day, freeze_count=1 → streak holds, freeze_count=0
- Miss a day, freeze_count=0 → streak resets to 0 (or 1 if completed today)

### Sync conflict
- Local item updated at T+5, server at T+3 → server gets local version
- Server item updated at T+5, local at T+3 → local gets server version
- Local new item (no server copy) → created on server, id returned

### Redistribution engine (unit)
- 3 pending items (main/high/low) → proposed order: main first
- is_protected=true item → excluded from redistribution
- No free slots → remaining items appended at end of day
- No pending items → empty proposed array

---

## Rules
- Never test with real ANTHROPIC_API_KEY — mock ai/ module with jest.mock()
- Each test cleans up its own data (or uses transactions that roll back)
- Tests must pass with `NODE_ENV=test` and `DATABASE_URL_TEST`
- A test failure = a bug, not "flaky infra" — fix root cause
