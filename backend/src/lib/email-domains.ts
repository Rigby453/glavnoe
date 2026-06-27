// Политика доменов email при регистрации.
//
// По умолчанию разрешён ЛЮБОЙ валидный email-домен (gmail/outlook/icloud и т.д.).
// Это НЕ нарушает 406-ФЗ: закон ограничивает иностранные СЕРВИСЫ авторизации
// (OAuth/identity), а не почтовый адрес как строку логина — `user@gmail.com`,
// чей пароль проверяет наш бэкенд, легален. Открытый список почты нужен для охвата
// (в т.ч. зарубежной аудитории — продукт ships «English first»).
//
// Опционально список можно ОГРАНИЧИТЬ через env ALLOWED_EMAIL_DOMAINS (через
// запятую) — тогда пускаются только перечисленные домены. Пусто/не задано = любой.
//
// Подсказка: если когда-нибудь понадобится РФ-only пресет, можно выставить
// ALLOWED_EMAIL_DOMAINS=mail.ru,bk.ru,list.ru,inbox.ru,internet.ru,yandex.ru,ya.ru,rambler.ru,vk.com

function buildAllowedSet(): Set<string> | null {
  const envVal = process.env["ALLOWED_EMAIL_DOMAINS"];
  if (envVal && envVal.trim().length > 0) {
    return new Set(
      envVal
        .split(",")
        .map((d) => d.trim().toLowerCase())
        .filter((d) => d.length > 0)
    );
  }
  return null; // null = без ограничения, разрешены любые домены
}

// Вычисляется один раз при старте. null = любой домен разрешён.
const ALLOWED_DOMAINS: Set<string> | null = buildAllowedSet();

/**
 * Проверяет, что домен email допустим.
 * Без env-ограничения — всегда true (любой валидный домен).
 * С заданным ALLOWED_EMAIL_DOMAINS — только перечисленные домены.
 * @param email — уже прошедший базовую Zod-валидацию адрес
 */
export function isAllowedEmailDomain(email: string): boolean {
  if (ALLOWED_DOMAINS === null) return true;
  const atIdx = email.lastIndexOf("@");
  if (atIdx === -1) return false;
  const domain = email.slice(atIdx + 1).toLowerCase();
  return ALLOWED_DOMAINS.has(domain);
}

/**
 * Форматированный список для сообщения об ошибке (первые 5).
 * Пустая строка, если ограничения нет (тогда сообщение и не показывается).
 */
export function allowedDomainsHint(): string {
  if (ALLOWED_DOMAINS === null) return "";
  return [...ALLOWED_DOMAINS].slice(0, 5).join(", ");
}
