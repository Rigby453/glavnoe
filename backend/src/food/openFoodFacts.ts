/**
 * Источник данных о продуктах — Open Food Facts (бесплатно, без ключа, открыто).
 * https://world.openfoodfacts.org . Числа КБЖУ берём отсюда (per 100 g), не из AI.
 * OFF просит указывать User-Agent.
 */

const OFF_BASE = "https://world.openfoodfacts.org";
// Полнотекстовый поиск переехал на search-a-licious: легаси cgi/search.pl
// стабильно отдаёт 503 (обнаружено на ревью MVP 2026-06-10).
const OFF_SEARCH_BASE = "https://search.openfoodfacts.org";
const USER_AGENT = "Kaizen/1.0 (student planner; contact: support@kaizen.app)";

// Таймаут на fetch-запросы к OFF (мс). Превышение → AbortError.
const FETCH_TIMEOUT_MS = 8_000;

// --- In-memory LRU+TTL кэш для searchProducts ---
// Ключ: язык + лимит + нормализованный запрос (trim+lowercase). Значение: результат
// + время вставки. Язык и лимит входят в ключ, иначе результаты для одного языка/лимита
// «утекали» бы в выдачу для другого (FOOD-26/28 fix 2026-07-01).
const CACHE_TTL_MS = 10 * 60 * 1_000; // 10 минут
const CACHE_MAX_SIZE = 200; // максимум уникальных запросов

interface CacheEntry {
  results: FoodProduct[];
  insertedAt: number; // Date.now()
}

// Map итерируется в порядке вставки — используем это для LRU-eviction (FIFO-приближение).
const searchCache = new Map<string, CacheEntry>();

/** Нормализует строку запроса для использования в качестве ключа кэша. */
function normalizeCacheKey(query: string): string {
  return query.trim().toLowerCase();
}

/**
 * Возвращает закэшированный результат или null если промах/протух.
 * Также удаляет протухшие записи по ходу.
 */
function cacheGet(key: string): FoodProduct[] | null {
  const entry = searchCache.get(key);
  if (!entry) return null;
  if (Date.now() - entry.insertedAt > CACHE_TTL_MS) {
    searchCache.delete(key);
    return null;
  }
  // Перемещаем в конец Map (LRU-touch): удаляем и снова вставляем.
  searchCache.delete(key);
  searchCache.set(key, entry);
  return entry.results;
}

/** Сохраняет результат в кэш; вытесняет самую старую запись если достигнут лимит. */
function cacheSet(key: string, results: FoodProduct[]): void {
  // Удаляем существующую запись чтобы обновить позицию.
  searchCache.delete(key);
  // LRU eviction: удаляем первую (самую старую) запись если упираемся в лимит.
  if (searchCache.size >= CACHE_MAX_SIZE) {
    const oldest = searchCache.keys().next().value;
    if (oldest !== undefined) searchCache.delete(oldest);
  }
  searchCache.set(key, { results, insertedAt: Date.now() });
}

/** Нормализованный продукт (значения — на 100 г, null если неизвестно). */
export interface FoodProduct {
  code: string; // штрихкод / OFF id
  name: string;
  brand: string | null;
  image: string | null;
  per100g: {
    calories: number | null;
    protein: number | null;
    fat: number | null;
    carbs: number | null;
    sugar: number | null;
    fiber: number | null;
  };
}

// --- Сырые формы ответа OFF (только нужные поля) ---
interface OffNutriments {
  "energy-kcal_100g"?: number | string;
  proteins_100g?: number | string;
  fat_100g?: number | string;
  carbohydrates_100g?: number | string;
  sugars_100g?: number | string;
  fiber_100g?: number | string;
}
interface OffProduct {
  code?: string;
  product_name?: string;
  // search-a-licious отдаёт массив, api/v2 — строку через запятую
  brands?: string | string[];
  nutriments?: OffNutriments;
  image_url?: string;
  // Локализованные имена product_name_<lang> (динамический ключ — запрашиваем
  // конкретный язык в `fields`, см. buildFields()).
  [key: string]: unknown;
}
interface OffProductResponse {
  status?: number;
  product?: OffProduct;
}
interface OffSearchResponse {
  hits?: OffProduct[];
}

