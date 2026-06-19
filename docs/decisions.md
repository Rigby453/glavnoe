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

## ADR-038: menu-build accepts optional food_prefs (diet/goal/dislikes/likes/meals_per_day)
**Date:** 2026-06-19
**Decision:** `POST /api/v1/ai/menu-build` gains an optional `food_prefs` request object (backward-compatible; absent = unchanged behavior) with five optional sub-fields: `diet` (string enum hint: none/vegetarian/vegan/pescatarian/halal/kosher/keto/other), `goal` (lose/maintain/gain), `dislikes` (free text), `likes` (free text), and `meals_per_day` (integer 1-8). The route-layer Zod schema trims and validates all strings (max 300 chars) and the integer range before passing a camelCase `foodPrefs` object to `buildMenu()` in `backend/src/ai/menuBuild.ts`. When any sub-field is non-empty, `buildMenu()` appends a clearly-labelled `USER FOOD PREFERENCES` block to the system prompt: diet (if not "none") → hard EXCLUDE instruction; dislikes → avoid instruction; likes → prefer-when-sensible instruction; goal → note that calorie_goal already reflects it (no numeric adjustment by the model); meals_per_day → informational note to not invent meal names beyond the provided `meals` array. The model still outputs only name+grams; all nutrition arithmetic stays code-computed from the food DB. Existing `health_profile`, `language`, and all other parameters are unchanged.
**Reason:** Users following specific diets (vegetarian, keto, halal …) or with strong food dislikes need the AI composer to respect those preferences without manual post-filtering. Structured `diet` + free-text `dislikes/likes` covers both the well-known pattern set and the long tail of personal tastes. `meals_per_day` is informational only — the `meals` array already controls which meal slots are composed. This is preference-based selection bias, not medical or nutritional advice; the disclaimer is embedded in the system prompt. Numbers stay code-computed per the core rule (КБЖУ never from the model).

## ADR-037: menu-build accepts optional free-text health_profile for candidate filtering
**Date:** 2026-06-19
**Decision:** `POST /api/v1/ai/menu-build` gains an optional `health_profile` request field (backward-compatible; absent = unchanged behavior) with three optional free-text string sub-fields: `allergies`, `healing`, `deficiencies` (each trimmed, max 500 chars). When any sub-field is non-empty, `buildMenu()` in `backend/src/ai/menuBuild.ts` appends a clearly-labelled block to the system prompt instructing the model to (a) never include candidate foods that conflict with stated allergies/intolerances and (b) bias selection toward foods rich in nutrients relevant to the notes (e.g. slow wound healing → protein, vitamin C, zinc; stated deficiency → foods rich in that nutrient). The model still outputs only name+grams; all nutrition arithmetic remains code-computed from the food DB. The `language` param and all other existing params are unchanged. This is a preference-based feature, NOT medical advice — the disclaimer is embedded in the system prompt text.
**Reason:** Users with allergies or known deficiencies need the AI-built menu to respect their constraints. Free-text input was chosen (over a structured enum) because the set of allergies and deficiencies is open-ended and users may express them in their native language. The route-layer Zod schema validates and trims input before it reaches the AI module, preserving the boundary that all model calls live in `backend/src/ai/`.

## ADR-036: AI output language driven by Accept-Language request header
**Date:** 2026-06-19
**Decision:** All human-readable AI output (morning message, diary insight, wrapped summary, redistribute label/reason, menu note) is localised to the language indicated by the client's `Accept-Language` header. A `langName()` helper in `backend/src/routes/ai.ts` maps the two-character tag to a full language name (en→"English", ru→"Russian", de→"German", default "English") and passes it as a `language` parameter (defaulting to "English") to each generator in `backend/src/ai/`. Each generator appends the instruction to its system prompt: "Write all human-readable text in ${language}. Keep JSON keys and structure exactly as specified in English." Structured fields (ids, meal names, grams, time values, enum-like keys) remain in English so the client-side code matching them is not affected. Language travels via the existing HTTP header — the API request/response body schemas in `api-spec.yaml` are unchanged.

