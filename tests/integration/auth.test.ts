/**
 * QA-01: Auth flow — регистрация, вход, /me (ADR-031: 406-ФЗ)
 *
 * Покрывает:
 *  - регистрация/логин по email (только российские домены)
 *  - регистрация/логин по телефону (E.164 нормализация)
 *  - запрет иностранных email-доменов
 *  - запрет нескольких/отсутствующих идентификаторов
 *  - дублирование email и phone → 409
 *  - /me с токеном и без
 */
import { buildServer } from '../../backend/src/app';
import type { FastifyInstance } from 'fastify';
import { randomEmail, randomPhone, cleanupUser } from '../helpers';

let app: FastifyInstance;
// Список userId для очистки после всех тестов
const userIdsToCleanup: string[] = [];

beforeAll(async () => {
  app = await buildServer();
  await app.ready();
});

afterAll(async () => {
  // Очищаем всех созданных пользователей
  for (const userId of userIdsToCleanup) {
    await cleanupUser(userId);
  }
  await app.close();
});

// ---------------------------------------------------------------------------
// POST /api/v1/auth/register — email-путь
// ---------------------------------------------------------------------------

describe('POST /api/v1/auth/register — email', () => {
  test('register by email → 201, returns { access_token, user: { id, email, phone, name } }', async () => {
    const email = randomEmail();
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/register',
      payload: { email, password: 'TestPass1!', name: 'Alice' },
    });

    expect(res.statusCode).toBe(201);
    const body = res.json<{
      access_token: string;
      user: { id: string; email: string | null; phone: string | null; name: string };
    }>();
    expect(typeof body.access_token).toBe('string');
    expect(body.access_token.length).toBeGreaterThan(0);
    expect(body.user.id).toBeDefined();
    expect(body.user.email).toBe(email);
    // При email-регистрации phone должен быть null
    expect(body.user.phone).toBeNull();
    expect(body.user.name).toBe('Alice');
    // passwordHash никогда не должен утекать
    expect((body.user as Record<string, unknown>)['passwordHash']).toBeUndefined();
    expect((body.user as Record<string, unknown>)['password_hash']).toBeUndefined();

    userIdsToCleanup.push(body.user.id);
  });

  test('duplicate email → 409 { error: "Email or phone already exists" }', async () => {
    const email = randomEmail();

    // Первая регистрация
    const first = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/register',
      payload: { email, password: 'TestPass1!', name: 'Alice' },
    });
    expect(first.statusCode).toBe(201);
    const firstBody = first.json<{ user: { id: string } }>();
    userIdsToCleanup.push(firstBody.user.id);

    // Дубликат — новое сообщение согласно ADR-031
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/register',
      payload: { email, password: 'AnotherPass1!', name: 'Bob' },
    });
    expect(res.statusCode).toBe(409);
    const body = res.json<{ error: string }>();
    expect(body.error).toBe('Email or phone already exists');
  });

  // Любая почта разрешена по умолчанию (406-ФЗ про OAuth-сервисы, не про адрес-строку).
  // Ограничить можно через env ALLOWED_EMAIL_DOMAINS.
  test('foreign email domain (gmail.com) → allowed (201)', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/register',
      payload: {
        email: `gmail_${Date.now()}@gmail.com`,
        password: 'TestPass1!',
        name: 'Foreign User',
      },
    });
    expect(res.statusCode).toBe(201);
    const body = res.json<{ access_token?: string }>();
    expect(typeof body.access_token).toBe('string');
  });

  test('another foreign domain (example.com) → allowed (201)', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/register',
      payload: {
        email: `ex_${Date.now()}@example.com`,
        password: 'TestPass1!',
        name: 'Example User',
      },
    });
    expect(res.statusCode).toBe(201);
  });
});

// ---------------------------------------------------------------------------
// POST /api/v1/auth/register — phone-путь
// ---------------------------------------------------------------------------

