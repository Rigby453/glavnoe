// Отправка транзакционных писем через Resend HTTP API (ADR-059).
//
// Без тяжёлых SDK/зависимостей — используем глобальный fetch (доступен в
// Node 18+, проект на Node 22, см. backend/CLAUDE.md). Если RESEND_API_KEY
// не задан (dev/test или ключ ещё не выдан), доставка считается
// "не настроена" — вызывающий код (auth-reset.ts) сам решает, что делать
// (в dev/test — вернуть dev_code в ответе вместо реальной отправки).

export interface SendEmailResult {
  sent: boolean;
  error?: string;
}

/**
 * Настроена ли реальная доставка почты (т.е. задан RESEND_API_KEY).
 * Используется в auth-reset.ts, чтобы решить, раскрывать ли dev_code в ответе:
 * как только ключ появился — dev_code больше не возвращается, даже в dev/test.
 */
export function isEmailDeliveryConfigured(): boolean {
  return Boolean(process.env["RESEND_API_KEY"]);
}

function buildResetEmailHtml(code: string): string {
  return `<!doctype html>
<html>
  <body style="font-family: -apple-system, Arial, sans-serif; color: #1a1a1a;">
    <p>You requested a password reset for your Kaizen account.</p>
    <p>Your reset code is:</p>
    <p style="font-size: 28px; font-weight: 700; letter-spacing: 6px;">${code}</p>
    <p>This code expires in 15 minutes. If you did not request this, you can safely ignore this email.</p>
  </body>
</html>`;
}

/**
 * Отправляет письмо с кодом сброса пароля через Resend.
 * Никогда не бросает исключение наружу — при любом сбое (нет ключа, нет
 * RESEND_FROM, сетевая ошибка, ответ не 2xx) возвращает { sent: false, error }.
 * Вызывающий код логирует ошибку, но всё равно отвечает клиенту 200 (security:
 * не раскрывать существование аккаунта через различие в ответах).
 */
export async function sendPasswordResetEmail(
  toEmail: string,
  code: string
): Promise<SendEmailResult> {
  const apiKey = process.env["RESEND_API_KEY"];
  if (!apiKey) {
    return { sent: false, error: "RESEND_API_KEY is not set" };
  }
  const from = process.env["RESEND_FROM"];
  if (!from) {
    return { sent: false, error: "RESEND_FROM is not set" };
  }

  try {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from,
        to: toEmail,
        subject: "Reset your Kaizen password",
        html: buildResetEmailHtml(code),
      }),
    });

    if (!res.ok) {
      const body = await res.text().catch(() => "");
      return { sent: false, error: `Resend API responded ${res.status}: ${body}` };
    }
    return { sent: true };
  } catch (err) {
    return { sent: false, error: err instanceof Error ? err.message : String(err) };
  }
}
