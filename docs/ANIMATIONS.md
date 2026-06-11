# «Главное» — ТЗ на анимации (v1)

> Flutter-реализация. Каждый блок: триггер → что происходит → длительность → кривая → Flutter-реализация.
> Принцип: анимация только там где она передаёт информацию. Нет декора ради декора.

---

## 0. Глобальные константы

```dart
// durations
const kDurationSnap     = Duration(milliseconds: 120); // мгновенный отклик
const kDurationFast     = Duration(milliseconds: 180); // переходы
const kDurationNormal   = Duration(milliseconds: 280); // карточки, модалки
const kDurationSlow     = Duration(milliseconds: 300); // экраны, прогресс (максимум!)

// curves
const kCurveSnap        = Curves.easeOut;
const kCurveSpring      = Curves.elasticOut;  // spring-физика
const kCurveLift        = Curves.easeOutCubic;
const kCurveSlide       = Curves.easeInOutCubic;
```

> **Правило таймингов (ревью 2026-06-11):** любой UI-переход — 120–300 мс,
> НИГДЕ не дольше. Исключение — деко-эффекты, которые не блокируют интерфейс:
> физика конфетти (§5), бесконечные циклы пульса/шиммера (§7.1/§7.2) —
> это не переходы, а фоновые петли/частицы. Было slow=400, ушито до 300.

---

## 1. Кнопки и карточки — базовые состояния

### 1.1 Lift (карточки задач, карточки еды)
**Что сообщает:** «этот элемент кликабельный»

| Параметр | Значение |
|---|---|
| Триггер | hover / focus |
| Transform | `translateY(-2px)` |
| Duration | 180 мс |
| Curve | `easeOutCubic` |
| Flutter | `AnimatedContainer` + `GestureDetector` / `MouseRegion` |

```dart
AnimatedContainer(
  duration: kDurationFast,
  curve: kCurveLift,
  transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
  child: child,
)
```

---

### 1.2 Scale при нажатии (все интерактивные карточки)
**Что сообщает:** «действие зарегистрировано»

| Параметр | Значение |
|---|---|
| Триггер | `onTapDown` → `onTapUp` / `onTapCancel` |
| Scale down | `0.97` (нажатие) |
| Scale up | `1.0` (отпускание) |
| Duration down | 120 мс |
| Duration up | 180 мс |
| Curve | `easeOut` |

```dart
GestureDetector(
  onTapDown: (_) => setState(() => _pressed = true),
  onTapUp: (_) => setState(() => _pressed = false),
  onTapCancel: () => setState(() => _pressed = false),
  child: AnimatedScale(
    scale: _pressed ? 0.97 : 1.0,
    duration: _pressed ? kDurationSnap : kDurationFast,
    curve: kCurveSnap,
    child: child,
  ),
)
```

---

### 1.3 Scale — карточки тренировок (выбор варианта)
**Что сообщает:** «ты выбрал именно этот»

| Состояние | Scale |
|---|---|
| Обычное | `1.0` |
| Hover / focus | `1.04` |
| Нажатие | `0.96` |
| Duration | 150 мс |

---

### 1.4 Ripple — кнопки действий (мобильный)
**Что сообщает:** «нажатие засчитано, вот откуда»
- Стандартный `InkWell` / `InkResponse` Flutter
- Цвет ripple: `theme.colorScheme.onSurface.withOpacity(0.08)`
- Радиус волны = диаметру элемента

---

## 2. Задачи

### 2.1 Добавление задачи — влёт справа
**Что сообщает:** «новый элемент появился в списке»

| Параметр | Значение |
|---|---|
| Триггер | FAB [+] → задача сохранена |
| Начало | `translateX(+100%)`, `opacity: 0` |
| Конец | `translateX(0)`, `opacity: 1` |
| Duration | 280 мс |
| Curve | `easeOutCubic` |

```dart
SlideTransition(
  position: Tween<Offset>(
    begin: const Offset(1.0, 0),
    end: Offset.zero,
  ).animate(CurvedAnimation(
    parent: _controller,
    curve: kCurveSlide,
  )),
  child: FadeTransition(opacity: _fadeAnim, child: taskCard),
)
```

---

### 2.2 Удаление задачи — свайп влево
**Что сообщает:** «элемент удалён, можно отменить»

| Параметр | Значение |
|---|---|
| Триггер | свайп влево завершён |
| Анимация карточки | уезжает влево (`translateX(-100%)`) + fade out |
| Duration | 220 мс |
| Curve | `easeInCubic` |
| Flutter | `Dismissible` widget |

