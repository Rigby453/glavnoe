/**
 * Провайдер-агностичный слой генерации для AI-фич.
 * Выбор провайдера по env, приоритет: GROQ_API_KEY → GEMINI_API_KEY → ANTHROPIC_API_KEY.
 * Так переключение Groq ↔ Gemini ↔ Anthropic — это только смена .env, без правки логики фич.
 * Вызовы модели идут ТОЛЬКО отсюда (backend/src/ai/).
 *
 * Groq и Gemini зовутся по REST (global fetch, Node 22) — без SDK, чтобы не
 * плодить зависимости. Anthropic — через официальный SDK. Groq использует
 * OpenAI-совместимый REST API (chat/completions).
 */

import Anthropic from "@anthropic-ai/sdk";
import { AiError, classifyAiError, type AiErrorKind } from "./aiErrors.js";

export type AiProvider = "gemini" | "anthropic" | "groq";
export type ModelTier = "fast" | "smart";

export interface GenerateParams {
  system: string;
  user: string;
  maxTokens: number;
  /** fast → дешёвая модель; smart → сильнее (на Gemini обе = одна дешёвая) */
  tier?: ModelTier;
  /** просим строгий JSON (responseMimeType для Gemini) */
  json?: boolean;
  /** мультимодальный ввод (фото расписания) */
  image?: { base64: string; mediaType: string };
}

/**
 * Какой провайдер активен (по наличию ключа).
 * Приоритет: GROQ_API_KEY → GEMINI_API_KEY → ANTHROPIC_API_KEY.
 * Groq стоит первым НАМЕРЕННО: Gemini в разработке/тестировании ведёт себя
 * нестабильно (частые 429/перегрузки), а у Groq есть щедрый бесплатный тир —
 * если ключ Groq задан, считаем это осознанным выбором на время разработки.
 */
export function activeProvider(): AiProvider {
  if (process.env["GROQ_API_KEY"]) return "groq";
  if (process.env["GEMINI_API_KEY"]) return "gemini";
  if (process.env["ANTHROPIC_API_KEY"]) return "anthropic";
  throw new Error(
    "No AI key set — define GROQ_API_KEY (or GEMINI_API_KEY / ANTHROPIC_API_KEY) in backend/.env"
  );
}

/**
 * Решает, стоит ли переключиться на Anthropic при сбое Gemini (issue #18).
 * Только для ПОСТОЯННЫХ сбоев, которые withAiRetry внутри того же провайдера
 * не лечит: гео-блок (регион не обслуживается Gemini) и исчерпанная
 * СУТОЧНАЯ квота free-tier (ждать сброс ~24ч иначе бессмысленно).
 * Поминутный rate-limit (quota_rate) сюда НЕ входит — для него есть быстрый
 * ретрай того же провайдера (withAiRetry); переключать провайдера на каждый
 * короткий всплеск 429 не нужно. Чистая функция — тестируется без SDK/сети.
 */
export function shouldFallbackToAnthropic(err: unknown, hasAnthropicKey: boolean): boolean {
  if (!hasAnthropicKey) return false;
  const kind = classifyAiError(err);
  return kind === "region" || kind === "quota_daily";
}

/** Единая точка генерации текста для всех AI-фич. */
export async function generateText(params: GenerateParams): Promise<string> {
  const provider = activeProvider();
  if (provider === "groq") return groqGenerate(params);
  if (provider === "anthropic") return anthropicGenerate(params);
  try {
    return await geminiGenerate(params);
  } catch (err) {
    if (shouldFallbackToAnthropic(err, Boolean(process.env["ANTHROPIC_API_KEY"]))) {
      return anthropicGenerate(params);
    }
    throw err;
  }
}

/**
 * Убирает markdown-ограждения ```json ... ``` вокруг JSON, если модель их добавила.
 * Возвращает строку, готовую к JSON.parse.
 */
