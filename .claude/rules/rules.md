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

## Subagent lessons (выстрадано сессиями 2026-06-10..12 — соблюдать!)
- Субагенты ОБРЫВАЮТСЯ и ЗАВИСАЮТ на длинных задачах (~5 из 15 за двое суток):
  финальный отчёт может быть оборван на полуслове, файлы — недописаны.
  Поэтому: задача агенту = ОДИН компактный блок (таблица+DAO+экран+тесты максимум),
  строго пронумерованные пункты, явные списки «НЕ трогай».
- После КАЖДОГО агента оркестратор проверяет работу ПО ДИСКУ (git status + чтение
  ключевых файлов), сам гоняет analyze/тесты и сам коммитит. Отчёту агента не верить
  на слово — он может описывать несделанное или устаревшее.
- Двум параллельным агентам нельзя одновременно гонять flutter/jest (конфликт
  build-кэшей): либо запрети им запускать проверки («проверит оркестратор»),
  либо запускай последовательно.
- Хвосты упавшего агента доделывает оркестратор сразу — не перезапускать агента
  на ту же задачу (дороже и рискованнее).
- Лимит сессий агентов может закончиться (видно по мгновенному failed) — тогда
  оркестратор делает блок сам, инлайн.

## Git / GitHub
- After finishing and verifying a block of work: `git commit` to `main`, then
  `git push origin main`. Remote = https://github.com/Rigby453/glavnoe (private).
  Standing authorization — commit AND push every block without asking (added 2026-06-13).
- One logical task = one commit. Conventional messages: `feat(app):`, `fix(...)`, `docs:`.
- If a push fails (auth/offline/conflict), tell the user once, keep working locally,
  don't loop on retries.
- NEVER commit secrets — `backend/.env` stays gitignored.

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
