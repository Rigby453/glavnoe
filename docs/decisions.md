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

## ADR-023: /docs/ANIMATIONS.md is the single source of truth for motion
**Date:** 2026-06-10
**Decision:** The animation spec the user supplied (`animations_tz.md`) is renamed to **`/docs/ANIMATIONS.md`** and declared the single source of truth for all motion: durations (snap 120 / fast 180 / normal 280 / slow 400 ms), curves, per-element behaviour, MVP/Ф1/Ф2 priority, and the accessibility rule (`MediaQuery.disableAnimations`). The `animation` block in `design-tokens.json` (previously fast 120 / normal 200 / slow 300) is updated to mirror ANIMATIONS.md section 0 with an explicit "if they differ, ANIMATIONS.md wins" note; `app/CLAUDE.md` and the flutter agent now point there. Existing hard-coded durations in Dart (200/300 ms) will be migrated to `core/animations/constants.dart` during the MVP animations block.
**Reason:** Two "sources of truth" contradicted each other (tokens said 120/200/300, the spec says 120/180/280/400) and nothing in the repo referenced the spec file at all. One law file kills the drift; tokens keep a mirrored copy only because the landing page reads tokens, not the Flutter spec.
**Date:** 2026-06
**Decision:** Introduced `backend/src/ai/provider.ts` exposing `generateText({ system, user, maxTokens, tier, json, image })`. It picks the provider by env: **Gemini** if `GEMINI_API_KEY` is set (REST, global `fetch`, no SDK; model from `GEMINI_MODEL`, default cheap `gemini-2.0-flash-lite`), otherwise **Anthropic** (existing SDK; `tier` fast→`claude-haiku-4-5`, smart→`claude-sonnet-4-6`, overridable via env). The four AI features (morning message, diary insight, smart redistribute, schedule-import incl. image) were refactored to call `generateText` instead of newing the Anthropic SDK directly. Structured outputs (smart-redistribute, schedule-import) now ask for strict JSON (`responseMimeType` on Gemini) and validate with the existing zod schemas after `stripJsonFences` + `JSON.parse`, instead of Anthropic's `messages.parse`/`zodOutputFormat`.
**Reason:** The user has a Gemini key, not Anthropic, and wants the cheapest model — but may switch to Anthropic later "without much architecture change." A thin provider seam makes the swap an `.env` change (drop in `GEMINI_API_KEY` or `ANTHROPIC_API_KEY`); feature logic and the premium gate are untouched. REST-for-Gemini avoids a new dependency and its version churn. Provider-agnostic JSON-via-prompt (not vendor structured-output helpers) keeps both paths identical. Tests still mock the feature modules, so they pass unchanged. Numbers/data still come from code/DB, never the model (unchanged). Supersedes the Claude-only assumption in [[ADR-006]] (key still backend-only, still only called from `src/ai/`).

