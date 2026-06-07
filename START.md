# How to start the build (orchestrator)

The "orchestra" is a Claude Code chat opened **inside this folder** (`kaizen`).
Start a new chat and paste the prompt below.

## Starter prompt — copy/paste

```
Ты — оркестратор проекта Kaizen. Прочитай CLAUDE.md и AGENTS.md.
Работаем по MVP build order из AGENTS.md. Начни с шага 1 (backend:
setup + Prisma schema + миграции). Для изолированных частей запускай
именованных субагентов: backend, flutter, ai, qa, landing. Двум агентам
не давай править один и тот же файл. После каждого шага обновляй
docs/BOARD.md и давай короткий отчёт, затем продолжай со следующего шага.
Если упрёшься в недостающую зависимость — сделай заглушку и продолжай.
```

## Prerequisites
- Node.js + npm — installed ✓
- Flutter + Dart — installed ✓
- PostgreSQL — needed for backend DB migrations (step 2). Options:
  - free cloud DB (Neon / Supabase) → put its connection string in `backend/.env` as `DATABASE_URL`
  - or install PostgreSQL locally / via Docker
- `ANTHROPIC_API_KEY` — only for AI features (Phase 1); MVP runs without it.
- `JWT_SECRET` — already generated in `backend/.env`.