## ADR-035: Fix Gemini REST inline_data field names for multimodal (food-photo) requests
**Date:** 2026-06-18
**Decision:** Corrected the image part in `backend/src/ai/provider.ts` `geminiGenerate()`: the field was `inlineData: { mimeType, data }` (camelCase, JavaScript convention) but the Gemini REST API v1beta requires snake_case — `inline_data: { mime_type, data }`. Simultaneously moved the image part before the text part in the `parts` array (Gemini docs: image first, prompt after for vision tasks).
**Reason:** The camelCase `inlineData` key is unknown to the Gemini REST API; it silently ignores the field. The request reaches the model with no image, the model returns an empty response (or blocks), `geminiGenerate` throws `"Gemini returned an empty response"`, which propagates to the `aiError` handler in the route and returns HTTP 502 `"AI service unavailable. Please try again later."` — the exact error the user sees. This affected every multimodal call (AI-03 food photo, AI-06 schedule-import). Text-only AI calls (AI-01 redistribute, AI-02 morning message, AI-04 diary insight) were unaffected because they never set `image`. Fix is in `backend/src/ai/provider.ts` only; no contract or schema changes. All 11 AI integration tests pass (they mock the provider module).

## ADR-034: AI usage limits persisted in an AiUsage table (not in-memory)
**Date:** 2026-06-18
**Decision:** Replace the in-memory `Map` that enforces the food-photo daily limit (3/day, AI-03) in `backend/src/routes/ai.ts` with a persistent `AiUsage` table (`userId`, `day` `YYYY-MM-DD` UTC, `feature`, `count`, unique `(userId, day, feature)`). The quota check becomes an atomic upsert-with-increment and a compare against the limit. Keyed by `feature` so future paid AI features reuse the same table.
**Reason:** The in-memory counter reset on every process restart and was not shared across instances, so the paid-feature limit (which exists for AI cost control, ADR-006) could be bypassed by waiting for a redeploy or load-balancing across replicas. A DB-backed counter is durable and correct under horizontal scale. Listed as known techdebt in docs/STATUS.md; this closes it.

## ADR-033: Navigation & layout codified "by science" in docs/UX-LAYOUT.md
**Date:** 2026-06-18
**Decision:** Created `docs/UX-LAYOUT.md` as the source of truth for control placement, accent usage, and tap-reduction. It **confirms the existing navigation** (4 bottom tabs Today·Plan·Health·Diary, profile as a top-left avatar — not a tab, FAB bottom-right with voice) and grounds it in UX laws (thumb-zone/Hoober, Fitts, Hick, Miller, Jakob, Tesler, progressive disclosure). It adds clearly-marked **[Шлифовка]** refinements (not rewrites): FAB gap from the tab bar + collapse-on-scroll + 360px check; pin the ember exam-countdown card atop the Plan list; remove the "wall of lime" in Food (accent only on the headline metric + done-marks, secondary macro bars muted); first-use affordance hint for swipe gestures; smart defaults on task create (today / next free slot) for one-tap save; Kai's slot in the Today header. Accent rule fixed: lime = primary/selected/success/the-one-main-thing only; ember = urgent/overdue/harsh only; never mixed.
**Reason:** The user asked to think through button placement "по науке" and lock it in the spec the orchestrator's agents read — without breaking it. The 4-tab + avatar + FAB layout was already correct per the laws (so it's confirmed, not changed); the value added is the documented rationale (why profile sits in the hard-to-reach corner, why 4 tabs) plus a small set of additive polish items that become design-backlog tasks. Kept as a separate doc referenced from SPEC §C and app/CLAUDE.md so existing contracts stay intact (per the rule "ask before changing a shared contract" — this only references, it does not rewrite). The refinement list mirrors observations from the user's own app screenshots. Pairs with [[ADR-032]] (mascot) as the design-polish layer over the feature-complete app.

