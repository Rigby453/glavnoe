# Kaizen — Agent Orchestration

## What you are
You are the **orchestrator**. Read this file + /CLAUDE.md before every session.
Spawn sub-agents via the Task tool when work is isolated to one area.
Coordinate their output. Never let agents step on each other's files.

## When to spawn sub-agents

| Task type | Agent to spawn | Reads |
|-----------|---------------|-------|
| Backend API / DB / rule engine | backend agent | backend/CLAUDE.md |
| Flutter screens / themes / sync | flutter agent | app/CLAUDE.md |
| Landing page | landing agent | landing/CLAUDE.md |
| Tests | QA agent | tests/CLAUDE.md |
| AI prompts / Claude API | AI agent | docs/agents/ai-tasks.md |

> These roles are now **registered sub-agents** in `.claude/agents/` — spawn them by name:
> `backend`, `flutter`, `ai`, `qa`, `landing`. Each already knows what to read and what it owns.

## Agents

### Backend Agent
**Works in:** `backend/`
**Reads first:** /CLAUDE.md · /backend/CLAUDE.md · /docs/api-spec.yaml · /docs/data-model.md
**Stack:** Node.js 22 · Fastify · Prisma · TypeScript · PostgreSQL
**Owns:** REST API · DB migrations · rule engine · AI proxy endpoints · JWT auth · sync

### Flutter Agent
**Works in:** `app/`
**Reads first:** /CLAUDE.md · /app/CLAUDE.md · /docs/design-tokens.json · /docs/api-spec.yaml
**Stack:** Flutter 3 · Riverpod · Drift (SQLite) · go_router · Dio
**Owns:** all screens · 5 themes · animations · offline-first storage · local notifications · home widget

### AI Agent
**Works in:** `backend/src/ai/`
**Reads first:** /CLAUDE.md · /docs/agents/ai-tasks.md
**Stack:** provider abstraction `src/ai/provider.ts` (ADR-022): Gemini (default, GEMINI_API_KEY) or Claude API (claude-haiku-4-5 bulk · claude-sonnet-4-6 complex · prompt caching · Batch)
**Owns:** redistribution prompts · AI endpoints · tone-aware copy · food vision

### QA Agent
**Works in:** `tests/`
**Reads first:** /CLAUDE.md · /tests/CLAUDE.md · /docs/agents/qa-tasks.md
**Stack:** Jest + Supertest (backend) · flutter_test (app)
**Owns:** integration tests · unit tests · sync conflict scenarios

### Landing Agent
**Works in:** `landing/`
**Reads first:** /CLAUDE.md · /landing/CLAUDE.md · /docs/design-tokens.json
**Stack:** HTML · Tailwind CDN · Alpine.js — **no build step**
**Owns:** index.html · smart Download button · pricing section

---

## Build order — MVP

```
1. [backend] Project setup + Prisma schema + migrations
2. [backend] Auth endpoints (register / login / me)
3. [backend] Items CRUD + Streaks + Sync endpoint
4. [flutter] Project setup + Focus theme + 4-tab navigation
5. [flutter] Drift local DB + Today screen + FAB add task
6. [backend] Rule redistribution engine (pending → proposed plan)
7. [flutter] Plan screen + Diary screen + morning review UI
8. [flutter] API client + Sync service
9. [qa]     Integration tests: auth, items, streaks, sync, engine
10. [landing] index.html with smart Download button
```

---

## Shared contracts — single source of truth

| Contract | File |
|----------|------|
| API endpoints | /docs/api-spec.yaml |
| DB schema | /docs/data-model.md |
| Colors / fonts / spacing | /docs/design-tokens.json |
| Architecture decisions | /docs/decisions.md |

**Never duplicate these in agent files — always reference the originals.**

---

## Rules for ALL agents

- `ANTHROPIC_API_KEY` / `GEMINI_API_KEY` live in `.env` only — **never** in Flutter/client code
- The AI provider (Claude or Gemini, ADR-022) is called **only** from `backend/src/ai/` — never from routes or client
- All API responses must match schemas in `/docs/api-spec.yaml` exactly
- All DB columns must match `/docs/data-model.md` exactly
- Code and variable names in **English**; comments can be Russian
- Log architectural decisions in `/docs/decisions.md` (ADR format)
- Before touching shared contracts, ask orchestrator first