export function stripJsonFences(text: string): string {
  const t = text.trim();
  if (t.startsWith("```")) {
    return t
      .replace(/^```(?:json)?\s*/i, "")
      .replace(/```$/, "")
      .trim();
  }
  return t;
}

// ---------------------------------------------------------------------------
// Gemini (REST)
// ---------------------------------------------------------------------------

interface GeminiPart {
  text?: string;
}
interface GeminiResponse {
  candidates?: { content?: { parts?: GeminiPart[] } }[];
  promptFeedback?: { blockReason?: string };
}

function geminiModel(tier: ModelTier): string {
  return tier === "smart"
    ? (process.env["GEMINI_MODEL_SMART"] ?? "gemini-2.5-flash")
    : (process.env["GEMINI_MODEL"] ?? "gemini-2.5-flash-lite");
}

async function geminiGenerate({
  system,
  user,
  maxTokens,
  tier,
  json,
  image,
}: GenerateParams): Promise<string> {
  const apiKey = process.env["GEMINI_API_KEY"];
  if (!apiKey) throw new Error("GEMINI_API_KEY is not set.");
  // Модель по тиру (меняется через .env без правки кода):
  //   fast  → GEMINI_MODEL (дешёвая, default gemini-2.5-flash-lite)
  //   smart → GEMINI_MODEL_SMART (сильнее, default gemini-2.5-flash) — для
  //           menu-build, где нужно попадать во ВСЕ макро-цели (ADR-046).
  // 2.0-flash-lite отдаёт 429 quota=0 для новых ключей (модель выведена) —
  // дефолт обновлён на 2.5 (проверено живым вызовом 2026-06-10).
  const model = geminiModel(tier ?? "fast");

  // Gemini REST API v1beta использует snake_case для всех полей.
  // Для multimodal-запросов изображение должно идти ПЕРЕД текстом-промптом.
  const parts: Array<Record<string, unknown>> = [];
  if (image) {
    parts.push({
      // Правильное имя поля — inline_data (snake_case), не inlineData.
      // mime_type тоже snake_case. Ошибка в этих именах → API игнорирует
      // изображение → пустой ответ → "AI service unavailable".
      inline_data: { mime_type: image.mediaType, data: image.base64 },
    });
  }
  parts.push({ text: user });

  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": apiKey,
      },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: system }] },
        contents: [{ role: "user", parts }],
        generationConfig: {
          maxOutputTokens: maxTokens,
          temperature: 0.7,
          // Отключаем «thinking» у Gemini 2.5 (flash/flash-lite): по умолчанию
          // модель тратит СОТНИ-ТЫСЯЧИ токенов на внутренние «мысли», которые
          // засчитываются в maxOutputTokens → на реальный ответ бюджета не
          // остаётся → finishReason=MAX_TOKENS → обрезанный/невалидный JSON.
          // Это ломало menu-build (сборку меню) и делало ИИ-итоги нестабильными
          // (живой вызов: thoughtsTokenCount≈3837, candidates≈148 → обрыв).
          // Наши фичи не требуют chain-of-thought (числа КБЖУ берём из food DB,
          // не из модели), поэтому thinkingBudget:0 — весь бюджет на вывод,
          // ответ стабилен, быстрее и дешевле. Поддерживается flash/flash-lite.
          thinkingConfig: { thinkingBudget: 0 },
          ...(json ? { responseMimeType: "application/json" } : {}),
        },
      }),
    }
  );

  if (!res.ok) {
    const body = await res.text();
    throw buildGeminiError(res.status, body);
  }

  const data = (await res.json()) as GeminiResponse;
  const text = (data.candidates?.[0]?.content?.parts ?? [])
    .map((p) => p.text ?? "")
    .join("")
    .trim();
  if (!text) {
    const reason = data.promptFeedback?.blockReason;
    throw new Error(
      `Gemini returned an empty response${reason ? ` (blocked: ${reason})` : ""}.`
    );
  }
  return text;
}