## ADR-032: Mascot "Kai" — abstract AI-presence (soft morphing squircle), spec in docs/MASCOT.md
**Date:** 2026-06-18
**Decision:** Adopt a brand mascot, codename **`Kai`** (provisional, from *Kaizen*; UI name may change later — a one-line rename, no architecture impact). Concept fixed in `docs/MASCOT.md`: an abstract **AI-presence**, not a creature/robot/humanoid — a **soft squircle** ("warm pebble"), **head only** (no body/limbs), **two asymmetric dash-eyes, no mouth**; emotion conveyed only through eye shape/colour and body morph. Base form holds ~95% of the time and **morphs at key emotional beats** (fright squashes/sharpens, joy rounds, failure "melts" down) — premium liquid feel without liquid's cost/legibility issues. **Eyes = the active theme's accent colour** (the only coloured element), so Kai is theme-branded for free. Behaviour is driven by the **existing `tone` pref (gentle/harsh)** — no new setting; Kai "speaks" the existing §B6 tone strings (no new copy system). Implementation: **Rive** state machine (inputs: `isHarsh`, `emotion` 0–5, `morph` 0–1, `action` triggers, `themeAccent`); static under `MediaQuery.disableAnimations` and minimal-morph in Contrast theme. **Off-toggle in Profile** (some adults dislike mascots). It is an ambient design layer over the feature-complete app — never blocks content, never adds taps.
**Reason:** The user wants a companion that reads as a sci-fi AI assistant with character (≈70% J.A.R.V.I.S. / 20% Nothing OS / 10% Duolingo), for an adult 18–35 audience — explicitly *not* a Duolingo-style cute creature. Three independent AI concepts converged on the same shape (head-only, two eyes, no mouth, theme-coloured eyes, tone-driven), so the concept is settled; the only real fork was the form, resolved by the user to "mostly squircle, morphs situationally". Reusing the existing tone toggle (instead of a new mode) makes the character's edge legitimate (user opted in) and avoids new state/copy. Rive over Lottie for cheap, vector, interactive state machines. Logged now as a design contract so the flutter agent can build it later from a single source; phasing in MASCOT.md §9. Pairs with [[ADR-033]] (layout polish).

## ADR-031: Auth identifiers comply with RF law 406-FZ — phone + RU-only email, no foreign OAuth
**Date:** 2026-06-18
**Decision:** Authentication moves off foreign identity providers to satisfy RF law № 406-ФЗ (ban on authorizing RF-resident users via foreign email/services; fines introduced June 2026). Concretely:
1. Removed the Google/Apple "Continue with…" buttons from the Flutter auth screen (they were stubs, never wired to any backend).
2. Added phone-number login: `phone` (Russian E.164 `+7XXXXXXXXXX`, unique, nullable) on the User model alongside `email` (now nullable). Register/login accept **exactly one** identifier — email OR phone — plus password (+ name on register).
3. Email registration is restricted to Russian email providers via an allow-list (default: mail.ru, bk.ru, list.ru, inbox.ru, yandex.ru, ya.ru, rambler.ru, …), overridable via env `ALLOWED_EMAIL_DOMAINS`. Foreign domains (gmail.com, outlook.com, …) are rejected with 400.
4. Phone login is **password-only — no SMS verification** (product decision: avoid a paid SMS provider for launch). Consequence: phone-only accounts have no password-recovery path until SMS is added (email reset flow unchanged).
**Reason:** Target audience is RF, so the product must comply. Phone is the law's primary identifier; RU-only email keeps the familiar flow within the law. Storing the address on our own server does **not** make a foreign address (gmail) compliant — the law governs which provider an address belongs to, not where it is stored. SMS verification is deferred to keep launch cost at zero; revisit with budget (ties to phone-based password reset).

