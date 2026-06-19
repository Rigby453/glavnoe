-- ADR-041: серверный entitlement — поля подписки с истечением и источником оплаты.
-- Оба поля nullable и аддитивны — существующие строки не ломаются.
-- premiumSource: apple|google|rustore|stripe|yookassa|dev

-- AlterTable
ALTER TABLE "User" ADD COLUMN "premiumUntil" TIMESTAMP(3);
ALTER TABLE "User" ADD COLUMN "premiumSource" TEXT;
