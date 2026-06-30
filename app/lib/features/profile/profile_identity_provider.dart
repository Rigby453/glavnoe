// Локальная "личность" профиля: отображаемое имя + выбранный аватар-пресет.
//
// Зачем отдельно от currentUserProvider (api.me()): имя аккаунта приходит с
// бэкенда и сейчас НЕ редактируется (PATCH /api/v1/auth/me поддерживает только
// onboarding_done — см. /docs/api-spec.yaml). Поэтому пользовательское
// переопределение имени и аватар храним локально (SharedPreferences), по
// образцу остальных core/settings/*_provider.dart (mascot_provider и т.д.).
//
// TODO(profile-name-sync): когда в API появится поле `name` в PATCH /auth/me,
// добавить вызов api.updateProfile(name: ...) в setDisplayName() ниже, чтобы
// синхронизировать имя между устройствами (сейчас — устройство-локально).
// Это НЕ блокирует офлайн-режим: переопределение работает без аккаунта.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/theme_provider.dart'; // sharedPreferencesProvider

// ---------------------------------------------------------------------------
// Аватар-пресеты
// ---------------------------------------------------------------------------

/// Набор безобидных пресетов-аватаров (без доступа к галерее/камере — не
/// тянем дополнительных разрешений для смены аватара). Первый — дефолт,
/// визуально совпадает с прежней иконкой-заглушкой профиля.
enum AvatarPreset {
  defaultAvatar,
  cat,
  dog,
  bird,
  fish,
  leaf,
  rocket,
  star,
  sun,
}

extension AvatarPresetX on AvatarPreset {
  /// Иконка пресета (рисуется в акцентном кружке текущей темы — см. _AvatarCircle).
  PhosphorIconData icon([PhosphorIconsStyle style = PhosphorIconsStyle.fill]) =>
      switch (this) {
        AvatarPreset.defaultAvatar => PhosphorIcons.user(style),
        AvatarPreset.cat => PhosphorIcons.cat(style),
        AvatarPreset.dog => PhosphorIcons.dog(style),
        AvatarPreset.bird => PhosphorIcons.bird(style),
        AvatarPreset.fish => PhosphorIcons.fish(style),
        AvatarPreset.leaf => PhosphorIcons.leaf(style),
        AvatarPreset.rocket => PhosphorIcons.rocket(style),
        AvatarPreset.star => PhosphorIcons.star(style),
        AvatarPreset.sun => PhosphorIcons.sun(style),
      };

  /// Ключ для хранения в SharedPreferences.
  String get storageKey => name;

  static AvatarPreset fromKey(String? key) => AvatarPreset.values.firstWhere(
        (a) => a.name == key,
        orElse: () => AvatarPreset.defaultAvatar,
      );
}

// ---------------------------------------------------------------------------
// Состояние: имя + аватар
// ---------------------------------------------------------------------------

class ProfileIdentity {
  const ProfileIdentity({this.displayName, this.avatar = AvatarPreset.defaultAvatar});

  /// Локальное переопределение имени. null/пусто → используем имя аккаунта
  /// (или дефолтную подпись "You" / "Offline mode" — резолвится в UI).
  final String? displayName;

  final AvatarPreset avatar;

  ProfileIdentity copyWith({String? displayName, AvatarPreset? avatar}) =>
      ProfileIdentity(
        displayName: displayName ?? this.displayName,
        avatar: avatar ?? this.avatar,
      );

  @override
  bool operator ==(Object other) =>
      other is ProfileIdentity &&
      other.displayName == displayName &&
      other.avatar == avatar;

  @override
  int get hashCode => Object.hash(displayName, avatar);
}

const _kDisplayNameKey = 'profile_display_name';
const _kAvatarKey = 'profile_avatar_preset';

/// Максимальная длина имени (защита от overflow в шапке/строках профиля —
/// текст всё равно укорачивается ellipsis, но не даём вводить абсурдно длинные
/// строки).
const int kProfileDisplayNameMaxLength = 40;

class ProfileIdentityNotifier extends Notifier<ProfileIdentity> {
  @override
  ProfileIdentity build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final storedName = prefs.getString(_kDisplayNameKey);
    final storedAvatar = prefs.getString(_kAvatarKey);
    return ProfileIdentity(
      displayName: (storedName != null && storedName.trim().isNotEmpty)
          ? storedName.trim()
          : null,
      avatar: AvatarPresetX.fromKey(storedAvatar),
    );
  }

  /// Сохранить новое отображаемое имя. Пустая строка / null сбрасывает
  /// переопределение — UI вернётся к имени аккаунта (или дефолту).
  Future<void> setDisplayName(String? name) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await prefs.remove(_kDisplayNameKey);
      // copyWith() трактует null как "не менять", поэтому сброс задаём
      // через прямой конструктор, а не через copyWith(displayName: null).
      state = ProfileIdentity(displayName: null, avatar: state.avatar);
      return;
    }
    final clipped = trimmed.length > kProfileDisplayNameMaxLength
        ? trimmed.substring(0, kProfileDisplayNameMaxLength)
        : trimmed;
    await prefs.setString(_kDisplayNameKey, clipped);
    state = ProfileIdentity(displayName: clipped, avatar: state.avatar);
    // TODO(profile-name-sync): синк с бэкендом, см. комментарий в шапке файла.
  }

  Future<void> setAvatar(AvatarPreset avatar) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_kAvatarKey, avatar.storageKey);
    state = state.copyWith(avatar: avatar);
  }
}

final profileIdentityProvider =
    NotifierProvider<ProfileIdentityNotifier, ProfileIdentity>(
        ProfileIdentityNotifier.new);