## ADR-030: Share links are signed JWTs, not DB rows
**Date:** 2026-06-11
**Decision:** `POST /api/v1/share` signs a JWT with `{ purpose: 'share', user_id, from, to }` and `expiresIn: '7d'`. The public URL is `/share/<token>`. The handler for both `GET /share/:token` and `GET /api/v1/share/:token` calls `fastify.jwt.verify`, checks `payload.purpose === 'share'`, fetches the owner's items in `[from, to)` from the DB at request time, and returns either HTML (dark Focus theme, inline CSS) or JSON based on the `Accept` header. No new Prisma model, no migration, no revocation in v1.
**Reason:** Zero schema changes keep this Ф3 feature deliverable without touching the DB contract. Stateless JWT verify scales horizontally without a DB lookup for auth. Revocation and analytics (e.g. view counts) can be layered on with a `SharedLink` table when the "shared with me" in-app feature (also Ф3) arrives — at that point the token becomes a lookup key into the table rather than the data store itself.

## ADR-029: Restaurant-menu food input deferred to Ф3 (delivery integration)
**Date:** 2026-06-11
**Decision:** The «ресторан-меню» input method from SPEC C5 ships in Ф3 together with the delivery integration, not in Ф1. In Ф1 the restaurant use case is covered by the existing inputs: AI photo of the dish (AI-03), text search, and voice.
**Reason:** There is no data source for restaurant menus today — Open Food Facts indexes packaged products, not restaurant dishes; menu data realistically arrives with the Ф3 delivery-platform integration (SPEC: «Список покупок (готов к доставке, Ф3)» implies the partner API). Building a fake restaurant picker over the same OFF search would add UI without new capability. Logged so the audit (docs/AUDIT.md) and BOARD reflect a conscious scope decision, not an omission.

## ADR-028: PurchaseService abstraction — stub now, RevenueCat later
**Date:** 2026-06-10
**Decision:** Subscriptions go through `app/lib/services/purchases/purchase_service.dart`: an abstract `PurchaseService` (`buyPremium()` / `restorePurchases()` → `PurchaseOutcome {success, cancelled, unavailable, error}`) behind `purchaseServiceProvider`. Today's implementation is `StubPurchaseService`: in debug builds `buyPremium` calls the existing dev-upgrade endpoint ([[ADR-018]]) so the single Subscribe button actually unlocks premium for testing (the separate "Dev: unlock premium" button is removed); in release it returns `unavailable` ("payments coming soon"). Real RevenueCat integration later = add `purchases_flutter`, implement `RevenueCatPurchaseService`, swap one line in the provider — UI untouched.
**Reason:** Real payments need store accounts and the RevenueCat SDK — not available yet — but the paywall UX (Subscribe / Restore / outcome handling) shouldn't be rebuilt twice. A seam identical in spirit to the AI provider seam ([[ADR-022]]) makes payments an implementation swap, not a refactor.

## ADR-027: Shopping list is local-only (no sync until Ф3)
**Date:** 2026-06-10
**Decision:** The shopping list (SPEC C5) lives only in the client Drift DB (`shopping_items`, schema v4): no Prisma model, no `/sync` participation. Cross-device sync and the delivery integration arrive together in Ф3.
**Reason:** SPEC marks delivery-readiness as Ф3; a grocery list is short-lived device-local state, so syncing it now adds contract surface (api-spec, tombstones for checked/deleted rows) with no user-visible win. When Ф3 lands, the append+LWW patterns from [[ADR-017]]/[[ADR-021]] apply directly.

