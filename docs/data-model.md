# Kaizen — Data Model

## Users
| Column            | Type     | Notes                                   |
|-------------------|----------|-----------------------------------------|
| id                | uuid PK  | auto-generated                          |
| email             | string   | unique, **nullable** (email OR phone required) |
| phone             | string   | unique, **nullable**; Russian E.164 `+7XXXXXXXXXX` (RF law 406-FZ) |
| password_hash     | string   | bcrypt                                  |
| name              | string   |                                         |
| subscription_tier | enum     | free / premium                          |
| premium_until     | timestamp| **nullable** (ADR-041); срочная подписка — active if > now |
| premium_source    | string   | **nullable** (ADR-041); apple\|google\|rustore\|stripe\|yookassa\|dev |
| theme             | enum     | focus / calm / black / white / contrast |
| tone_preference   | enum     | gentle / harsh                          |
| created_at        | timestamp|                                         |
| updated_at        | timestamp|                                         |

## Items
| Column           | Type     | Notes                                 |
|------------------|----------|---------------------------------------|
| id               | uuid PK  |                                       |
| user_id          | uuid FK  | -> users.id                           |
| title            | string   |                                       |
| type             | enum     | task / event / exam / deadline        |
| priority         | enum     | low / medium / high / main            |
| status           | enum     | pending / done / skipped              |
| scheduled_at     | timestamp|                                       |
| duration_minutes | integer  | default 30                            |
| is_protected     | boolean  | защищён от переноса                   |
| recurrence_rule  | string   | iCal RRULE, nullable                  |
| reminder_minutes_before | integer | nullable; за сколько минут до scheduled_at уведомить (null/0 = нет; макс. 10080 = неделя) |
| created_at       | timestamp|                                       |
| updated_at       | timestamp|                                       |

## Subtasks
Подзадача (чеклист внутри задачи). Каскадно удаляется вместе с `Item`. В API отдаётся/принимается вложенным массивом snake_case (`{ id, title, done, sort_order }`) на `Item` и через `/sync` (LWW на наборе).
| Column     | Type     | Notes                                          |
|------------|----------|------------------------------------------------|
| id         | uuid PK  |                                                |
| item_id    | uuid FK  | -> items.id, **onDelete: Cascade**; index (item_id) |
| title      | string   |                                                |
| done       | boolean  | default false                                  |
| sort_order | integer  | default 0                                      |
| created_at | timestamp|                                                |
| updated_at | timestamp|                                                |

## Streaks
| Column                  | Type      | Notes                                      |
|-------------------------|-----------|---------------------------------------------|
| id                      | uuid PK   |                                             |
| user_id                 | uuid FK   | -> users.id                                 |
| current                 | integer   | default 0                                   |
| longest                 | integer   | default 0                                   |
| last_completed_date     | date      | nullable                                    |
| freeze_count            | integer   | default 0                                   |
| last_freeze_accrual_at  | timestamp | nullable; LWW cursor for freeze sync (ADR-044) |

## DayLogs
| Column     | Type     | Notes          |
|------------|----------|----------------|
| id         | uuid PK  |                |
| user_id    | uuid FK  | -> users.id    |
| date       | date     |                |
| mood       | integer  | 1-5, nullable  |
| note       | text     | nullable       |
| insight    | text     | AI, nullable   |
| created_at | timestamp|                |
| updated_at | timestamp| LWW sync       |

## WaterLogs
| Column     | Type     | Notes       |
|------------|----------|-------------|
| id         | uuid PK  |             |
| user_id    | uuid FK  | -> users.id |
| amount_ml  | integer  |             |
| logged_at  | timestamp|             |

## FoodLogs
| Column     | Type     | Notes                                          |
|------------|----------|------------------------------------------------|
| id         | uuid PK  | клиентский UUID (идемпотентность синка)        |
| user_id    | uuid FK  | -> users.id                                    |
| date       | date     | день (UTC-полночь)                             |
| meal       | string   | breakfast / lunch / dinner / snack             |
| name       | string   | название блюда/продукта                        |
| grams      | float    | default 100                                    |
| calories   | float    | nullable; абсолют на порцию (из food DB)       |
| protein    | float    | nullable                                       |
| fat        | float    | nullable                                       |
| carbs      | float    | nullable                                       |
| sugar      | float    | nullable                                       |
| fiber      | float    | nullable                                       |
| created_at | timestamp| маркер «changed since» (append-only, ADR-024)  |