describe('POST /api/v1/auth/register — phone', () => {
  test('register by phone (8XXXXXXXXXX input) → 201; user.phone normalized to +7XXXXXXXXXX; user.email is null', async () => {
    // Отправляем в формате 8... — бэкенд должен нормализовать до +7...
    const rawPhone = randomPhone().replace(/^\+7/, '8'); // +79XXXXXXXXX → 89XXXXXXXXX
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/register',
      payload: { phone: rawPhone, password: 'TestPass1!', name: 'PhoneUser' },
    });

    expect(res.statusCode).toBe(201);
    const body = res.json<{
      access_token: string;
      user: { id: string; email: string | null; phone: string | null; name: string };
    }>();
    expect(typeof body.access_token).toBe('string');
    expect(body.user.id).toBeDefined();
    // Нормализован в E.164: +7...
    expect(body.user.phone).toMatch(/^\+7\d{10}$/);
    // При phone-регистрации email должен быть null
    expect(body.user.email).toBeNull();
    // passwordHash не должен утекать
    expect((body.user as Record<string, unknown>)['passwordHash']).toBeUndefined();

    userIdsToCleanup.push(body.user.id);
  });

  test('register by phone (+7XXXXXXXXXX input) → 201', async () => {
    const phone = randomPhone(); // уже в формате +7...
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/register',
      payload: { phone, password: 'TestPass1!', name: 'PhoneUser2' },
    });

    expect(res.statusCode).toBe(201);
    const body = res.json<{ user: { id: string; phone: string | null } }>();
    expect(body.user.phone).toBe(phone);

    userIdsToCleanup.push(body.user.id);
  });

  test('duplicate phone → 409 { error: "Email or phone already exists" }', async () => {
    const phone = randomPhone();

    // Первая регистрация
    const first = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/register',
      payload: { phone, password: 'TestPass1!', name: 'PhoneDup1' },
    });
    expect(first.statusCode).toBe(201);
    const firstBody = first.json<{ user: { id: string } }>();
    userIdsToCleanup.push(firstBody.user.id);

    // Дубликат
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/register',
      payload: { phone, password: 'AnotherPass1!', name: 'PhoneDup2' },
    });
    expect(res.statusCode).toBe(409);
    const body = res.json<{ error: string }>();
    expect(body.error).toBe('Email or phone already exists');
  });

  test('malformed phone (12345) → 400', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/register',
      payload: { phone: '12345', password: 'TestPass1!', name: 'Bad Phone' },
    });
    expect(res.statusCode).toBe(400);
  });
});

// ---------------------------------------------------------------------------
// POST /api/v1/auth/register — валидация идентификаторов
// ---------------------------------------------------------------------------

describe('POST /api/v1/auth/register — identifier validation', () => {
  test('register with BOTH email and phone → 400', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/register',
      payload: {
        email: randomEmail(),
        phone: randomPhone(),
        password: 'TestPass1!',
        name: 'BothUser',
      },
    });
    expect(res.statusCode).toBe(400);
    const body = res.json<{ error: string }>();
    expect(typeof body.error).toBe('string');
  });

  test('register with NEITHER email nor phone → 400', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/register',
      payload: { password: 'TestPass1!', name: 'NoIdentifier' },
    });
    expect(res.statusCode).toBe(400);
    const body = res.json<{ error: string }>();
    expect(typeof body.error).toBe('string');
  });
});

// ---------------------------------------------------------------------------
// POST /api/v1/auth/login
// ---------------------------------------------------------------------------

