/**
 * AI-03: распознавание еды по фото (Phase 1, premium).
 * Модель ТОЛЬКО называет блюдо ({dish, portion_description, confidence}) —
 * числа КБЖУ берутся из food DB (Open Food Facts), не из модели (правило ТЗ).
 * Вызов модели — только через provider.ts.
 *
 * Issue #18: обёрнут withAiRetry — раньше этот вызов не ретраился вовсе.
 */

import { z } from "zod";
import { generateText, stripJsonFences } from "./provider.js";
import { withAiRetry } from "./retry.js";

export interface FoodRecognition {
  dish: string;
  portionDescription: string;
  confidence: number;
}

const RecognitionSchema = z.object({
  dish: z.string().min(1),
  portion_description: z.string().default(""),
  confidence: z.number().min(0).max(1),
});

/** Отправляет фото еды в модель и возвращает название блюда + уверенность. */
export async function recognizeFood(params: {
  imageBase64: string;
  mediaType: "image/jpeg" | "image/png";
}): Promise<FoodRecognition> {
  const system =
    "Identify the food in this image. " +
    "Return ONLY JSON with exactly these fields: " +
    '{ "dish": string, "portion_description": string, "confidence": number }. ' +
    "dish must be a specific, searchable food name in English (e.g. " +
    '"grilled chicken breast", not "meat"). portion_description briefly ' +
    "describes the visible amount. confidence is 0..1. " +
    "If unclear, give your best guess with low confidence. " +
    "Do NOT estimate calories or nutrition — only identify the food.";

  const user = "What food is shown in this photo? JSON only.";

  // withAiRetry повторяет вызов при временных сбоях (rate-limit/перегрузка/
  // битый JSON); постоянные сбои (гео-блок, суточная квота) идут наверх сразу.
  const result = await withAiRetry(() =>
    callAndParse({ system, user, imageBase64: params.imageBase64, mediaType: params.mediaType })
  );

  return {
    dish: result.dish,
    portionDescription: result.portion_description,
    confidence: result.confidence,
  };
}

async function callAndParse(args: {
  system: string;
  user: string;
  imageBase64: string;
  mediaType: "image/jpeg" | "image/png";
}): Promise<z.infer<typeof RecognitionSchema>> {
  const text = await generateText({
    system: args.system,
    user: args.user,
    maxTokens: 150,
    tier: "fast",
    json: true,
    image: { base64: args.imageBase64, mediaType: args.mediaType },
  });

  let parsed: unknown;
  try {
    parsed = JSON.parse(stripJsonFences(text));
  } catch {
    throw new Error("AI returned an unparseable response for food photo.");
  }
  const result = RecognitionSchema.safeParse(parsed);
  if (!result.success) {
    throw new Error("AI returned an unexpected food-recognition shape.");
  }
  return result.data;
}