## Tombstones
| Column     | Type     | Notes                                   |
|------------|----------|------------------------------------------|
| id         | uuid PK  |                                          |
| user_id    | uuid FK  | -> users.id                              |
| item_id    | uuid     | удалённый Item (ADR-021, delete sync)    |
| deleted_at | timestamp| unique (user_id, item_id)                |

## AiUsage
Учёт расхода платных AI-фич (дневные лимиты), устойчивый к рестарту процесса и мультиинстансу (ADR-034). Заменяет in-memory `Map` в `routes/ai.ts`.
| Column   | Type     | Notes                                       |
|----------|----------|----------------------------------------------|
| id       | uuid PK  |                                              |
| user_id  | uuid FK  | -> users.id                                  |
| day      | string   | `YYYY-MM-DD` (UTC-день)                       |
| feature  | string   | напр. `food_photo`                           |
| count    | integer  | default 0; unique (user_id, day, feature)    |

## PasswordResetCode
Код восстановления пароля, устойчивый к рестарту/мультиинстансу (ADR-047). Хранится **только** SHA-256-хэш кода (не сам код). TTL 15 мин + одноразовость.
| Column     | Type     | Notes                                          |
|------------|----------|------------------------------------------------|
| id         | uuid PK  |                                                |
| user_id    | uuid FK  | -> users.id, **onDelete: Cascade**; index (user_id) |
| code_hash  | string   | SHA-256 от 6-значного кода                      |
| expires_at | timestamp| now + 15 мин; index (expires_at)               |
| used_at    | timestamp| nullable; null = не использован (одноразовость) |
| created_at | timestamp|                                                |

## StudyGroup
Настоящая учебная группа (Ф3, ADR-049). Объединяет нескольких пользователей; вступление по короткому коду с модерацией владельцем.
| Column     | Type     | Notes                                          |
|------------|----------|------------------------------------------------|
| id         | uuid PK  | таблица `study_groups`                          |
| owner_id   | uuid FK  | -> users.id, **onDelete: Cascade** (выход владельца удаляет группу) |
| name       | string   |                                                |
| code       | string   | **unique**; короткий код (первые 8 символов uuid) |
| created_at | timestamp|                                                |

## StudyGroupMember
Членство пользователя в `StudyGroup` (Ф3, ADR-049).
| Column    | Type     | Notes                                          |
|-----------|----------|------------------------------------------------|
| id        | uuid PK  | таблица `study_group_members`                   |
| group_id  | uuid FK  | -> study_groups.id, **onDelete: Cascade**       |
| user_id   | uuid FK  | -> users.id, **onDelete: Cascade**              |
| role      | string   | default `member`; `owner` \| `member`           |
| status    | string   | default `pending`; `pending` \| `accepted`      |
| joined_at | timestamp|                                                |
| | | unique (group_id, user_id)                     |

## Prisma schema

> ⚠️ Этот встроенный prisma-блок — **выжимка** и местами расходится с актуальной
> `backend/prisma/schema.prisma` (источник истины). Здесь обновлены `datasource`
> (Neon pooling) и добавлены новые модели (`Subtask`, `PasswordResetCode`,
> `StudyGroup`, `StudyGroupMember`) и поля (`Item.reminderMinutesBefore`,
> `Streak.lastFreezeAccrualAt`, `User.premiumUntil/premiumSource`). Полный набор
> моделей (`Friend`, `CoStudySession`, relation-поля `User`) см. в `schema.prisma`.

