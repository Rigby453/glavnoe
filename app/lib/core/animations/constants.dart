// Глобальные константы анимаций — источник истины: /docs/ANIMATIONS.md (секция 0).
// Не менять duration/curve без правки ANIMATIONS.md.

import 'package:flutter/material.dart';

// --- Длительности (ANIMATIONS.md §0) ---

/// Мгновенный отклик (нажатие, scale down)
const kDurationSnap = Duration(milliseconds: 120);

/// Переходы (scale up, lift, crossfade)
const kDurationFast = Duration(milliseconds: 180);

/// Карточки, модалки, тосты
const kDurationNormal = Duration(milliseconds: 280);

/// Экраны, прогресс (кольцо, бары).
/// Ревью 2026-06-11: 400 → 300 мс — UI-переходы не дольше 300 мс
/// (деко-эффекты вроде конфетти/пульса — отдельно, см. ANIMATIONS.md §0).
const kDurationSlow = Duration(milliseconds: 300);

// --- Кривые (ANIMATIONS.md §0) ---

const kCurveSnap = Curves.easeOut;
const kCurveSpring = Curves.elasticOut; // spring-физика
const kCurveLift = Curves.easeOutCubic;
const kCurveSlide = Curves.easeInOutCubic;

// --- Доступность (ANIMATIONS.md §10) ---

/// true, если анимации должны быть отключены (reduce motion).
bool reduceMotionOf(BuildContext context) =>
    MediaQuery.of(context).disableAnimations;

/// Длительность с учётом reduce motion: при отключённых анимациях — Duration.zero.
Duration effectiveDuration(BuildContext context, Duration duration) =>
    reduceMotionOf(context) ? Duration.zero : duration;