```dart
Dismissible(
  key: Key(task.id),
  direction: DismissDirection.endToStart,
  movementDuration: const Duration(milliseconds: 220),
  onDismissed: (_) => _showUndoToast(task),
  child: taskCard,
)
```

---

### 2.3 Галочка при отметке выполнения
**Что сообщает:** «действие засчитано»

| Параметр | Значение |
|---|---|
| Триггер | тап на чекбокс |
| Анимация | галочка рисуется (path animation) + круг заполняется |
| Duration | 200 мс |
| Дополнительно | текст задачи получает `strikethrough` с fade |
| Curve | `easeOut` |

Используй пакет `animated_checkmark` или кастомный `CustomPainter` с `Path` анимацией.

---

## 3. Тосты (Toasts / Plashки)

### Общее поведение всех тостов
- Появляются **снизу**, поднимаясь вверх
- Висят **3–4 секунды**, потом уходят вниз
- Максимум 1 тост одновременно
- Отступ от нижней навигации: 16px

| Параметр | Появление | Исчезновение |
|---|---|---|
| Transform | `translateY(+80px) → 0` | `0 → translateY(+80px)` |
| Opacity | `0 → 1` | `1 → 0` |
| Duration | 280 мс | 220 мс |
| Curve | `easeOutCubic` | `easeInCubic` |

---

### 3.1 Тост: задача выполнена (зелёный)
```
✓  "Done! Great work."
```
- Цвет фона: `#1D9E75` (success green)
- Иконка: галочка слева
- Триггер: чекбокс задачи отмечен

---

### 3.2 Тост: напоминание о дедлайне (оранжевый)
```
⏰  "1 hour until: Сдать реферат"
```
- Цвет фона: `#FF6A3D` (ember)
- Иконка: часы слева
- Триггер: push-уведомление за 1 час до дедлайна → тост если приложение открыто

---

### 3.3 Тост: задача удалена (серый + кнопка Отмена)
```
🗑  "Task removed"    [Undo]
```
- Цвет фона: поверхность темы + border
- Кнопка `[Undo]` справа — тап возвращает задачу с влётом справа (п. 2.1)
- Таймер отмены: 4 секунды
- Триггер: свайп-удаление завершено

---

## 4. Прогресс и кольца

### 4.1 Кольцо «главное закрыто» (Today)
| Параметр | Значение |
|---|---|
| Триггер | каждый чек задачи из «Главного» |
| Анимация | дуга плавно удлиняется до нового % |
| При 100% | пружина — кольцо чуть «перескакивает» на 105% и возвращается |
| Duration дуги | 300 мс |
| Duration пружины | 300 мс |
| Curve дуги | `easeOutCubic` |
| Curve пружины | `elasticOut` (amplitude 0.5) |
| Flutter | `CustomPainter` + `AnimationController` |

```dart
// При 100%: tweenSequence
TweenSequence([
  TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.05), weight: 30),
  TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 70),
])
```

---

### 4.2 Прогресс-бар воды
| Параметр | Значение |
|---|---|
| Триггер | тап на стакан (+ объём воды) |
| Анимация | полоса плавно растёт до нового % |
| Duration | 300 мс |
| Curve | `easeOutCubic` |
| При 100% | задержка 600 мс → появляется тост «Норма воды выполнена 💧» |
| Flutter | `AnimatedFractionallySizedBox` или `TweenAnimationBuilder` |

```dart
TweenAnimationBuilder<double>(
  tween: Tween(begin: _prev, end: _current),
  duration: kDurationSlow,
  curve: kCurveLift,
  builder: (_, value, __) => FractionallySizedBox(
    widthFactor: value,
    child: waterBar,
  ),
)
```

---

## 5. Экран «День завершён»

**Когда:** последняя задача из «Главного» закрыта.

| Слой | Анимация | Задержка | Duration |
|---|---|---|---|
| Фон | fade in зелёный оверлей `#1D9E75 @ 95%` | 0 мс | 300 мс |
| Галочка | path draw (рисуется) + scale `0 → 1` с пружиной | 200 мс | 300 мс |
| Заголовок | fade up снизу | 350 мс | 280 мс |
| Конфетти | burst из центра, физика (гравитация вниз) — деко, не переход | 300 мс | 2000 мс |
| Стрик +1 | счётчик подпрыгивает (scale 1 → 1.3 → 1) | 500 мс | 300 мс |
| Закрытие | тап или 4 сек → fade out | — | 300 мс |

Flutter: пакет `confetti` для конфетти. Оверлей через `OverlayEntry`.

```dart
// Стрик +1
TweenSequence([
  TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 40),
  TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 60),
])
```

---

## 6. Достижения (Achievement badge)