## ADR-021: Cross-device delete propagation via Tombstone table
**Date:** 2026-06
**Decision:** Added a `Tombstone` model (`userId`, `itemId`, `deletedAt`, unique `(userId,itemId)`, index `(userId,deletedAt)`; Neon migration `add_tombstone`). Deleting an item — via `POST /sync deleted_item_ids` **or** `DELETE /items/:id` — now records a tombstone. `/sync` returns `deleted_item_ids` = tombstones with `deletedAt > last_sync_at`, **excluding ids the caller sent in the same request** (so a device isn't told to delete what it just deleted). The client applies these by removing the local rows directly (not via `ItemsDao.deleteItem`, so no new tombstone/loop).
**Reason:** Closes the known limitation from [[ADR-019]]: outgoing deletes reached the server, but other devices never learned of them (the item lingered on device B). A dedicated tombstone table keeps existing item queries (GET/redistribute/streak) untouched — a soft-delete column on Item would have forced `deletedAt IS NULL` filters everywhere and risked leaks. Mirrors the additive, optional sync-contract style of water/day-logs. Tombstones grow unbounded; acceptable for now (few deletes), revisit with periodic pruning (e.g. >90 days) if needed. Completes the sync story: items (LWW), water (append), day logs (LWW-by-date), deletes (tombstones), streak recompute.

## ADR-020: Diary (DayLog) sync — keyed by date, last-write-wins via updatedAt
**Date:** 2026-06
**Decision:** Added `updatedAt DateTime @default(now()) @updatedAt` to `DayLog` (Prisma migration `add_daylog_updated_at` on Neon; data-model updated) and a matching column to the client Drift `day_logs` table (schemaVersion 1→2 migration). `/sync` gained optional `day_logs` (request) and `updated_day_logs` (response). The server upserts each incoming day log **by `(userId, date)`** (the existing `@@unique`), applying it only if `incoming.updated_at > existing.updatedAt` (LWW, same `@updatedAt` model as Items), and creating it otherwise. The client sends day logs changed since `last_sync_at` and merges server rows **by date** (not id), since each device mints its own uuid for the same date.
**Reason:** Diary entries were local-only (no backup/cross-device). Unlike water (append-only, ADR-017), day logs are mutable (one per day, edited in place), so they need an `updatedAt` to (a) compute the outgoing delta and (b) resolve conflicts — hence the migration the work was waiting on. Keying by `(user, date)` rather than the surrogate uuid avoids duplicate rows when two devices independently create a uuid for the same day. LWW mirrors Items for consistency (ADR-004); the cross-clock caveat (server `@updatedAt` is server-time) is the same accepted trade-off. The contract change is additive/optional → backward compatible. The Neon migration is routine; the only care point was the on-device Drift `addColumn` migration (default `currentDateAndTime` backfills existing rows). Completes the "sync everything" line after [[ADR-017]] (water) and [[ADR-019]] (deletes).

## ADR-019: Delete sync via SyncQueue tombstones + /sync deleted_item_ids
**Date:** 2026-06
**Decision:** Deleting an item now (a) removes it from the local Drift `items` table and (b) writes a tombstone row into the existing `sync_queue` table (`operation='delete'`, `table_name='items'`, `record_id=id`). On the next sync, `SyncService` sends those ids as `deleted_item_ids` in the (additive, optional) `/api/v1/sync` request; the server `deleteMany`s them scoped by `userId` (ownership), and the client clears the processed tombstones. Added a Delete action to the edit-task sheet (there was none before). Cross-device *incoming* deletes (device A deletes → device B learns) still aren't handled — that needs server-side tombstones; documented as a known limitation.
**Reason:** Two bugs: users couldn't delete a task at all (no UI), and the audit flagged that local deletes never reached the server — so a deleted task **reappeared** on the next `/sync` (server still had it and returned it in `updated_items`). Sending `deleted_item_ids` makes the server drop them first, fixing the reappearance. This finally uses the `SyncQueueTable` that was declared in the Drift schema but dead (audit: "мёртвая таблица"). Writing the tombstone via `attachedDatabase` from `ItemsDao` avoids adding the table to its `@DriftAccessor` (no codegen). Contract change is additive/optional → backward compatible. Builds on [[ADR-017]] (water) and [[ADR-004]] (last-write-wins).

## ADR-018: Dev-only subscription upgrade endpoint (test premium before payments)
**Date:** 2026-06
**Decision:** Added `POST /api/v1/subscription/dev-upgrade` (auth required) that sets the current user's `subscriptionTier` to `premium`/`free`. It returns **404 when `NODE_ENV=production`** — usable only in dev/test/staging. The Flutter paywall exposes it only under `kDebugMode` ("Dev: unlock premium"); the real "Subscribe" CTA is a placeholder until payments exist.
**Reason:** AI features are premium-gated server-side (`subscriptionTier==='premium'`), but real payments (RevenueCat) are Phase 1 and not built. Without a way to flip the tier, premium/AI is untestable from the app except by hand-editing the DB. A non-production endpoint is the standard, low-risk way to exercise the paid path end-to-end; the hard `NODE_ENV` gate keeps it out of production. Documented in `api-spec.yaml` under a `Subscription` tag so the contract stays the source of truth. Replace with a real receipt-validation flow in Phase 1. See [[ADR-015]] (premium gate) — same gate this toggles.

## ADR-017: Water logs sync via the existing /sync endpoint (append-only, no schema change)
**Date:** 2026-06
**Decision:** Extend `POST /api/v1/sync` (not a new endpoint) to also carry water logs: `SyncRequest.water_logs` (optional) and `SyncResponse.updated_water_logs`. Water logs are treated as **append-only immutable events**: the server upserts by `id` (creates if absent, owned by the JWT user; never updates an existing row), and returns the user's water logs with `loggedAt > last_sync_at`. The client sends local water logs with `loggedAt > last_sync_at` and merges the response by `id`. No `updatedAt` column and **no Drift/Prisma migration** were needed (client `WaterLogsTable` stays `id/amountMl/loggedAt`; it does not store `userId` — the server assigns it from the token).
**Reason:** Water/diary data lived only on-device (no backup/cross-device) even for signed-in users. Water logs are immutable single events, so they need no last-write-wins conflict resolution — a create-if-absent upsert keyed by the client UUID is correct and idempotent, and `loggedAt` doubles as the "changed since" marker. Reusing `/sync` keeps one sync path and one round-trip; the new fields are optional so the contract stays backward-compatible. DayLogs are mutable (one per day) and **do** need `updatedAt`-based LWW, so they are handled in a separate change (with a migration), not here.

## ADR-016: Streak computed on both client (offline-first) and backend (on sync)
**Date:** 2026-06
**Decision:** The streak is computed in **two places using identical rules**: (1) client-side `StreakService.recomputeForDay` (`app/lib/services/streak/streak_service.dart`) runs whenever today's main items change and writes the local Drift `StreakTable`; (2) backend `checkAndUpdateStreak` now runs from **both** `PATCH /items` **and** `POST /sync` (for every day where a main item transitions to `done` in the batch). The client treats its local value as authoritative for display and does **not** pull `GET /streaks` into local storage.
**Reason:** The streak ("everything important closed N days in a row") is a flagship product hook, but it was effectively dead: the client only ever *read* the local `StreakTable` (nothing wrote it), and the backend only recomputed on `PATCH /items` — which the offline-first client never calls (it persists via Drift and ships changes through `/sync`). So the streak showed `0` for everyone. Offline-first + no-account mode means the streak must be computable with no network, hence client-side computation is the primary, user-visible fix. The backend recompute on `/sync` keeps the server value correct for backup/cross-device and future features. Both use the same rules (all `main` items `done`; strict `done`, `skipped` does not count; yesterday→+1, freeze consumes a miss, else reset to 1; idempotent per day) so the two sources converge to the same number from the same item data. Avoided pulling `GET /streaks` into the client to prevent a second conflicting write path; revisit when true multi-device sync of streak/water/day-logs lands.

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
