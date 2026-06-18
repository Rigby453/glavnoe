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
// Ключ: нормализованный запрос (trim+lowercase). Значение: результат + время вставки.
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

function normalize(p: OffProduct, fallbackCode: string): FoodProduct | null {
  const name = (p.product_name ?? "").trim();
  if (!name) return null; // продукт без названия бесполезен
  const n = p.nutriments ?? {};
  const rawBrand = Array.isArray(p.brands) ? p.brands[0] : p.brands?.split(",")[0];
  return {
    code: (p.code ?? fallbackCode).trim(),
    name,
    brand: rawBrand?.trim() || null,
    image: p.image_url?.trim() || null,
    per100g: {
      calories: num(n["energy-kcal_100g"]),
      protein: num(n.proteins_100g),
      fat: num(n.fat_100g),
      carbs: num(n.carbohydrates_100g),
      sugar: num(n.sugars_100g),
      fiber: num(n.fiber_100g),
    },
  };
}

const FIELDS = "code,product_name,brands,nutriments,image_url";

/** Поиск продукта по штрихкоду. null — не найден. */
export async function lookupBarcode(code: string): Promise<FoodProduct | null> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);
  try {
    const res = await fetch(
      `${OFF_BASE}/api/v2/product/${encodeURIComponent(code)}.json?fields=${FIELDS}`,
      { headers: { "User-Agent": USER_AGENT }, signal: controller.signal }
    );
    if (res.status === 404) return null;
    if (!res.ok) throw new Error(`Open Food Facts error ${res.status}`);
    const data = (await res.json()) as OffProductResponse;
    if (data.status !== 1 || !data.product) return null;
    return normalize(data.product, code);
  } finally {
    clearTimeout(timer);
  }
}

/** Текстовый поиск продуктов (до [limit]). */
export async function searchProducts(
  query: string,
  limit = 20
): Promise<FoodProduct[]> {
  // Нормализуем ключ кэша — независимо от регистра и пробелов по краям.
  const cacheKey = normalizeCacheKey(query);

  // Проверяем кэш до обращения к OFF.
  const cached = cacheGet(cacheKey);
  if (cached !== null) {
    // Срез до limit на случай если в кэше лежат результаты с другим limit'ом —
    // в текущей реализации limit всегда 20, но защищаемся явно.
    return cached.slice(0, limit);
  }

  const url =
    `${OFF_SEARCH_BASE}/search?q=${encodeURIComponent(query)}` +
    `&page_size=${limit}&fields=${FIELDS}`;

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
  const products = data.hits ?? [];
  const out: FoodProduct[] = [];
  for (const p of products) {
    const normalized = normalize(p, "");
    // нужен код и хоть какие-то калории, иначе для лога бесполезно
    if (normalized && normalized.code && normalized.per100g.calories !== null) {
      out.push(normalized);
    }
    if (out.length >= limit) break;
  }

  // Кэшируем только непустые результаты — не хотим фиксировать временные ошибки OFF.
  if (out.length > 0) {
    cacheSet(cacheKey, out);
  }

  return out;
}