describe('POST /api/v1/auth/login — email', () => {
  let loginEmail: string;
  const loginPassword = 'LoginPass1!';

  beforeAll(async () => {
    loginEmail = randomEmail();
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/register',
      payload: { email: loginEmail, password: loginPassword, name: 'Login User' },
    });
    const body = res.json<{ user: { id: string } }>();
    userIdsToCleanup.push(body.user.id);
  });

  test('login by email correct → 200, returns JWT', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/login',
      payload: { email: loginEmail, password: loginPassword },
    });
    expect(res.statusCode).toBe(200);
    const body = res.json<{ access_token: string; user: { email: string } }>();
    expect(typeof body.access_token).toBe('string');
    expect(body.access_token.length).toBeGreaterThan(0);
    expect(body.user.email).toBe(loginEmail);
  });

  test('login wrong password → 401', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/login',
      payload: { email: loginEmail, password: 'WrongPassword!' },
    });
    expect(res.statusCode).toBe(401);
  });

  test('login unknown email → 401', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/login',
      // Используем yandex.ru — разрешённый домен, но пользователь не существует
      payload: { email: 'nonexistent@yandex.ru', password: 'AnyPass123!' },
    });
    expect(res.statusCode).toBe(401);
  });
});

describe('POST /api/v1/auth/login — phone', () => {
  let registeredPhone: string; // нормализованный +7...
  const phonePassword = 'PhoneLogin1!';
  let phoneUserId: string;

  beforeAll(async () => {
    registeredPhone = randomPhone(); // +79XXXXXXXXX
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/register',
      payload: { phone: registeredPhone, password: phonePassword, name: 'PhoneLoginUser' },
    });
    const body = res.json<{ user: { id: string } }>();
    phoneUserId = body.user.id;
    userIdsToCleanup.push(phoneUserId);
  });

  test('login by phone (+7... form) → 200, same user', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/login',
      payload: { phone: registeredPhone, password: phonePassword },
    });
    expect(res.statusCode).toBe(200);
    const body = res.json<{ access_token: string; user: { id: string; phone: string | null } }>();
    expect(typeof body.access_token).toBe('string');
    expect(body.user.id).toBe(phoneUserId);
    expect(body.user.phone).toBe(registeredPhone);
  });

  test('login by phone (8... form of the same number) → 200, same user', async () => {
    // Конвертируем +7XXXXXXXXXX → 8XXXXXXXXXX и проверяем нормализацию при логине
    const eightForm = registeredPhone.replace(/^\+7/, '8');
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/login',
      payload: { phone: eightForm, password: phonePassword },
    });
    expect(res.statusCode).toBe(200);
    const body = res.json<{ user: { id: string } }>();
    expect(body.user.id).toBe(phoneUserId);
  });

  test('login by phone wrong password → 401', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/login',
      payload: { phone: registeredPhone, password: 'WrongPass999!' },
    });
    expect(res.statusCode).toBe(401);
  });

  test('login by malformed phone → 401', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/login',
      payload: { phone: '12345', password: phonePassword },
    });
    expect(res.statusCode).toBe(401);
  });
});

// ---------------------------------------------------------------------------
// GET /api/v1/auth/me
// ---------------------------------------------------------------------------

describe('GET /api/v1/auth/me', () => {
  let token: string;
  let userId: string;
  let userEmail: string;

  beforeAll(async () => {
    userEmail = randomEmail();
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/register',
      payload: { email: userEmail, password: 'MePass1234!', name: 'Me User' },
    });
    const body = res.json<{ access_token: string; user: { id: string } }>();
    token = body.access_token;
    userId = body.user.id;
    userIdsToCleanup.push(userId);
  });

  test('valid JWT → 200, user object (no passwordHash field)', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/auth/me',
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(res.statusCode).toBe(200);
    const body = res.json<Record<string, unknown>>();
    expect(body['id']).toBe(userId);
    expect(body['email']).toBe(userEmail);
    expect(body['name']).toBe('Me User');
    // passwordHash не должен присутствовать
    expect(body['passwordHash']).toBeUndefined();
    expect(body['password_hash']).toBeUndefined();
  });

  test('no token → 401', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/auth/me',
    });
    expect(res.statusCode).toBe(401);
  });

  test('garbage token → 401', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/auth/me',
      headers: { Authorization: 'Bearer thisisnotavalidjwt' },
    });
    expect(res.statusCode).toBe(401);
  });
});