interface GeminiErrorDetailViolation {
  quotaId?: string;
}
interface GeminiErrorDetail {
  violations?: GeminiErrorDetailViolation[];
}
interface GeminiErrorBody {
  error?: {
    message?: string;
    status?: string;
    details?: GeminiErrorDetail[];
  };
}

/**
 * Строит классифицируемую ошибку (issue #18) из тела ответа Gemini при !res.ok.
 * Gemini отдаёт `{"error":{"code","message","status","details"}}`; для квоты
 * `status` — "RESOURCE_EXHAUSTED", а `details[].violations[].quotaId`
 * различает суточный лимит ("...PerDayPerProjectPerModel...") от поминутного
 * ("...PerMinutePerProjectPerModel..."). Если тело — не JSON (proxy-ошибка,
 * HTML-страница и т.п.), используем обрезанный сырой текст — классификация
 * по http-статусу/ключевым словам всё ещё сработает в classifyAiError.
 */
function buildGeminiError(httpStatus: number, bodyText: string): AiError {
  let message = bodyText.slice(0, 500);
  let apiStatus = "";
  let quotaId = "";
  try {
    const body = JSON.parse(bodyText) as GeminiErrorBody;
    if (body.error?.message) message = body.error.message;
    if (body.error?.status) apiStatus = body.error.status;
    for (const detail of body.error?.details ?? []) {
      const found = detail.violations?.find((v) => v.quotaId);
      if (found?.quotaId) {
        quotaId = found.quotaId;
        break;
      }
    }
  } catch {
    // тело не JSON — оставляем сырой обрезанный текст, классификация по
    // ключевым словам/http-статусу в classifyAiError всё равно сработает.
  }

  // classifyAiError() читает сообщение целиком (включая quotaId и apiStatus,
  // вшитые в текст ниже) — отдельный объект kind тут не нужен, достаточно
  // включить в message все маркеры, по которым она различает quota_daily от
  // quota_rate/region/overloaded.
  const fullMessage =
    `Gemini API error ${httpStatus}${apiStatus ? ` (${apiStatus})` : ""}: ${message}` +
    (quotaId ? ` [quotaId=${quotaId}]` : "");
  let kind: AiErrorKind;
  if (apiStatus === "RESOURCE_EXHAUSTED" || httpStatus === 429) {
    kind = quotaId.toLowerCase().includes("perday") ? "quota_daily" : "quota_rate";
  } else if (message.toLowerCase().includes("user location is not supported")) {
    kind = "region";
  } else if (httpStatus === 503 || apiStatus === "UNAVAILABLE") {
    kind = "overloaded";
  } else {
    kind = "unknown";
  }
  return new AiError(kind, fullMessage);
}

// ---------------------------------------------------------------------------
// Groq (REST, OpenAI-совместимый chat/completions) — приоритетный dev-провайдер
// ---------------------------------------------------------------------------

interface GroqResponse {
  choices?: { message?: { content?: string } }[];
}

function groqModel(tier: ModelTier, hasImage: boolean): string {
  if (hasImage) {
    return process.env["GROQ_MODEL_VISION"] ?? "meta-llama/llama-4-scout-17b-16e-instruct";
  }
  return tier === "smart"
    ? (process.env["GROQ_MODEL_SMART"] ?? "llama-3.3-70b-versatile")
    : (process.env["GROQ_MODEL"] ?? "llama-3.1-8b-instant");
}

