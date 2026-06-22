/**
 * BUG A: defensive unwrap для PLAIN-TEXT AI-генераторов.
 * unwrapMaybeJson разворачивает случайный JSON {"key":"..."} обратно в текст,
 * иначе возвращает исходный (триммированный) текст.
 */
import { unwrapMaybeJson } from '../../backend/src/ai/textResponse';

test('returns the field value when text is JSON with the expected string key', () => {
  expect(unwrapMaybeJson('{"summary":"В этом месяце ты молодец"}', 'summary')).toBe(
    'В этом месяце ты молодец'
  );
  expect(unwrapMaybeJson('  {"insight": "You journal on Sundays."}  ', 'insight')).toBe(
    'You journal on Sundays.'
  );
});

test('returns plain text unchanged when it is not JSON', () => {
  expect(unwrapMaybeJson('Good morning — 2 tasks carried over.', 'message')).toBe(
    'Good morning — 2 tasks carried over.'
  );
});

test('trims surrounding whitespace on plain text', () => {
  expect(unwrapMaybeJson('   hello there   ', 'message')).toBe('hello there');
});

test('falls back to raw text when JSON lacks the expected key', () => {
  // валидный JSON, но без ключа message → отдаём как есть (триммированный)
  expect(unwrapMaybeJson('{"other":"x"}', 'message')).toBe('{"other":"x"}');
});

test('falls back to raw text when the key value is not a string', () => {
  expect(unwrapMaybeJson('{"summary": 42}', 'summary')).toBe('{"summary": 42}');
});

test('falls back to raw text on malformed JSON that starts with a brace', () => {
  const broken = '{"summary":"truncated...';
  expect(unwrapMaybeJson(broken, 'summary')).toBe(broken.trim());
});