**Триггеры:** стрик 7/14/30 дней, рекорд недели, первая тренировка, первый wrapped.

| Параметр | Значение |
|---|---|
| Появление | падает сверху с пружиной |
| Начало | `translateY(-120px)`, `opacity: 0` |
| Конец | `translateY(0)`, `opacity: 1` |
| Duration | 300 мс |
| Curve | `elasticOut` (имитация пружины) |
| Позиция | верх экрана, под status bar, по центру |
| Висит | 3 секунды |
| Уход | уезжает вверх, 200 мс, `easeInCubic` |

```dart
SlideTransition(
  position: Tween<Offset>(
    begin: const Offset(0, -1.5),
    end: Offset.zero,
  ).animate(CurvedAnimation(
    parent: _controller,
    curve: Curves.elasticOut,
  )),
  child: achievementBadge,
)
```

---

## 7. ИИ-раздел

### 7.1 Pulse — индикатор анализа
| Параметр | Значение |
|---|---|
| Триггер | ИИ начал обработку |
| Анимация | зелёная точка пульсирует (scale + opacity кольца) |
| Цикл | бесконечный пока идёт запрос |
| Duration цикла | 1400 мс |
| Curve | `easeInOut` |
| Остановка | запрос завершён → fade out точки |

```dart
RepaintBoundary(
  child: AnimatedBuilder(
    animation: _pulseController,
    builder: (_, __) => Stack(children: [
      // внешнее кольцо
      Opacity(
        opacity: (1 - _pulseController.value).clamp(0.0, 0.8),
        child: Transform.scale(
          scale: 1.0 + _pulseController.value * 0.7,
          child: pulseDot,
        ),
      ),
      // центральная точка
      pulseDot,
    ]),
  ),
)
```

---

### 7.2 Skeleton — загрузка инсайта
| Параметр | Значение |
|---|---|
| Триггер | запрос к ИИ отправлен, ответ не пришёл |
| Анимация | shimmer слева направо по блокам-заглушкам |
| Duration цикла | 1400 мс |
| Gradient | `#surface → #border → #surface`, `background-size: 200%` |
| Замена | skeleton исчезает (fade out 200 мс), появляется контент (fade in 280 мс) |

Используй пакет `shimmer` или кастомный `AnimatedBuilder` + `LinearGradient`.

---

### 7.3 Fade-in инсайта
| Параметр | Значение |
|---|---|
| Триггер | ИИ-текст получен |
| Анимация | `opacity: 0 → 1` + `translateY(+8px → 0)` |
| Duration | 300 мс |
| Curve | `easeOutCubic` |
| Задержка | 100 мс после появления контейнера |

---

## 8. Навигация и модалки

### 8.1 Смена вкладок (Tab bar)
- Быстрый crossfade: `opacity` старого `1→0` + нового `0→1`
- Duration: 150 мс
- Без slide — вкладки не имеют пространственной иерархии

### 8.2 Модалки (bottom sheets)
- Spring снизу: `translateY(100% → 0)`
- Duration: 300 мс
- Curve: `Curves.easeOutCubic`
- Backdrop: fade in `0 → 0.5 opacity`
- Закрытие: `translateY(0 → 100%)`, 220 мс, `easeInCubic`

### 8.3 Полноэкранный «Разбор дня»
- Карточки складываются: каждая улетает вверх с задержкой +40мс
- Duration каждой: 280 мс
- Curve: `easeInCubic`

---

## 9. Что намеренно без анимации

| Элемент | Почему статично |
|---|---|
| Стрик (счётчик дней) | Не нужно привлекать внимание постоянно |
| Текст и заголовки | Появляются мгновенно — не путаем с контентом |
| Переключатель тона (тумблер) | Стандартный Switch, пользователь знает паттерн |
| Нижняя навигация | Иконки без анимации — скорость важнее |
| Числа КБЖУ | Обновляются мгновенно, анимация отвлекает |

---

## 10. Доступность

Все анимации отключаются если `MediaQuery.of(context).disableAnimations == true` или включён режим **Contrast** (тема B2.5 ТЗ).

```dart
final reduce = MediaQuery.of(context).disableAnimations;
final duration = reduce ? Duration.zero : kDurationNormal;
```

---

## Приоритет реализации

| Фаза | Анимации |
|---|---|
| **MVP** | Scale/Lift карточек, тосты (все 3), галочка задачи, кольцо Today, смена вкладок, модалки |
| **Ф1** | Экран «День завершён» + конфетти, прогресс-бар воды, skeleton + pulse ИИ |
| **Ф2** | Достижения (badge), fade-in инсайта, влёт/вылет задач |