```prisma
generator client {
  provider = "prisma-client-js"
}
datasource db {
  provider  = "postgresql"
  // Pooled-строка Neon (хост с -pooler, ?pgbouncer=true&connection_limit=...) —
  // используется в рантайме (ADR-050).
  url       = env("DATABASE_URL")
  // Прямая строка Neon (без -pooler) — Prisma берёт её только для миграций.
  directUrl = env("DIRECT_URL")
}
model User {
  id               String     @id @default(uuid())
  email            String?    @unique
  phone            String?    @unique
  passwordHash     String
  name             String
  subscriptionTier String     @default("free")
  premiumUntil     DateTime?  // ADR-041: nullable, срочная подписка
  premiumSource    String?    // ADR-041: apple|google|rustore|stripe|yookassa|dev
  theme            String     @default("focus")
  tonePreference   String     @default("gentle")
  createdAt        DateTime   @default(now())
  updatedAt        DateTime   @updatedAt
  items            Item[]
  streak           Streak?
  dayLogs          DayLog[]
  waterLogs        WaterLog[]
  foodLogs         FoodLog[]
  tombstones       Tombstone[]
  aiUsages         AiUsage[]
  // ↓ relation-поля Friend/CoStudySession опущены — см. schema.prisma
  ownedGroups        StudyGroup[]        @relation("GroupOwner")
  groupMemberships   StudyGroupMember[]
  passwordResetCodes PasswordResetCode[]
}
model Item {
  id              String   @id @default(uuid())
  userId          String
  user            User     @relation(fields: [userId], references: [id])
  title           String
  type            String
  priority        String   @default("medium")
  status          String   @default("pending")
  scheduledAt     DateTime
  durationMinutes Int      @default(30)
  isProtected     Boolean  @default(false)
  recurrenceRule  String?
  reminderMinutesBefore Int?  // за сколько минут до scheduledAt уведомить (null/0 = нет)
  createdAt       DateTime @default(now())
  updatedAt       DateTime @updatedAt
  subtasks        Subtask[]
}
// Подзадача (чеклист). Каскадно удаляется с Item; в API/sync — вложенный snake_case массив.
model Subtask {
  id        String   @id @default(uuid())
  itemId    String
  item      Item     @relation(fields: [itemId], references: [id], onDelete: Cascade)
  title     String
  done      Boolean  @default(false)
  sortOrder Int      @default(0)
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
  @@index([itemId])
}
model Streak {
  id                  String    @id @default(uuid())
  userId              String    @unique
  user                User      @relation(fields: [userId], references: [id])
  current             Int       @default(0)
  longest             Int       @default(0)
  lastCompletedDate   DateTime?
  freezeCount         Int       @default(0)
  lastFreezeAccrualAt DateTime? // LWW-курсор начисления заморозок (ADR-044)
}
model DayLog {
  id        String   @id @default(uuid())
  userId    String
  user      User     @relation(fields: [userId], references: [id])
  date      DateTime @db.Date
  mood      Int?
  note      String?
  insight   String?
  createdAt DateTime @default(now())
  updatedAt DateTime @default(now()) @updatedAt
  @@unique([userId, date])
}
model WaterLog {
  id       String   @id @default(uuid())
  userId   String
  user     User     @relation(fields: [userId], references: [id])
  amountMl Int
  loggedAt DateTime @default(now())
}
model FoodLog {
  id        String   @id @default(uuid())
  userId    String
  user      User     @relation(fields: [userId], references: [id])
  date      DateTime @db.Date
  meal      String   @default("snack")
  name      String
  grams     Float    @default(100)
  calories  Float?
  protein   Float?
  fat       Float?
  carbs     Float?
  sugar     Float?
  fiber     Float?
  createdAt DateTime @default(now())
  @@index([userId, date])
  @@index([userId, createdAt])
}
model Tombstone {
  id        String   @id @default(uuid())
  userId    String
  user      User     @relation(fields: [userId], references: [id])
  itemId    String
  deletedAt DateTime @default(now())
  @@unique([userId, itemId])
  @@index([userId, deletedAt])
}
model AiUsage {
  id        String   @id @default(uuid())
  userId    String
  user      User     @relation(fields: [userId], references: [id])
  day       String
  feature   String
  count     Int      @default(0)
  @@unique([userId, day, feature])
  @@index([userId, day])
}
// Код восстановления пароля (ADR-047). Храним только SHA-256-хэш, TTL + одноразовость.
model PasswordResetCode {
  id        String    @id @default(uuid())
  userId    String
  user      User      @relation(fields: [userId], references: [id], onDelete: Cascade)
  codeHash  String
  expiresAt DateTime
  usedAt    DateTime?
  createdAt DateTime  @default(now())
  @@index([userId])
  @@index([expiresAt])
}
// Учебная группа (Ф3, ADR-049). Вступление по коду с модерацией владельцем.
model StudyGroup {
  id        String             @id @default(uuid())
  ownerId   String
  name      String
  code      String             @unique
  createdAt DateTime           @default(now())
  owner     User               @relation("GroupOwner", fields: [ownerId], references: [id], onDelete: Cascade)
  members   StudyGroupMember[]
  @@map("study_groups")
}
model StudyGroupMember {
  id       String     @id @default(uuid())
  groupId  String
  userId   String
  role     String     @default("member") // owner | member
  status   String     @default("pending") // pending | accepted
  joinedAt DateTime   @default(now())
  group    StudyGroup @relation(fields: [groupId], references: [id], onDelete: Cascade)
  user     User       @relation(fields: [userId], references: [id], onDelete: Cascade)
  @@unique([groupId, userId])
  @@map("study_group_members")
}
```
