-- ADR-044: серверная синхронизация заморозок стрика через /sync, LWW по lastFreezeAccrualAt.
-- Поле nullable и аддитивно — существующие строки не ломаются.

-- AlterTable
ALTER TABLE "Streak" ADD COLUMN "lastFreezeAccrualAt" TIMESTAMP(3);
