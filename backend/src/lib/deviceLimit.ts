/**
 * Лимит активных устройств/сессий на аккаунт — ADR-058.
 *
 * Стаб: хранилище in-memory (Map<userId, Set<deviceId>>).
 * Данные пропадают при рестарте процесса — это нормально для стаба.
 *
 * В production заменить на DB-таблицу:
 *
 *   // schema.prisma:
 *   model Device {
 *     id         String   @id @default(uuid())
 *     userId     String
 *     deviceId   String   // UUID устройства, генерируется клиентом
 *     platform   String?  // ios | android | web
 *     label      String?  // "iPhone 15 Pro", "MacBook Air"
 *     lastSeenAt DateTime @default(now()) @updatedAt
 *     createdAt  DateTime @default(now())
 *     user       User     @relation(fields: [userId], references: [id], onDelete: Cascade)
 *     @@unique([userId, deviceId])
 *     @@index([userId])
 *   }
 *
 *   // Логика в routes/auth.ts при каждом /login:
 *   const count = await prisma.device.count({ where: { userId } });
 *   if (count >= getDeviceLimit() && !existingDevice) { return 403; }
 *   await prisma.device.upsert({ where: { userId_deviceId: { userId, deviceId } }, ... });
 *
 *   // Добавить TTL: устройства без lastSeenAt > 30 дней удалять через cron.
 *
 * Env-переменные:
 *   DEVICE_LIMIT — максимум активных устройств (default: 5)
 */

/** Максимум активных устройств по умолчанию. */
export const DEFAULT_DEVICE_LIMIT = 5;

// In-memory хранилище: userId → Set<deviceId>
const deviceStore = new Map<string, Set<string>>();

/**
 * Возвращает максимально допустимое число устройств для аккаунта.
 * Читает DEVICE_LIMIT из env; при ошибке или нуле — DEFAULT_DEVICE_LIMIT.
 */
export function getDeviceLimit(): number {
  const val = parseInt(process.env["DEVICE_LIMIT"] ?? "", 10);
  return isNaN(val) || val <= 0 ? DEFAULT_DEVICE_LIMIT : val;
}

/**
 * Возвращает число активных устройств для userId.
 */
export function getDeviceCount(userId: string): number {
  return deviceStore.get(userId)?.size ?? 0;
}

/**
 * Возвращает список зарегистрированных deviceId для userId.
 */
export function getDeviceIds(userId: string): string[] {
  const set = deviceStore.get(userId);
  return set ? [...set] : [];
}

/**
 * Регистрирует устройство для userId.
 *
 * Идемпотентно: если deviceId уже зарегистрирован — счётчик не растёт.
 * Если лимит превышен и устройство новое — возвращает allowed=false
 * (вызывающий маршрут должен ответить 403).
 *
 * @returns { allowed, count } — разрешено ли + текущее число устройств
 */
export function registerDevice(
  userId: string,
  deviceId: string
): { allowed: boolean; count: number } {
  let set = deviceStore.get(userId);
  if (!set) {
    set = new Set<string>();
    deviceStore.set(userId, set);
  }

  // Уже зарегистрировано — идемпотентно, не увеличиваем счётчик
  if (set.has(deviceId)) {
    return { allowed: true, count: set.size };
  }

  const limit = getDeviceLimit();
  if (set.size >= limit) {
    return { allowed: false, count: set.size };
  }

  set.add(deviceId);
  return { allowed: true, count: set.size };
}

/**
 * Удаляет устройство (выход, деавторизация на устройстве).
 * Безопасно вызывать для несуществующего deviceId.
 */
export function removeDevice(userId: string, deviceId: string): void {
  const set = deviceStore.get(userId);
  if (set) {
    set.delete(deviceId);
    if (set.size === 0) {
      deviceStore.delete(userId);
    }
  }
}

/**
 * Удаляет все устройства userId (выход со всех устройств / сброс аккаунта).
 */
export function removeAllDevices(userId: string): void {
  deviceStore.delete(userId);
}

/**
 * Очищает всё хранилище.
 * Использовать ТОЛЬКО в тестах (NODE_ENV=test).
 */
export function clearDevices(): void {
  deviceStore.clear();
}