async function groqGenerate({
  system,
  user,
  maxTokens,
  tier,
  json,
  image,
}: GenerateParams): Promise<string> {
  const apiKey = process.env["GROQ_API_KEY"];
  if (!apiKey) throw new Error("GROQ_API_KEY is not set.");

  const model = groqModel(tier ?? "fast", Boolean(image));

  // OpenAI JSON-режим требует, чтобы слово "json" встречалось в сообщениях,
  // иначе API отвечает 400. Подстраховываемся: если json=true, а слова "json"
  // нет ни в system, ни в user — дописываем инструкцию в system.
  let systemMessage = system;
  if (json && !/json/i.test(system) && !/json/i.test(user)) {
    systemMessage = `${system}\nRespond with a valid JSON object only.`;
  }

  const userContent: unknown = image
    ? [
        { type: "text", text: user },
        {
          type: "image_url",
          image_url: { url: `data:${image.mediaType};base64,${image.base64}` },
        },
      ]
    : user;

  const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model,
      messages: [
        { role: "system", content: systemMessage },
        { role: "user", content: userContent },
      ],
      max_tokens: maxTokens,
      temperature: 0.7,
      ...(json ? { response_format: { type: "json_object" } } : {}),
    }),
  });

  if (!res.ok) {
    const body = await res.text();
    throw buildGroqError(res.status, body);
  }

  const data = (await res.json()) as GroqResponse;
  const text = (data.choices?.[0]?.message?.content ?? "").trim();
  if (!text) {
    throw new AiError("invalid_response", "Groq returned an empty response.");
  }
  return text;
}

interface GroqErrorBody {
  error?: {
    message?: string;
    type?: string;
    code?: string;
  };
}

/**
 * Строит классифицируемую ошибку из тела ответа Groq при !res.ok.
 * Groq (OpenAI-совместимый) отдаёт `{"error":{"message","type","code"}}`.
 */
function buildGroqError(httpStatus: number, bodyText: string): AiError {
  let message = bodyText.slice(0, 500);
  try {
    const body = JSON.parse(bodyText) as GroqErrorBody;
    if (body.error?.message) message = body.error.message;
  } catch {
    // тело не JSON — оставляем сырой обрезанный текст.
  }

  const fullMessage = `Groq API error ${httpStatus}: ${message}`;
  const lower = message.toLowerCase();
  let kind: AiErrorKind;
  if (httpStatus === 429) {
    const dailySignal =
      lower.includes("per day") ||
      lower.includes("tokens per day") ||
      lower.includes("requests per day") ||
      lower.includes("rpd") ||
      lower.includes("tpd");
    kind = dailySignal ? "quota_daily" : "quota_rate";
  } else if (httpStatus === 503 || httpStatus === 502) {
    kind = "overloaded";
  } else {
    kind = "unknown";
  }
  return new AiError(kind, fullMessage);
}

// ---------------------------------------------------------------------------
// Anthropic (SDK) — для возврата к Claude позже
// ---------------------------------------------------------------------------

let _anthropic: Anthropic | null = null;
function anthropicClient(): Anthropic {
  if (_anthropic) return _anthropic;
  const apiKey = process.env["ANTHROPIC_API_KEY"];
  if (!apiKey) throw new Error("ANTHROPIC_API_KEY is not set.");
  _anthropic = new Anthropic({ apiKey });
  return _anthropic;
}

function anthropicModel(tier: ModelTier): string {
  return tier === "smart"
    ? (process.env["ANTHROPIC_MODEL_SMART"] ?? "claude-sonnet-4-6")
    : (process.env["ANTHROPIC_MODEL_FAST"] ?? "claude-haiku-4-5");
}

async function anthropicGenerate({
  system,
  user,
  maxTokens,
  tier,
  image,
}: GenerateParams): Promise<string> {
  const content: Anthropic.ContentBlockParam[] = [{ type: "text", text: user }];
  if (image) {
    content.push({
      type: "image",
      source: {
        type: "base64",
        media_type: image.mediaType as "image/jpeg" | "image/png",
        data: image.base64,
      },
    });
  }

  const msg = await anthropicClient().messages.create({
    model: anthropicModel(tier ?? "fast"),
    max_tokens: maxTokens,
    system: [{ type: "text", text: system }],
    messages: [{ role: "user", content }],
  });

  const block = msg.content[0];
  const text = block && block.type === "text" ? block.text.trim() : "";
  if (!text) throw new Error("Claude returned an empty response.");
  return text;
}
