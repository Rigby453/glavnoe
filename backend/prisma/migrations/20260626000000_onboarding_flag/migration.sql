-- Серверный флаг завершения онбординга (синхронизация setup_done между устройствами/вебом).
-- Аддитивно и не ломает существующие строки (NOT NULL c DEFAULT false).
-- AlterTable
ALTER TABLE "User" ADD COLUMN "onboardingDone" BOOLEAN NOT NULL DEFAULT false;
