# Claude Code Rules — Kaizen

## Always read first
Before starting any task:
1. Read /CLAUDE.md — project overview, tech stack, principles
2. Read /AGENTS.md — who does what, build order, shared contracts
3. Read the relevant subdirectory CLAUDE.md (backend/CLAUDE.md, app/CLAUDE.md, etc.)

## Orchestration
- You are the orchestrator by default
- Spawn sub-agents (Task tool) for isolated work: backend / flutter / landing / qa
- Don't let two agents touch the same file simultaneously
- Sync points: after backend auth is done → start flutter API client

## Code rules
- Language: English for all code, variable names, file names, comments
- Never put secrets (API keys, JWT secret) in code — use process.env / .env only
- ANTHROPIC_API_KEY only in backend/.env, only used in backend/src/ai/
- No `any` type in TypeScript — use proper types or Zod schemas
- No unused imports or dead code

## File rules
- Shared contracts (/docs/*.yaml, /docs/*.json, /docs/*.md) — read, never rewrite unless instructed
- If you need to change a shared contract, ask first and log in /docs/decisions.md
- /docs/decisions.md — append ADR (Architecture Decision Record) when making a significant choice

## Build rules
- MVP first: no AI features, no RevenueCat, no OAuth — email/password only
- Do not implement Phase 1+ features during MVP work
- If blocked by a dependency, create a stub/mock and continue

## Error handling
- Backend: always return proper HTTP codes (see backend/CLAUDE.md)
- Flutter: always catch Dio errors, show user-friendly messages
- Never silently swallow exceptions — log them

## Testing
- New backend route = at least one integration test in tests/
- Rule engine logic = unit tests (tests/unit/engine.test.ts)
- Mock backend/src/ai/ in all tests — no real API calls