## ADR-026: Wrapped AI summary is on-demand, not Sunday cron+Batch
**Date:** 2026-06-10
**Decision:** AI-05 ships as `POST /api/v1/ai/wrapped-summary` (premium): the **client computes all stats** (tasks/main done, avg mood, water, top setback — code, never the model) from its local Drift DB and sends them; the model only writes a <60-word tone-aware paragraph. The ai-tasks.md design (Sunday 20:00 cron + Anthropic Batch over all users, stored server-side) is deferred.
**Reason:** The app is offline-first — the client's local DB is the most complete source of the user's week, and the stats pipeline already exists on the client (rule-based wrapped). A cron+Batch pipeline needs job infrastructure, a WeekLog store and enough users to benefit from −50% Batch pricing; none exist yet. On-demand keeps one code path, zero infra, and the same cost order at current scale. Revisit Batch when wrapped generation becomes a scheduled push feature.

## ADR-025: Gemini default model bumped to gemini-2.5-flash-lite
**Date:** 2026-06-10
**Decision:** The Gemini-path default in `backend/src/ai/provider.ts` (and the `GEMINI_MODEL` value in `backend/.env`) changes from `gemini-2.0-flash-lite` to **`gemini-2.5-flash-lite`**.
**Reason:** Live verification with the user's new API key returned `429 quota exceeded` with limit 0 for `gemini-2.0-flash-lite` — the 2.0 line is retired for new keys — while `gemini-2.5-flash-lite`, `gemini-flash-lite-latest` and `gemini-2.5-flash` all answered 200 (probed directly). 2.5-flash-lite is the cheapest working tier, same role as before. All four AI endpoints were then verified live end-to-end (morning-message, redistribute 3 variants, diary-insight, schedule-import reading a generated timetable PNG). Builds on [[ADR-022]].

## ADR-024: Food logs sync append-only via /sync (like water)
**Date:** 2026-06-10
**Decision:** Food logs sync through the existing `POST /api/v1/sync` exactly like water logs (ADR-017): optional `SyncRequest.food_logs` + `SyncResponse.updated_food_logs`; the server creates-if-absent by client UUID (never updates an existing row) and returns rows with `createdAt > last_sync_at`. New Prisma model `FoodLog` mirrors the client Drift `food_logs` table (id, date @db.Date, meal, name, grams, nullable calories/protein/fat/carbs/sugar/fiber, createdAt); nutrition numbers are absolute per portion, precomputed by the client from the food DB. Local deletion of a food log is NOT propagated cross-device yet (no tombstones for food) — documented limitation, same as water.
**Reason:** Food logs were local-only (no backup/cross-device). They are effectively immutable single events (a logged portion), so the proven append-only contract from [[ADR-017]] applies unchanged — no `updatedAt`, no LWW, idempotent by client UUID, `createdAt` doubles as the delta marker. Reusing `/sync` keeps one sync path; the new fields are optional so the contract stays backward compatible. Deleting a log only affects the local day view; cross-device delete propagation can reuse the tombstone pattern ([[ADR-021]]) later if users notice.

## ADR-023: ANIMATIONS.md is the single source of truth for motion
**Date:** 2026-06-10
**Decision:** The animation spec the user supplied (`animations_tz.md`) is renamed to **`/docs/ANIMATIONS.md`** and declared the single source of truth for all motion: durations (snap 120 / fast 180 / normal 280 / slow 400 ms), curves, per-element behaviour, MVP/Ф1/Ф2 priority, and the accessibility rule (`MediaQuery.disableAnimations`). The `animation` block in `design-tokens.json` (previously fast 120 / normal 200 / slow 300) is updated to mirror ANIMATIONS.md section 0 with an explicit "if they differ, ANIMATIONS.md wins" note; `app/CLAUDE.md` and the flutter agent now point there. Existing hard-coded durations in Dart (200/300 ms) will be migrated to `core/animations/constants.dart` during the MVP animations block.
**Reason:** Two "sources of truth" contradicted each other (tokens said 120/200/300, the spec says 120/180/280/400) and nothing in the repo referenced the spec file at all. One law file kills the drift; tokens keep a mirrored copy only because the landing page reads tokens, not the Flutter spec.

## ADR-022: AI provider abstraction — Gemini or Anthropic by .env
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
