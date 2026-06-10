/**
 * Провайдер-агностичный слой генерации для AI-фич.
 * Выбор провайдера по env: есть GEMINI_API_KEY → Gemini; иначе ANTHROPIC_API_KEY → Claude.
 * Так переключение Gemini ↔ Anthropic — это только смена .env, без правки логики фич.
 * Вызовы модели идут ТОЛЬКО отсюда (backend/src/ai/).
 *
 * Gemini зовётся по REST (global fetch, Node 22) — без SDK, чтобы не плодить
 * зависимости. Anthropic — через официальный SDK.
 */

import Anthropic from "@anthropic-ai/sdk";

export type AiProvider = "gemini" | "anthropic";
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

/** Какой провайдер активен (по наличию ключа). */
export function activeProvider(): AiProvider {
  if (process.env["GEMINI_API_KEY"]) return "gemini";
  if (process.env["ANTHROPIC_API_KEY"]) return "anthropic";
  throw new Error(
    "No AI key set — define GEMINI_API_KEY (or ANTHROPIC_API_KEY) in backend/.env"
  );
}

/** Единая точка генерации текста для всех AI-фич. */
export async function generateText(params: GenerateParams): Promise<string> {
  return activeProvider() === "gemini"
    ? geminiGenerate(params)
    : anthropicGenerate(params);
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

async function geminiGenerate({
  system,
  user,
  maxTokens,
  json,
  image,
}: GenerateParams): Promise<string> {
  const apiKey = process.env["GEMINI_API_KEY"];
  if (!apiKey) throw new Error("GEMINI_API_KEY is not set.");
  // Самая дешёвая модель по умолчанию; меняется через .env без правки кода.
  // 2.0-flash-lite отдаёт 429 quota=0 для новых ключей (модель выведена) —
  // дефолт обновлён на 2.5 (проверено живым вызовом 2026-06-10).
  const model = process.env["GEMINI_MODEL"] ?? "gemini-2.5-flash-lite";

  const parts: Array<Record<string, unknown>> = [{ text: user }];
  if (image) {
    parts.push({
      inlineData: { mimeType: image.mediaType, data: image.base64 },
    });
  }

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
          ...(json ? { responseMimeType: "application/json" } : {}),
        },
      }),
    }
  );

  if (!res.ok) {
    const body = await res.text();
    throw new Error(`Gemini API error ${res.status}: ${body.slice(0, 300)}`);
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
