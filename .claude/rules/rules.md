# Claude Code Rules — Kaizen (v2)

## Always read first
Before starting any task:
1. Read /CLAUDE.md — project overview, tech stack, principles
2. Read /AGENTS.md — who does what, build order, shared contracts
3. Read the relevant subdirectory CLAUDE.md (backend/CLAUDE.md, app/CLAUDE.md, etc.)

## Orchestration Rules
- **No Coding**: The orchestrator (you) must never write application code. Your job is to spawn specialized agents, review their work, and manage the process.
- **Verification First**: Never trust an agent's report. Always run `git status`, read the modified files, and execute tests/lints before committing.
- **Atomic Tasks**: One task = one atomic block (one feature + its unit test). Max 30 mins of real work. If a task is too big, split it.
- **Parallelism**: 
  - File-writing agents can run in parallel if they touch different directories.
  - **Never** run agents that execute `flutter build`, `flutter test`, or `jest` simultaneously (resource contention).
- **Context**: Always provide agents with the relevant `CLAUDE.md` from their subdirectory.

## Git & Workflow
- **Commit Format**: `feat(scope):`, `fix(scope):`, `docs:`, `refactor(scope):`.
- **Push Policy**: Push to `origin main` after every verified task. Standing authorization — commit AND push every block without asking.
- **Secrets**: Never commit `.env` or files containing keys. Use `git status` to check for accidental additions.

## Code & Quality Standards
- **Language**: English for all code, variable names, file names. Comments can be Russian.
- **Secrets**: Never put secrets (API keys, JWT secret) in code — use process.env / .env only.
- **Lints**: `flutter analyze` must return 0 errors.
- **Tests**: All existing tests must pass. New features must include unit tests. Mock AI calls in all tests.
- **Architecture**: Follow ADRs in `/docs/decisions.md`. Log new decisions immediately.

## File Rules
- Shared contracts (/docs/*.yaml, /docs/*.json, /docs/*.md) — read, never rewrite unless instructed.
- If you need to change a shared contract, ask first and log in /docs/decisions.md.

## Agent reliability & test-run hygiene
Subagents sometimes **drop their connection mid-response** ("API Error: Connection closed") or get stopped — they usually still did real work but lose their final report. Handle it, don't trust the report:
- **Verify from disk, not from the agent's word**: after any agent finishes/dies, run `git status --short`, confirm the expected new files exist, run `flutter analyze` on changed files. Agents typically leave a *compilable, partial* result.
- **Finish with a continuation agent**: tell it exactly what's already done ("PART X done, do the rest") + the public API of the existing code, so it builds on top instead of redoing.
- **Kill orphaned test processes — they contend and cause minute-long stalls/timeouts.** Dead/stopped agents leave stray `dart` / `flutter_tester` / `node` (jest) processes that compete with the next run (project bans parallel `flutter test`/`jest`). Before every verification run and after any agent dies, run `scripts/cleanup-test-procs.ps1` (`-IncludeNode` only when no backend `npm run dev` is up — it would kill that too).
- **Run long commands in the background** (`flutter test`, `flutter analyze`, `build_runner`, `npm test`) so the UI/token counter doesn't appear frozen and the user can interrupt; never run two test-runners at once. Foreground only for <~5s checks.
- **Isolate hangs fast**: an unverified new test file can hang (e.g. awaiting a Drift stream `.first` or `pumpAndSettle` without `tester.runAsync`, which deadlocks under the fake test clock). Don't wait out a 6-min timeout — run the new/suspect test file ALONE with a short timeout, find the hang, fix the test (wrap seeding in `tester.runAsync`), re-run.
- A flat token counter during a run is normal — the model is idle waiting for the command (a full `flutter test` ~1-2 min, backend `npm test` ~4 min). Stuck ≠ slow: confirm liveness by checking the `flutter_tester` process is accumulating CPU/holding RAM.
