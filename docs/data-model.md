# Kaizen — Data Model

## Users
| Column            | Type     | Notes                                   |
|-------------------|----------|-----------------------------------------|
| id                | uuid PK  | auto-generated                          |
| email             | string   | unique                                  |
| password_hash     | string   | bcrypt                                  |
| name              | string   |                                         |
| subscription_tier | enum     | free / premium                          |
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

## Tombstones
| Column     | Type     | Notes                                   |
|------------|----------|------------------------------------------|
| id         | uuid PK  |                                          |
| user_id    | uuid FK  | -> users.id                              |
| item_id    | uuid     | удалённый Item (ADR-021, delete sync)    |
| deleted_at | timestamp| unique (user_id, item_id)                |

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
  email            String     @unique
  passwordHash     String
  name             String
  subscriptionTier String     @default("free")
  theme            String     @default("focus")
  tonePreference   String     @default("gentle")
  createdAt        DateTime   @default(now())
  updatedAt        DateTime   @updatedAt
  items            Item[]
  streak           Streak?
  dayLogs          DayLog[]
  waterLogs        WaterLog[]
  tombstones       Tombstone[]
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
model Tombstone {
  id        String   @id @default(uuid())
  userId    String
  user      User     @relation(fields: [userId], references: [id])
  itemId    String
  deletedAt DateTime @default(now())
  @@unique([userId, itemId])
  @@index([userId, deletedAt])
}
```
