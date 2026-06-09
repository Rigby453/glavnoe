# AI Tasks — Phase 1 and beyond

> All AI calls live in `backend/src/ai/` ONLY. API keys are backend-only, never exposed to client.
> **Since ADR-022 the provider is abstracted:** `src/ai/provider.ts` picks **Gemini** when
> `GEMINI_API_KEY` is set (current default), else **Anthropic**. The prompts/endpoints below are
> still the spec; the Anthropic-specific `client.ts` pattern at the bottom is superseded by
> `generateText()` from provider.ts.
> Models (Anthropic path): claude-haiku-4-5 (bulk/fast) · claude-sonnet-4-6 (complex/reasoning)

---

## Cost strategy
- **Haiku 4.5**: $1 input / $5 output per 1M tokens → use for all high-frequency tasks
- **Sonnet 4.6**: $3 input / $15 output per 1M tokens → use only for complex reasoning
- **Prompt caching**: mark static system prompts as `cache_control: ephemeral` → up to -90% on repeat calls
- **Batch API**: use for wrapped reports and bulk operations → -50% cost

---

## AI-01: Smart redistribution (Sonnet — paid feature)
**Endpoint:** `POST /api/v1/ai/redistribute`
**When:** morning review, if user is on premium

Request payload to Claude:
```
System (cached): "You are a productivity assistant for students.
  Given a user's pending tasks and today's schedule, propose 2-3
  redistribution plans in JSON. Each plan has a label, brief reason,
  and ordered list of task IDs with new scheduledAt times.
  Be realistic about time. Protect 'main' priority tasks.
  Tone: {tone_preference}. Respond ONLY with valid JSON."

User: "Pending tasks: {JSON}. Today's schedule: {JSON}. Free slots: {JSON}"
```

Expected output:
```json
{
  "plans": [
    {
      "label": "Balanced day",
      "reason": "Spreads work evenly, protects your main task at 10am",
      "items": [{ "id": "uuid", "scheduledAt": "2025-01-15T10:00:00Z" }]
    }
  ]
}
```
Validate JSON before returning. Max 3 plans. Sonnet max_tokens=1000.

## AI-02: Morning review message (Haiku — paid feature)
**Endpoint:** `POST /api/v1/ai/morning-message`
**Input:** `{ pending_count, tone, user_name }`

System (cached by tone — 2 cached variants):
```
Gentle: "You write warm, encouraging messages for a student planner..."
Harsh:  "You write blunt, funny (not mean) messages for a student planner.
         Never shame food, body, or weight."
```

User: `"User {name} has {count} unfinished tasks from yesterday. Write a 1-2 sentence review message."`

Output: plain text string, 1-2 sentences. Haiku max_tokens=100.

## AI-03: Food photo recognition (Haiku multimodal — Phase 1, paid)
**Endpoint:** `POST /api/v1/ai/food-recognize`
**Input:** `{ image_base64: string, media_type: "image/jpeg"|"image/png" }`
**Rate limit:** 3 per user per day (enforce in backend — store count in Redis or DB)

System (cached):
```
"Identify the food in this image. Return ONLY JSON:
{ dish: string, portion_description: string, confidence: 0-1 }
dish must be a specific food name. If unclear, give best guess with low confidence."
```

After Claude responds → look up dish in food database (OFF/Nutritionix) for КБЖУ.
Claude does NOT calculate nutrition — it only identifies the food.

## AI-04: Diary insight (Sonnet — Phase 1, paid)
**Endpoint:** `POST /api/v1/ai/diary-insight`
**Input:** `{ day_logs: DayLog[], tone }`

Pass last 7 DayLogs for pattern context (use prompt caching for older logs).
System: "You are a gentle life coach reviewing a student's week patterns.
  Find one specific insight. Suggest one concrete action. 2-3 sentences max.
  Tone: {tone}. No generic advice."

Output: string (2-3 sentences). Sonnet max_tokens=200.

## AI-05: Weekly wrapped summary (Haiku + Batch — Phase 1)
**Triggered:** every Sunday at 20:00 user local time (cron job)
**Process:** batch all users with completed week → single Batch API call

System (cached): "Summarize a student's week in 1 upbeat paragraph.
  Include: tasks completed, streak, best day, top failure reason.
  Tone: {tone}. Under 60 words."

Use Anthropic Batch API to process all users at once → -50% cost.
Store result in DayLog or WeekLog. Client fetches on Monday.

---

## Implementation pattern (all AI endpoints)
```typescript
// backend/src/ai/client.ts
import Anthropic from '@anthropic-ai/sdk';
const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

export async function callClaude(params: {
  model: 'claude-haiku-4-5' | 'claude-sonnet-4-6',
  system: string,
  userMessage: string,
  maxTokens: number,
  useCache?: boolean
}) {
  const response = await client.messages.create({
    model: params.model,
    max_tokens: params.maxTokens,
    system: params.useCache
      ? [{ type: 'text', text: params.system, cache_control: { type: 'ephemeral' } }]
      : params.system,
    messages: [{ role: 'user', content: params.userMessage }]
  });
  return response.content[0].type === 'text' ? response.content[0].text : '';
}
```

## Rules
- Validate all AI output before storing or returning to client
- If Claude returns invalid JSON → return rule-based fallback, log error
- Never pass `is_protected=true` items to redistribution as movable
- Haiku max_tokens: 100–500 · Sonnet max_tokens: 500–1000
- Log token usage per user per day for cost monitoring
