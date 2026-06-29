/**
 * Unit-тесты: deviceLimit (ADR-058).
 * Запуск: npx jest tests/unit/device-limit.test.ts --runInBand
 * Не требует БД, сетевых вызовов, переменных окружения.
 */

import {
  registerDevice,
  removeDevice,
  removeAllDevices,
  getDeviceCount,
  getDeviceIds,
  getDeviceLimit,
  clearDevices,
  DEFAULT_DEVICE_LIMIT,
} from "../../backend/src/lib/deviceLimit";

beforeEach(() => {
  clearDevices();
  delete process.env["DEVICE_LIMIT"];
});

afterEach(() => {
  clearDevices();
  delete process.env["DEVICE_LIMIT"];
});

// ────────────────────────────────────────────────────────────────────────────
// getDeviceLimit
// ────────────────────────────────────────────────────────────────────────────

describe("getDeviceLimit", () => {
  test("без env — возвращает DEFAULT_DEVICE_LIMIT (5)", () => {
    expect(getDeviceLimit()).toBe(DEFAULT_DEVICE_LIMIT);
    expect(DEFAULT_DEVICE_LIMIT).toBe(5);
  });

  test("DEVICE_LIMIT=3 → 3", () => {
    process.env["DEVICE_LIMIT"] = "3";
    expect(getDeviceLimit()).toBe(3);
  });

  test("DEVICE_LIMIT=1 → 1", () => {
    process.env["DEVICE_LIMIT"] = "1";
    expect(getDeviceLimit()).toBe(1);
  });

  test("DEVICE_LIMIT=abc (не число) → DEFAULT_DEVICE_LIMIT", () => {
    process.env["DEVICE_LIMIT"] = "abc";
    expect(getDeviceLimit()).toBe(DEFAULT_DEVICE_LIMIT);
  });

  test("DEVICE_LIMIT=0 → DEFAULT_DEVICE_LIMIT (0 не допустим)", () => {
    process.env["DEVICE_LIMIT"] = "0";
    expect(getDeviceLimit()).toBe(DEFAULT_DEVICE_LIMIT);
  });

  test("DEVICE_LIMIT=-1 → DEFAULT_DEVICE_LIMIT (отрицательное не допустимо)", () => {
    process.env["DEVICE_LIMIT"] = "-1";
    expect(getDeviceLimit()).toBe(DEFAULT_DEVICE_LIMIT);
  });
});

// ────────────────────────────────────────────────────────────────────────────
// registerDevice
// ────────────────────────────────────────────────────────────────────────────

describe("registerDevice", () => {
  test("первое устройство — разрешено", () => {
    const result = registerDevice("user-1", "device-a");
    expect(result.allowed).toBe(true);
    expect(result.count).toBe(1);
  });

  test("регистрация того же device-id идемпотентна — счётчик не растёт", () => {
    registerDevice("user-2", "device-b");
    const result = registerDevice("user-2", "device-b");
    expect(result.allowed).toBe(true);
    expect(result.count).toBe(1);
  });

  test("до лимита включительно — все разрешены", () => {
    for (let i = 1; i <= DEFAULT_DEVICE_LIMIT; i++) {
      const result = registerDevice("user-3", `device-${i}`);
      expect(result.allowed).toBe(true);
      expect(result.count).toBe(i);
    }
  });

  test("сверх лимита — отклонено", () => {
    for (let i = 1; i <= DEFAULT_DEVICE_LIMIT; i++) {
      registerDevice("user-4", `device-${i}`);
    }
    const result = registerDevice("user-4", "device-extra");
    expect(result.allowed).toBe(false);
    expect(result.count).toBe(DEFAULT_DEVICE_LIMIT);
  });

  test("разные userId независимы", () => {
    // user-a заполнен
    for (let i = 1; i <= DEFAULT_DEVICE_LIMIT; i++) {
      registerDevice("user-a", `device-${i}`);
    }
    expect(registerDevice("user-a", "extra").allowed).toBe(false);

    // user-b начинает с нуля
    expect(registerDevice("user-b", "device-1").allowed).toBe(true);
  });

  test("DEVICE_LIMIT из env соблюдается", () => {
    process.env["DEVICE_LIMIT"] = "2";
    registerDevice("user-env", "dev-1");
    registerDevice("user-env", "dev-2");
    const result = registerDevice("user-env", "dev-3");
    expect(result.allowed).toBe(false);
    expect(result.count).toBe(2);
  });

  test("после удаления устройства регистрация нового разрешена", () => {
    for (let i = 1; i <= DEFAULT_DEVICE_LIMIT; i++) {
      registerDevice("user-rem", `device-${i}`);
    }
    // лимит достигнут
    expect(registerDevice("user-rem", "extra").allowed).toBe(false);

    removeDevice("user-rem", "device-1");
    // теперь есть место
    const result = registerDevice("user-rem", "device-new");
    expect(result.allowed).toBe(true);
  });
});

