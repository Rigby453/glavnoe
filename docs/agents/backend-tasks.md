# Backend Tasks — MVP

> Each task is a single focused unit of work. Complete in order.
> Reference: /docs/api-spec.yaml + /docs/data-model.md

---

## SETUP

### SETUP-01: Project scaffolding
```bash
mkdir -p src/{ai,engine,models,routes}
npm init -y
npm install fastify @fastify/jwt @fastify/cors @prisma/client bcrypt zod dotenv
npm install -D typescript ts-node-dev @types/node @types/bcrypt prisma
npx tsc --init
```
`tsconfig.json`: target ES2022, moduleResolution bundler, strict true.
`package.json` scripts: `"dev": "ts-node-dev src/index.ts"`, `"build": "tsc"`.

### SETUP-02: Prisma schema + migration
Copy Prisma schema from `/docs/data-model.md` → `prisma/schema.prisma`.
```bash
npx prisma migrate dev --name init
npx prisma generate
```
Verify all tables created in psql.

### SETUP-03: Fastify server
`src/index.ts`:
- Register `@fastify/cors` (allow localhost:* in dev)
- Register `@fastify/jwt` with `JWT_SECRET` from env
- Health check: `GET /health → { status: "ok" }`
- Start on `PORT` from env (default 3000)

---

## AUTH

### AUTH-01: Register
`POST /api/v1/auth/register`
- Zod schema: `{ email: z.string().email(), password: z.string().min(8), name: z.string() }`
- Check for existing email → 409 `{ error: "Email already exists" }`
- `bcrypt.hash(password, 12)`
- Insert User, create empty Streak row
- Sign JWT: `{ userId, email }`, expiry 30d
- Return 201 `AuthResponse` (see api-spec.yaml)

### AUTH-02: Login
`POST /api/v1/auth/login`
- Find user by email → 401 if not found
- `bcrypt.compare` → 401 if mismatch
- Sign JWT, return 200 `AuthResponse`

### AUTH-03: JWT middleware
`src/routes/middleware/auth.ts`
- `fastify.addHook('preHandler', verifyJWT)` on protected routes
- Decode token, attach `req.user = { userId, email }`
- Return 401 if token missing/invalid

### AUTH-04: Get current user
`GET /api/v1/auth/me`
- Protected route
- Return User object (exclude `passwordHash`)

---

## ITEMS

### ITEMS-01: Create item
`POST /api/v1/items`
- Protected
- Zod: `{ title, type, scheduled_at, duration_minutes?, is_protected?, priority? }`
- If `priority === 'main'` → force `is_protected = true`
- Insert Item with `userId = req.user.userId`
- Return 201 Item

### ITEMS-02: Get items
`GET /api/v1/items?from=&to=`
- Protected
- Filter: `userId = req.user.userId AND scheduledAt >= from AND scheduledAt <= to`
- Return array of Items (empty array if none)

### ITEMS-03: Update item
`PATCH /api/v1/items/:id`
- Protected
- Fetch item → 404 if not found
- Verify `item.userId === req.user.userId` → **404** if not (not 403 — see ADR-014; api-spec.yaml wins)
- Partial update: only fields present in body
- Return updated Item

### ITEMS-04: Delete item
`DELETE /api/v1/items/:id`
- Protected, ownership check
- Return 204 (no body)

---

## STREAKS

### STREAK-01: Get streak
`GET /api/v1/streaks`
- Protected
- Find Streak where `userId = req.user.userId`
- If not found → create with defaults (current=0, longest=0)
- Return Streak

### STREAK-02: Update streak (internal helper)
`src/engine/streaks.ts` — called internally, not an API endpoint:
```
async function checkAndUpdateStreak(userId: string, date: Date)
  1. Fetch all items where userId, priority=main, scheduledAt = date
  2. If none → return (no main tasks today = no streak change)
  3. If all done → proceed; else → return
  4. Fetch or create Streak
  5. yesterday = date - 1 day
  6. if lastCompletedDate = yesterday → current += 1
  7. elif freeze_count > 0 → freeze_count -= 1 (streak preserved)
  8. else → current = 1
  9. if current > longest → longest = current
  10. lastCompletedDate = date
  11. Save streak
```
Call this from ITEMS-03 whenever `status` changes to `done`.

---

## SYNC

### SYNC-01: Sync endpoint
`POST /api/v1/sync`
- Protected
- Body: `{ items: Item[], last_sync_at: string (ISO) }`
- For each incoming item:
  - If not exists on server → create
  - If exists: compare `updatedAt` → keep newer version
- Return `{ updated_items: Item[] }` (server-side changes client doesn't have)

---

## ENGINE

### ENGINE-01: Rule redistribution
`src/engine/redistributor.ts`
```
async function proposeRedistribution(userId: string, targetDate: Date):
  Promise<{ proposed: Item[], skipped: Item[] }>

1. pendingItems = fetch Items where userId, status=pending, scheduledAt < targetDate
2. sort pendingItems by priority weight: main=4, high=3, medium=2, low=1
3. todayItems = fetch Items where userId, scheduledAt >= startOfDay(targetDate)
4. occupiedSlots = todayItems.map(i => i.scheduledAt)
5. freeSlots = generateSlots(targetDate, 30min) - occupiedSlots
6. proposed = []
7. skipped = []
8. for item of pendingItems:
     if item.isProtected: skipped.push(item); continue
     if freeSlots.length > 0:
       slot = freeSlots.shift()
       proposed.push({ ...item, scheduledAt: slot })
     else:
       skipped.push(item)
9. return { proposed, skipped }
```
This returns proposals. The `/api/v1/items PATCH` endpoint applies them (user must confirm first).
