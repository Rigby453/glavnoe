# Architecture Decision Records — Kaizen

> Append here whenever you make a significant architectural choice.
> Format: ## ADR-NNN: Title | Date | Decision | Reason

---

## ADR-001: Flutter for all platforms
**Date:** 2025-01
**Decision:** Flutter (iOS + Android + Web) over React Native or separate codebases
**Reason:** Single codebase, strong offline support via Drift, good animation control for themes

## ADR-002: Claude API models
**Date:** 2025-01
**Decision:** Haiku 4.5 for bulk/frequent, Sonnet 4.6 for complex reasoning
**Reason:** Cost balance — Haiku is 3× cheaper, sufficient for morning messages and food ID; Sonnet for redistribution reasoning and diary insights

## ADR-003: Offline-first with Drift
**Date:** 2025-01
**Decision:** Write to local SQLite (Drift) first, sync to backend async
**Reason:** Students use app in lecture halls with poor connectivity; data must never be lost

## ADR-004: Last-write-wins sync
**Date:** 2025-01
**Decision:** Sync conflict resolution = newer updatedAt wins
**Reason:** Simple to implement for MVP; revisit if users report data loss (Phase 2)

## ADR-005: Redistribution is proposals only
**Date:** 2025-01
**Decision:** Engine returns proposed changes; user must confirm before items are moved
**Reason:** Autonomy is core to the product — the app suggests, the user decides

## ADR-006: Claude API key on backend only
**Date:** 2025-01
**Decision:** Flutter client never calls Claude API directly — always via backend proxy endpoints
**Reason:** Security (key exposure), rate limiting, cost control, ability to add caching/batching

## ADR-007: Rule-based redistribution endpoint
**Date:** 2026-06
**Decision:** Expose the MVP rule engine as `POST /api/v1/redistribute` returning `{ proposed, skipped }` (proposals only, nothing saved). The premium AI variant is `POST /api/v1/ai/redistribute`.
**Reason:** The task files defined the engine logic but no REST endpoint for the client to fetch proposals. The Today morning-review UI needs one. Kept separate from the AI endpoint so the free tier works without AI.

## ADR-008: API payloads use snake_case
**Date:** 2026-06
**Decision:** All API request/response fields use snake_case (e.g. `scheduled_at`, `is_protected`, `access_token`, `updated_items`). Prisma models stay camelCase internally and are mapped at the route boundary.
**Reason:** The task-file examples already use snake_case; `api-spec.yaml` codifies it as the single source of truth to avoid client/server drift.

---

<!-- Add new ADRs below this line -->

## ADR-015: New AI endpoint /api/v1/ai/schedule-import (Phase 1, premium)
**Date:** 2026-06
**Decision:** Added `POST /api/v1/ai/schedule-import` to `api-spec.yaml`: a premium (Phase 1) multimodal endpoint that takes `{ image_base64, media_type, target_date }`, has Claude (Haiku, multimodal) read a timetable photo, and returns `{ items: [{ title, scheduled_at }] }`. Nothing is saved server-side — the client confirms and creates items via `POST /items`.
**Reason:** The user requested photo-based schedule import as a paid feature. There was no existing endpoint for "photo → schedule items" (the existing `ai/food-recognize` is for the Food module). Per project rules the Claude call lives only in `backend/src/ai/`; the route enforces the premium gate (free tier → 403). Adding a new endpoint (vs. changing an existing one) keeps the contract backward-compatible. Live verification requires a real `ANTHROPIC_API_KEY` (the `.env` currently holds a placeholder) and a premium user, so tests mock `backend/src/ai/`.

## ADR-014: 404 (not 403) for non-owned items on PATCH and DELETE
**Date:** 2026-06
**Decision:** When PATCH `/api/v1/items/:id` or DELETE `/api/v1/items/:id` is called and the item does not exist **or** exists but belongs to a different user, the server returns `404 { error: "Not found" }`. A `403 Forbidden` is never returned for these two endpoints.
**Reason:** `/docs/api-spec.yaml` is the single source of truth for HTTP contracts. For both PATCH and DELETE it lists only `401` and `404` as possible error codes, and the `NotFound` response description explicitly reads "also returned for items owned by another user". `/docs/agents/backend-tasks.md` (ITEMS-03) mentions 403 for non-owned items, but that contradicts the spec. The spec wins (per global rule: "API responses must match api-spec.yaml"). Returning 404 also avoids leaking the existence of items owned by other users (information-exposure mitigation).

## ADR-012: JWT type augmentation via ambient .d.ts, not runtime import
**Date:** 2026-06
**Decision:** `src/types/fastify-jwt.d.ts` augments `@fastify/jwt` with `FastifyJWT { payload, user }`. It is included automatically via `"include": ["src/**/*"]` in tsconfig and is never imported at runtime.
**Reason:** TypeScript module augmentation in `.d.ts` files emits no JavaScript. Importing a `.d.ts` path at runtime causes a `MODULE_NOT_FOUND` error. The ambient approach gives full type safety (`req.user: { userId: string; email: string }`, no `any`) without a runtime artifact.

## ADR-013: serializeUser as an explicit mapping function (no Omit/Pick hacks)
**Date:** 2026-06
**Decision:** `src/models/user.ts` exports `serializeUser(user: User): SerializedUser` which explicitly lists every field and renames camelCase Prisma fields to snake_case API fields. `passwordHash` is simply not mapped.
**Reason:** Relying on `Omit<User, 'passwordHash'>` or spread would still produce camelCase keys in the JSON response, violating `api-spec.yaml`. An explicit return object is the only way to guarantee both the correct key names and the absence of sensitive fields. TypeScript enforces completeness via the `SerializedUser` return type.

## ADR-009: Prisma 5 (not 7) — downgrade from npm resolution
**Date:** 2026-06
**Decision:** Pin `prisma` and `@prisma/client` at `^5.22.0` despite npm resolving to 7.x.
**Reason:** Prisma 7 removes `url = env(...)` from `datasource db {}` and requires a `prisma.config.ts` file — incompatible with the schema in `/docs/data-model.md` (written for Prisma 5). Downgrading keeps the schema verbatim and avoids changing a shared contract.

## ADR-010: TypeScript module=Node16 / moduleResolution=node16 with CommonJS output
**Date:** 2026-06
**Decision:** `tsconfig.json` uses `"module": "Node16"` and `"moduleResolution": "node16"`. TypeScript emits CommonJS (`.js` files, `require` calls at runtime).
**Reason:** TypeScript 6 deprecated `moduleResolution: node` (alias for node10) and produces an error with it. `Node16` is the correct pairing for projects targeting Node.js 22 with CommonJS output; it satisfies TypeScript 6 and ts-node-dev 2 without top-level-await issues.

## ADR-011: migrate dev succeeded on Neon cloud DB (no fallback needed)
**Date:** 2026-06
**Decision:** Used `prisma migrate dev --name init` directly. No fallback to `migrate deploy` or `db push` was needed.
**Reason:** Neon's serverless PostgreSQL allowed Prisma to create the shadow database. Migration SQL is recorded under `prisma/migrations/20260606183848_init/migration.sql` and the schema is in sync.
