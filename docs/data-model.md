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
| created_at       | timestamp|                                       |
| updated_at       | timestamp|                                       |

## Streaks
| Column              | Type     | Notes          |
|---------------------|----------|----------------|
| id                  | uuid PK  |                |
| user_id             | uuid FK  | -> users.id    |
| current             | integer  | default 0      |
| longest             | integer  | default 0      |
| last_completed_date | date     | nullable       |
| freeze_count        | integer  | default 0      |

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

## Prisma schema

```prisma
generator client {
  provider = "prisma-client-js"
}
datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
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
  createdAt       DateTime @default(now())
  updatedAt       DateTime @updatedAt
}
model Streak {
  id                String    @id @default(uuid())
  userId            String    @unique
  user              User      @relation(fields: [userId], references: [id])
  current           Int       @default(0)
  longest           Int       @default(0)
  lastCompletedDate DateTime?
  freezeCount       Int       @default(0)
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
```
