/**
 * Волна 6 / Этап 4 (docs/WAVE6-REVIEW-FINDINGS.md, п.2) — серверное «сейчас»
 * пользователя. Промптам quick-add/onboarding-plan нужно текущее время, а не
 * только дату, чтобы разрешать относительные фразы вроде «через час» —
 * `today` в user-payload раньше нёс только дату, без времени.
 *
 * Формат: "YYYY-MM-DDTHH:MM" — naive-local, без смещения/Z. Тот же контракт,
 * что и у scheduled_at/deadline (см. docs/WAVE6-REVIEW-FINDINGS.md п.1):
 * модель работает исключительно в таймзоне пользователя, сервер не просит её
 * конвертировать в UTC.
 *
 * Общий модуль (не дублировать в onboardingPlan.ts/quickAdd.ts) — оба файла
 * импортируют localNowFor().
 */

/** Строка вида "+03:00"/"-05:30" → офсет в минутах. */
function offsetTagToMinutes(tag: string): number {
  const sign = tag[0] === "-" ? -1 : 1;
  const hh = parseInt(tag.slice(1, 3), 10);
  const mm = parseInt(tag.slice(4, 6), 10);
  return sign * (hh * 60 + mm);
}

/** UTC-«сейчас» в формате YYYY-MM-DDTHH:MM — безопасный фоллбэк на любую ошибку. */
function utcNow(): string {
  return new Date().toISOString().slice(0, 16);
}

// Веб-клиент не имеет доступа к IANA tz-базе и вместо зоны шлёт офсет —
// "UTC" или "UTC+03:00" (см. п.7 WAVE6-REVIEW-FINDINGS.md). Intl.DateTimeFormat
// не парсит такие строки как timeZone (кидает RangeError), поэтому для них
// считаем офсет арифметикой от Date.now().
const UTC_OFFSET_RE = /^UTC([+-]\d{2}:\d{2})?$/;

/**
 * Локальное «сейчас» пользователя.
 * @param timezone - IANA-таймзона ("Europe/Moscow") ИЛИ строка смещения
 *   ("UTC", "UTC+03:00").
 */
export function localNowFor(timezone: string): string {
  try {
    const formatter = new Intl.DateTimeFormat("sv-SE", {
      timeZone: timezone,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      hour12: false,
    });
    const parts = formatter.formatToParts(new Date());
    const get = (type: string) => parts.find((p) => p.type === type)?.value;
    const y = get("year");
    const mo = get("month");
    const d = get("day");
    const h = get("hour");
    const mi = get("minute");
    if (y && mo && d && h && mi) {
      return `${y}-${mo}-${d}T${h}:${mi}`;
    }
    return utcNow();
  } catch {
    const m = UTC_OFFSET_RE.exec(timezone);
    if (m) {
      const offsetMinutes = m[1] ? offsetTagToMinutes(m[1]) : 0;
      return new Date(Date.now() + offsetMinutes * 60_000).toISOString().slice(0, 16);
    }
    return utcNow();
  }
}