function num(v: number | string | undefined): number | null {
  if (v === undefined || v === null || v === "") return null;
  const n = typeof v === "number" ? v : Number(v);
  return Number.isFinite(n) ? Math.round(n * 10) / 10 : null;
}

/** Читает строковое поле OFF-продукта по динамическому ключу (trim, "" если нет/не строка). */
function strField(p: OffProduct, key: string): string {
  const v = p[key];
  return typeof v === "string" ? v.trim() : "";
}

interface NormalizedProduct {
  product: FoodProduct;
  // true — нашлось имя именно на языке пользователя (product_name_<lang>),
  // не дефолтный фолбэк. Используется для ранжирования результатов поиска.
  hasLocalizedName: boolean;
  // Все известные варианты имени/бренда продукта (локализованное + дефолтное +
  // английское + бренд), lower-case, склеенные пробелом — используется ТОЛЬКО для
  // проверки релевантности (isRelevant), не для отображения. Важно: запрос может
  // быть набран в другом алфавите/языке, чем итоговое отображаемое имя (например,
  // запрос "apple" при выбранном русском интерфейсе должен матчить продукт, чьё
  // отображаемое имя локализовано в "Яблочный сок") — поэтому релевантность
  // проверяем по ВСЕМ вариантам имени, а не только по тому, что показываем.
  searchHaystack: string;
}

/**
 * Превращает сырой OFF-продукт в FoodProduct. Имя выбирается по приоритету:
 * 1) product_name_<lang> — реально локализованное под язык пользователя имя;
 * 2) product_name — дефолтное имя OFF (для api/v2 уже локализуется через `lc=`,
 *    для search-a-licious — обычно на «основном» языке продукта);
 * 3) product_name_en — последний фолбэк, если у продукта вообще нет дефолтного имени.
 * Продукт без имени бесполезен — возвращаем null.
 */
function normalize(
  p: OffProduct,
  fallbackCode: string,
  lang: string
): NormalizedProduct | null {
  const localized = strField(p, `product_name_${lang}`);
  const defaultName = strField(p, "product_name");
  const enName = strField(p, "product_name_en");
  const name = localized || defaultName || enName;
  if (!name) return null; // продукт без названия бесполезен

  const n = p.nutriments ?? {};
  const rawBrand = Array.isArray(p.brands) ? p.brands[0] : p.brands?.split(",")[0];
  const brand = rawBrand?.trim() || null;
  const searchHaystack = [localized, defaultName, enName, brand ?? ""]
    .filter(Boolean)
    .join(" ")
    .toLocaleLowerCase();
  return {
    hasLocalizedName: localized.length > 0,
    searchHaystack,
    product: {
      code: (p.code ?? fallbackCode).trim(),
      name,
      brand,
      image: p.image_url?.trim() || null,
      per100g: {
        calories: num(n["energy-kcal_100g"]),
        protein: num(n.proteins_100g),
        fat: num(n.fat_100g),
        carbs: num(n.carbohydrates_100g),
        sugar: num(n.sugars_100g),
        fiber: num(n.fiber_100g),
      },
    },
  };
}

/** Список полей `fields=` для запроса к OFF — включает имя на языке пользователя. */
function buildFields(lang: string): string {
  // Set убирает дубликат, если lang === "en" (product_name_en запрошено бы дважды).
  const fields = new Set([
    "code",
    "product_name",
    `product_name_${lang}`,
    "product_name_en",
    "brands",
    "nutriments",
    "image_url",
  ]);
  return Array.from(fields).join(",");
}

/** Токенизирует запрос для проверки релевантности (lower-case, по словам). */
function queryTokens(query: string): string[] {
  return query.trim().toLocaleLowerCase().split(/\s+/).filter(Boolean);
}

/**
 * FOOD-26 fix: OFF (особенно search-a-licious) ищет по множеству полей —
 * брендам, категориям, ингредиентам, переводам на других языках — не только по
 * имени продукта. Из-за этого короткий (даже однобуквенный) запрос мог вернуть
 * продукт, в чьём имени/бренде нет даже введённой буквы: совпадение приходило
 * из поля, которое мы вообще не показываем пользователю.
 * Фильтруем результат на стороне backend: каждый токен запроса должен
 * встречаться (как подстрока, без учёта регистра) в одном из известных
 * вариантов имени/бренда продукта (searchHaystack — см. normalize()).
 */
