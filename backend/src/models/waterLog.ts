import type { WaterLog } from "@prisma/client";

// Тип ответа для WaterLog — строго по api-spec.yaml (snake_case)
export interface SerializedWaterLog {
  id: string;
  user_id: string;
  amount_ml: number;
  logged_at: string;
}

/**
 * Преобразует Prisma WaterLog (camelCase) в snake_case ответ API.
 */
export function serializeWaterLog(log: WaterLog): SerializedWaterLog {
  return {
    id: log.id,
    user_id: log.userId,
    amount_ml: log.amountMl,
    logged_at: log.loggedAt.toISOString(),
  };
}