// ---------------------------------------------------------------------------
// PATCH /api/v1/auth/me — профиль (ADR-062: антропометрия + цели питания/воды,
// синк между устройствами вместо SharedPreferences-only)
// ---------------------------------------------------------------------------

describe('PATCH /api/v1/auth/me — profile sync fields (ADR-062)', () => {
  let token: string;
  let userId: string;

  beforeAll(async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/register',
      payload: { email: randomEmail(), password: 'ProfilePass1!', name: 'Profile User' },
    });
    const body = res.json<{ access_token: string; user: { id: string } }>();
    token = body.access_token;
    userId = body.user.id;
    userIdsToCleanup.push(userId);
  });

  test('new profile fields default to null/false on GET /me', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/auth/me',
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(res.statusCode).toBe(200);
    const body = res.json<Record<string, unknown>>();
    expect(body['weight_kg']).toBeNull();
    expect(body['calorie_goal']).toBeNull();
    expect(body['water_goal_ml']).toBeNull();
    expect(body['macro_override_enabled']).toBe(false);
  });

  test('PATCH writes anthropometry + calorie/water goals → 200; GET returns them', async () => {
    const patchRes = await app.inject({
      method: 'PATCH',
      url: '/api/v1/auth/me',
      headers: { Authorization: `Bearer ${token}` },
      payload: {
        weight_kg: 68.5,
        height_cm: 174,
        age_years: 21,
        sex: 'male',
        activity_level: 'medium',
        food_goal: 'lose',
        calorie_goal: 2100,
        water_goal_ml: 2500,
      },
    });
    expect(patchRes.statusCode).toBe(200);
    const patchBody = patchRes.json<Record<string, unknown>>();
    expect(patchBody['weight_kg']).toBe(68.5);
    expect(patchBody['height_cm']).toBe(174);
    expect(patchBody['age_years']).toBe(21);
    expect(patchBody['sex']).toBe('male');
    expect(patchBody['activity_level']).toBe('medium');
    expect(patchBody['food_goal']).toBe('lose');
    expect(patchBody['calorie_goal']).toBe(2100);
    expect(patchBody['water_goal_ml']).toBe(2500);

    // GET reflects the same values (server is the source of truth for a new device)
    const getRes = await app.inject({
      method: 'GET',
      url: '/api/v1/auth/me',
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(getRes.statusCode).toBe(200);
    const getBody = getRes.json<Record<string, unknown>>();
    expect(getBody['calorie_goal']).toBe(2100);
    expect(getBody['water_goal_ml']).toBe(2500);
  });

  test('PATCH manual macro override → 200; GET returns macro_override_enabled + targets', async () => {
    const patchRes = await app.inject({
      method: 'PATCH',
      url: '/api/v1/auth/me',
      headers: { Authorization: `Bearer ${token}` },
      payload: {
        macro_override_enabled: true,
        macro_kcal_target: 2200,
        macro_protein_g: 150,
        macro_fat_g: 70,
        macro_carbs_g: 220,
      },
    });
    expect(patchRes.statusCode).toBe(200);
    const body = patchRes.json<Record<string, unknown>>();
    expect(body['macro_override_enabled']).toBe(true);
    expect(body['macro_kcal_target']).toBe(2200);
    expect(body['macro_protein_g']).toBe(150);
    expect(body['macro_fat_g']).toBe(70);
    expect(body['macro_carbs_g']).toBe(220);
  });

  test('PATCH out-of-range value (calorie_goal too low) → 400', async () => {
    const res = await app.inject({
      method: 'PATCH',
      url: '/api/v1/auth/me',
      headers: { Authorization: `Bearer ${token}` },
      payload: { calorie_goal: 100 },
    });
    expect(res.statusCode).toBe(400);
  });

  test('PATCH invalid enum (sex) → 400', async () => {
    const res = await app.inject({
      method: 'PATCH',
      url: '/api/v1/auth/me',
      headers: { Authorization: `Bearer ${token}` },
      payload: { sex: 'unknown' },
    });
    expect(res.statusCode).toBe(400);
  });
});
