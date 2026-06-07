/**
 * AI-02: Утреннее сообщение (tone-aware).
 * Claude (Haiku) генерирует 1-2 предложения под тон gentle/harsh.
 * Claude вызывается ТОЛЬКО здесь (backend/src/ai/). Ключ — из env.
 */

import Anthropic from '@anthropic-ai/sdk';

let _client: Anthropic | null = null;

function getClient(): Anthropic {
  if (_client) return _client;
  const apiKey = process.env['ANTHROPIC_API_KEY'];
  if (!apiKey) {
    throw new Error('ANTHROPIC_API_KEY is not set.');
  }
  _client = new Anthropic({ apiKey });
  return _client;
}

export type Tone = 'gentle' | 'harsh';

/**
 * Возвращает короткое утреннее сообщение.
 * @param pendingCount - сколько незавершённых задач перенесено на сегодня
 * @param tone - gentle (мягкий) / harsh (жёсткий)
 * @param userName - имя пользователя (опционально)
 */
export async function generateMorningMessage(params: {
  pendingCount: number;
  tone: Tone;
  userName?: string;
}): Promise<{ message: string }> {
  const { pendingCount, tone, userName } = params;
  const client = getClient();

  const toneHint =
    tone === 'harsh'
      ? 'Be blunt, no-nonsense and a little provocative, but never insulting.'
      : 'Be warm, supportive and encouraging.';

  const system =
    'You write the morning review line for a student planner called the app. ' +
    'Output ONE or TWO short sentences, plain text, no emoji, no quotes. ' +
    toneHint;

  const who = userName ? `The user's name is ${userName}. ` : '';
  const userText =
    `${who}They have ${pendingCount} unfinished task(s) carried over to today. ` +
    'Write the morning message.';

  const msg = await client.messages.create({
    model: 'claude-haiku-4-5',
    max_tokens: 120,
    system: [
      { type: 'text', text: system, cache_control: { type: 'ephemeral' } },
    ],
    messages: [{ role: 'user', content: userText }],
  });

  const block = msg.content[0];
  const message = block && block.type === 'text' ? block.text.trim() : '';
  if (!message) {
    throw new Error('Claude returned an empty morning message.');
  }
  return { message };
}
