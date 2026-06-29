// Экран входа / регистрации (406-ФЗ: основной идентификатор — телефон).
// Переключение режимов login/register; вход в офлайн-режиме без аккаунта.
// После успеха навигацию выполняет redirect в routerProvider (по смене статуса).
// Google/Apple OAuth удалены — иностранные OAuth-провайдеры запрещены 406-ФЗ.
//
// Редизайн (design-kai): premium first-impression — displaySmall брендинг,
// KaiLoader вместо CircularProgressIndicator, ошибки через ember,
// accent только на FilledButton-сабмите + SegmentedButton-сегментах.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/animations/constants.dart';
import '../../core/branding.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/settings/mascot_provider.dart';
import '../../core/settings/tone_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/kai_loader.dart';
import '../../features/mascot/kai_mascot.dart';
import '../../services/api/api_client.dart';
import 'auth_controller.dart';

// ---------------------------------------------------------------------------
// Вспомогательный тип: какой идентификатор использует пользователь
// ---------------------------------------------------------------------------

enum _IdentifierType { phone, email }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isLogin = true;
  bool _loading = false;
  String? _error;

  // По умолчанию — телефон (требование 406-ФЗ)
  _IdentifierType _identifierType = _IdentifierType.phone;

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Валидация
  // ---------------------------------------------------------------------------

  /// Проверяет, что номер похож на российский (+7, 7 или 8, всего ~11 цифр).
  bool _isValidRuPhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 11) return false;
    return digits.startsWith('7') || digits.startsWith('8');
  }

  /// Нормализует номер к E.164: +7XXXXXXXXXX.
  String _normalizePhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    final normalized = digits.startsWith('8') ? '7${digits.substring(1)}' : digits;
    return '+$normalized';
  }

  // ---------------------------------------------------------------------------
  // Submit
  // ---------------------------------------------------------------------------

  Future<void> _submit() async {
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    // --- Валидация идентификатора ---
    String? email;
    String? phone;

    if (_identifierType == _IdentifierType.phone) {
      final rawPhone = _phoneController.text.trim();
      if (rawPhone.isEmpty) {
        setState(() => _error = context.s('auth.err_phone_empty'));
        return;
      }
      if (!_isValidRuPhone(rawPhone)) {
        setState(() => _error = context.s('auth.err_phone_invalid'));
        return;
      }
      phone = _normalizePhone(rawPhone);
    } else {
      email = _emailController.text.trim();
      if (email.isEmpty) {
        setState(() => _error = context.s('auth.err_email_empty'));
        return;
      }
    }

    // --- Валидация пароля и имени ---
    if (password.isEmpty) {
      setState(() => _error = context.s('auth.err_password_empty'));
      return;
    }
    if (!_isLogin && name.isEmpty) {
      setState(() => _error = context.s('auth.err_name_empty'));
      return;
    }
    if (!_isLogin && password.length < 8) {
      setState(() => _error = context.s('auth.err_password_short'));
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = ref.read(authControllerProvider.notifier);
      if (_isLogin) {
        await auth.login(email: email, phone: phone, password: password);
      } else {
        await auth.register(
          email: email,
          phone: phone,
          password: password,
          name: name,
        );
      }
      // Навигацию выполнит redirect роутера; виджет может быть уже размонтирован.
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = context.s('auth.err_generic'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _continueOffline() async {
    await ref.read(authControllerProvider.notifier).continueOffline();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final showKai = ref.watch(showKaiProvider);
    final tone = ref.watch(toneProvider);
    final reduce = reduceMotionOf(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- Брендинг-шапка: Kai + имя приложения ---
                  Center(
                    child: Column(
                      children: [
                        // Kai — нейтральное выражение, только если не loading
                        if (showKai && !reduce && !_loading)
                          KaiMascot(
                            size: 72,
                            emotion: KaiEmotion.neutral,
                            isHarsh: tone == AppTone.harsh,
                          )
                        else if (_loading)
                          // KaiLoader вместо CircularProgressIndicator
                          KaiLoader(
                            size: 72,
                            label: _isLogin
                                ? context.s('auth.btn_login')
                                : context.s('auth.btn_signup'),
                          )
                        else
                          // Fallback если Kai отключён: пустое место той же высоты
                          const SizedBox(height: 72),
                        const SizedBox(height: 20),
                        // Wordmark — displaySmall — editorial первое впечатление
                        Text(
                          kAppWordmark,
                          style: textTheme.displaySmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.s('auth.tagline'),
                          style: textTheme.bodyMedium?.copyWith(
                            color: ext.textMuted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // --- Заголовок формы: headlineSmall ---
                  Text(
                    _isLogin
                        ? context.s('auth.welcome_back')
                        : context.s('auth.create_account'),
                    style: textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 20),

                  // --- Phone / Email toggle ---
                  _IdentifierToggle(
                    selected: _identifierType,
                    onChanged: _loading
                        ? null
                        : (type) => setState(() {
                              _identifierType = type;
                              _error = null;
                            }),
                  ),
                  const SizedBox(height: 16),

                  // --- Name field (sign-up only) ---
                  if (!_isLogin) ...[
                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      enabled: !_loading,
                      decoration: InputDecoration(
                        labelText: context.s('auth.field_name'),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // --- Identifier field ---
                  AnimatedSwitcher(
                    duration: effectiveDuration(context, kDurationFast),
                    child: _identifierType == _IdentifierType.phone
                        ? TextField(
                            key: const ValueKey('phone_field'),
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            autocorrect: false,
                            enabled: !_loading,
                            decoration: InputDecoration(
                              labelText: context.s('auth.field_phone'),
                              hintText: context.s('auth.field_phone_hint'),
                            ),
                          )
                        : TextField(
                            key: const ValueKey('email_field'),
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            enabled: !_loading,
                            decoration: InputDecoration(
                              labelText: context.s('auth.field_email'),
                            ),
                          ),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    enabled: !_loading,
                    decoration: InputDecoration(
                      labelText: context.s('auth.field_password'),
                    ),
                    onSubmitted: _loading ? null : (_) => _submit(),
                  ),

                  // --- Сообщение об ошибке: ember (urgent/error color) ---
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: textTheme.bodySmall?.copyWith(
                        color: ext.ember,
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),

                  // --- Primary action: единственный FilledButton ---
                  // KaiLoader показан в шапке, кнопка остаётся для повторной попытки
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: Text(
                      _isLogin
                          ? context.s('auth.btn_login')
                          : context.s('auth.btn_signup'),
                    ),
                  ),

                  const SizedBox(height: 4),

                  // --- Вторичные действия: TextButton (минимальный вес) ---

                  // Toggle login/register
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => setState(() {
                              _isLogin = !_isLogin;
                              _error = null;
                            }),
                    child: Text(
                      _isLogin
                          ? context.s('auth.switch_to_signup')
                          : context.s('auth.switch_to_login'),
                      style: textTheme.labelLarge?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  // Forgot password (login only)
                  if (_isLogin)
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => context.push('/forgot-password'),
                      child: Text(
                        context.s('auth.forgot_password'),
                        style: textTheme.labelLarge?.copyWith(
                          color: ext.textMuted,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),

                  // Offline mode — ещё меньший вес, textFaint
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: _loading ? null : _continueOffline,
                    child: Text(
                      context.s('auth.continue_offline'),
                      style: textTheme.labelLarge?.copyWith(
                        color: ext.textFaint,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Phone / Email toggle widget
// ---------------------------------------------------------------------------

class _IdentifierToggle extends StatelessWidget {
  const _IdentifierToggle({
    required this.selected,
    required this.onChanged,
  });

  final _IdentifierType selected;
  final ValueChanged<_IdentifierType>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_IdentifierType>(
      segments: [
        ButtonSegment(
          value: _IdentifierType.phone,
          label: Text(context.s('auth.tab_phone')),
          icon: Icon(PhosphorIcons.phone()),
        ),
        ButtonSegment(
          value: _IdentifierType.email,
          label: Text(context.s('auth.tab_email')),
          icon: Icon(PhosphorIcons.envelope()),
        ),
      ],
      selected: {selected},
      onSelectionChanged: onChanged == null
          ? null
          : (newSelection) => onChanged!(newSelection.first),
      showSelectedIcon: false,
    );
  }
}