function isRelevant(searchHaystack: string, tokens: string[]): boolean {
  if (tokens.length === 0) return true;
  return tokens.every((t) => searchHaystack.includes(t));
}

/** Поиск продукта по штрихкоду. null — не найден. */
export async function lookupBarcode(
  code: string,
  lang = "en"
): Promise<FoodProduct | null> {
  const safeLang = /^[a-z]{2}$/.test(lang) ? lang : "en";
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);
  try {
    const res = await fetch(
      `${OFF_BASE}/api/v2/product/${encodeURIComponent(code)}.json` +
        `?fields=${buildFields(safeLang)}&lc=${encodeURIComponent(safeLang)}`,
      { headers: { "User-Agent": USER_AGENT }, signal: controller.signal }
    );
    if (res.status === 404) return null;
    if (!res.ok) throw new Error(`Open Food Facts error ${res.status}`);
    const data = (await res.json()) as OffProductResponse;
    if (data.status !== 1 || !data.product) return null;
    const result = normalize(data.product, code, safeLang);
    return result ? result.product : null;
  } finally {
    clearTimeout(timer);
  }
}

/** Текстовый поиск продуктов (до [limit]), на языке [lang] (2-буквенный код, "en" по умолчанию). */
export async function searchProducts(
  query: string,
  limit = 20,
  lang = "en"
): Promise<FoodProduct[]> {
  const safeLang = /^[a-z]{2}$/.test(lang) ? lang : "en";

  // Нормализуем ключ кэша — язык + лимит + запрос (независимо от регистра/пробелов).
  const cacheKey = `${safeLang}:${limit}:${normalizeCacheKey(query)}`;

  // Проверяем кэш до обращения к OFF.
  const cached = cacheGet(cacheKey);
  if (cached !== null) {
    return cached.slice(0, limit);
  }

  // Берём с запасом сверх limit — после фильтра релевантности (isRelevant) и
  // ранжирования по языку часть «сырых» хитов OFF отсеется, но мы всё ещё хотим
  // вернуть до [limit] реально релевантных продуктов.
  const fetchSize = Math.min(limit * 3, 60);

  const url =
    `${OFF_SEARCH_BASE}/search?q=${encodeURIComponent(query)}` +
    `&page_size=${fetchSize}&fields=${buildFields(safeLang)}` +
    // lc — легаси-параметр локализации OFF; langs — параметр search-a-licious.
    // Передаём оба: какой бы из них поисковый бэкенд ни учитывал, лишний
    // параметр другой системой просто игнорируется.
    `&lc=${encodeURIComponent(safeLang)}&langs=${encodeURIComponent(safeLang)}`;

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);

  let res: Response;
  try {
    res = await fetch(url, {
      headers: { "User-Agent": USER_AGENT },
      signal: controller.signal,
    });
  } catch (err) {
    clearTimeout(timer);
    // AbortError означает таймаут — возвращаем пустой список, не кэшируем.
    if (err instanceof Error && err.name === "AbortError") {
      return [];
    }
    throw err;
  }
  clearTimeout(timer);

  if (!res.ok) throw new Error(`Open Food Facts error ${res.status}`);
  const data = (await res.json()) as OffSearchResponse;
  const hits = data.hits ?? [];
  const tokens = queryTokens(query);

  const scored: NormalizedProduct[] = [];
  for (const p of hits) {
    const normalized = normalize(p, "", safeLang);
    if (!normalized) continue;
    const { product, searchHaystack } = normalized;
    // нужен код и хоть какие-то калории, иначе для лога бесполезно
    if (!product.code || product.per100g.calories === null) continue;
    // FOOD-26: запрос реально должен встречаться в каком-то из известных имён продукта
    if (!isRelevant(searchHaystack, tokens)) continue;
    scored.push(normalized);
  }

  // FOOD-28: продукты с именем на языке пользователя — выше остальных.
  // Array.prototype.sort стабилен (Node 11+) — относительный порядок (релевантность
  // по версии OFF) внутри каждой из двух групп сохраняется.
  scored.sort((a, b) => Number(b.hasLocalizedName) - Number(a.hasLocalizedName));

  const out = scored.slice(0, limit).map((s) => s.product);

  // Кэшируем только непустые результаты — не хотим фиксировать временные ошибки OFF.
  if (out.length > 0) {
    cacheSet(cacheKey, out);
  }

  return out;
}
