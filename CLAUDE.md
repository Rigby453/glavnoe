# Kaizen — Project Overview

> This file is auto-loaded into every Claude Code session. It is the entry point.
> Orchestration (who does what, build order) lives in **/AGENTS.md** — read it next.

---

## What we're building

**Kaizen** ("the important stuff won't slip") — a planner for students that
re-assembles the day around what matters and helps users understand *why* plans fail.

> Naming: the product is **«Главное»** (RU working title, see /docs/SPEC.md); **Kaizen** is the
> codename used in code, packages (com.kaizen) and repo docs. Same product — don't rename code.

- **Hook:** auto-carry-over of unfinished tasks + priority-based redistribution **with user
  confirmation**. Rule-based (free) → AI-smarter (paid).
- **Audience:** students and young adults. Commercial product.
- **Language:** ships in **English first** (all copy in EN); other languages later.
- **Platform:** **Flutter** — iOS, Android, **Web** — plus a **landing site** with a smart
  `[Download]` button.
- **Monetization:** subscription **$10/mo** (funds AI). Ads only on the free tier, never on paid.
  AI is **never** funded by ads — AI is a paid-only feature.
- **AI:** backend-only, via the provider abstraction `backend/src/ai/provider.ts` (ADR-022):
  **Gemini** if `GEMINI_API_KEY` is set (current default), else **Claude API**
  (`claude-haiku-4-5` for bulk/fast, `claude-sonnet-4-6` for complex reasoning; prompt caching +
  Batch to cut cost). Provider swap = `.env` change only. Nutrition numbers come from the
  food DB, never from the model.

Full product spec: **/docs/SPEC.md**.

---

## Read order (every session)

1. **/CLAUDE.md** (this file) — overview + global rules
2. **/AGENTS.md** — orchestration: roles, when to spawn sub-agents, MVP build order
3. The relevant subdir guide: `backend/CLAUDE.md` · `app/CLAUDE.md` · `landing/CLAUDE.md` · `tests/CLAUDE.md`
4. Per-role task list in `/docs/agents/` (`backend-tasks.md`, `flutter-tasks.md`, `ai-tasks.md`, `qa-tasks.md`)

## Single source of truth (never duplicate — reference these)

| Contract | File |
|----------|------|
| Product spec | `/docs/SPEC.md` |
| API endpoints (OpenAPI 3.0) | `/docs/api-spec.yaml` |
| DB schema (+ Prisma) | `/docs/data-model.md` |
| Colors / fonts / spacing | `/docs/design-tokens.json` |
| Animations (durations / curves / per-element spec) | `/docs/ANIMATIONS.md` |
| Architecture decisions (ADR) | `/docs/decisions.md` |
| MVP status board | `/docs/BOARD.md` |

---

## Phases (Definition of Done per phase)

1. **MVP (free, no AI):** design system + data model → accounts/sync → Today/Plan/Diary →
   rule-based review (morning + evening + variants) → schedule import → streaks/freeze →
   onboarding → themes Focus/Black/White → home widget.
2. **Phase 1 (paid):** food DB + Food module (KБЖУ/sugar/fiber, barcode/photo/recipe/restaurant,
   AI menu build) + Water + shopping list + wrapped + subscription/paywall + AI add-ons.
3. **Phase 2:** Workouts + posture + breathing + Sleep + Health integrations + Contrast theme +
   focus sessions (incl. 67/15).
4. **Phase 3:** web share link + "shared with me"/copy + co-study + delivery integration.

---

## Global rules (apply to ALL agents)

- `ANTHROPIC_API_KEY` / `GEMINI_API_KEY` / `JWT_SECRET` / `DATABASE_URL` live in `.env` **only** — never in code, never in the Flutter client.
- The AI provider (Claude or Gemini, ADR-022) is called **only** from `backend/src/ai/` — never from routes, the engine, or the client.
- All API responses must match `/docs/api-spec.yaml` exactly. API payloads use **snake_case**.
- All DB columns must match `/docs/data-model.md` exactly.
- Code, file names, and variable names in **English**; comments may be Russian.
- **MVP first:** no AI, no OAuth, no payments — email/password only. Don't build Phase 1+ during MVP.
- If blocked by a missing dependency, create a stub/mock and continue — don't stall.
- Log significant architectural choices in `/docs/decisions.md` (ADR format).
- Before changing a shared contract (api-spec / data-model / design-tokens), ask the orchestrator first.

Detailed working rules: @.claude/rules/rules.md