// ────────────────────────────────────────────────────────────────────────────
// removeDevice
// ────────────────────────────────────────────────────────────────────────────

describe("removeDevice", () => {
  test("удаляет устройство и уменьшает счётчик", () => {
    registerDevice("user-5", "dev-a");
    registerDevice("user-5", "dev-b");
    expect(getDeviceCount("user-5")).toBe(2);

    removeDevice("user-5", "dev-a");
    expect(getDeviceCount("user-5")).toBe(1);
  });

  test("удаление несуществующего устройства безопасно (нет исключения)", () => {
    expect(() => removeDevice("user-x", "device-missing")).not.toThrow();
  });

  test("удаление последнего устройства → count = 0", () => {
    registerDevice("user-6", "dev-only");
    removeDevice("user-6", "dev-only");
    expect(getDeviceCount("user-6")).toBe(0);
  });
});

// ────────────────────────────────────────────────────────────────────────────
// removeAllDevices
// ────────────────────────────────────────────────────────────────────────────

describe("removeAllDevices", () => {
  test("удаляет все устройства userId", () => {
    registerDevice("user-7", "dev-a");
    registerDevice("user-7", "dev-b");
    registerDevice("user-7", "dev-c");
    removeAllDevices("user-7");
    expect(getDeviceCount("user-7")).toBe(0);
  });

  test("другой userId не затронут", () => {
    registerDevice("user-a", "dev-1");
    registerDevice("user-b", "dev-1");
    removeAllDevices("user-a");
    expect(getDeviceCount("user-a")).toBe(0);
    expect(getDeviceCount("user-b")).toBe(1);
  });

  test("removeAllDevices на несуществующем userId безопасен", () => {
    expect(() => removeAllDevices("user-nonexistent")).not.toThrow();
  });
});

// ────────────────────────────────────────────────────────────────────────────
// getDeviceCount & getDeviceIds
// ────────────────────────────────────────────────────────────────────────────

describe("getDeviceCount & getDeviceIds", () => {
  test("getDeviceCount для нового userId = 0", () => {
    expect(getDeviceCount("user-unknown")).toBe(0);
  });

  test("getDeviceCount отражает текущее число устройств", () => {
    registerDevice("user-cnt", "dev-1");
    registerDevice("user-cnt", "dev-2");
    expect(getDeviceCount("user-cnt")).toBe(2);
  });

  test("getDeviceIds возвращает зарегистрированные ID", () => {
    registerDevice("user-ids", "dev-1");
    registerDevice("user-ids", "dev-2");
    const ids = getDeviceIds("user-ids");
    expect(ids).toHaveLength(2);
    expect(ids).toContain("dev-1");
    expect(ids).toContain("dev-2");
  });

  test("getDeviceIds для неизвестного userId → пустой массив", () => {
    expect(getDeviceIds("user-unknown")).toEqual([]);
  });

  test("getDeviceIds не включает удалённые устройства", () => {
    registerDevice("user-del", "dev-a");
    registerDevice("user-del", "dev-b");
    removeDevice("user-del", "dev-a");
    const ids = getDeviceIds("user-del");
    expect(ids).not.toContain("dev-a");
    expect(ids).toContain("dev-b");
  });
});
