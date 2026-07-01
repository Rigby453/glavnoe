-- ADR-062: профиль (антропометрия + цели питания/воды) синкается на сервер —
-- раньше жил только в SharedPreferences на устройстве (телефон и веб показывали
-- разные значения). Все новые колонки nullable либо с дефолтом — аддитивно,
-- не ломает существующие строки.
-- AlterTable
ALTER TABLE "User" ADD COLUMN     "activityLevel" TEXT,
ADD COLUMN     "ageYears" INTEGER,
ADD COLUMN     "calorieGoal" INTEGER,
ADD COLUMN     "foodGoal" TEXT,
ADD COLUMN     "heightCm" INTEGER,
ADD COLUMN     "macroCarbsG" INTEGER,
ADD COLUMN     "macroFatG" INTEGER,
ADD COLUMN     "macroKcalTarget" INTEGER,
ADD COLUMN     "macroOverrideEnabled" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "macroProteinG" INTEGER,
ADD COLUMN     "sex" TEXT,
ADD COLUMN     "waterGoalMl" INTEGER,
ADD COLUMN     "weightKg" DOUBLE PRECISION;
