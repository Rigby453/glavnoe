// Экран восстановления пароля: два шага — запрос кода → ввод кода + нового пароля.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../services/api/api_client.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();

  bool _step2 = false; // false = ввод email, true = ввод кода+пароля
  bool _loading = false;
  String? _error;
  String? _devCode; // показываем в dev-режиме

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final code = await ref.read(apiClientProvider).forgotPassword(email);
      if (!mounted) return;
      setState(() { _step2 = true; _devCode = code; });
    } catch (e) {
      if (mounted) setState(() => _error = context.s('auth.reset_err_send'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final code = _codeCtrl.text.trim();
    final pw = _pwCtrl.text.trim();
    if (code.length != 6 || pw.length < 8) {
      setState(() => _error = context.s('auth.reset_err_code_pw'));
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(apiClientProvider).resetPassword(
        email: _emailCtrl.text.trim(),
        code: code,
        newPassword: pw,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.s('auth.reset_success_snack'))),
      );
      context.pop();
    } catch (e) {
      if (mounted) setState(() => _error = context.s('auth.reset_err_invalid_code'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(context.s('auth.reset_title'))),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_step2) ...[
              Text(context.s('auth.reset_step1_heading'), style: textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                context.s('auth.reset_step1_body'),
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: context.s('auth.field_email'),
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _requestCode(),
              ),
            ] else ...[
              Text(context.s('auth.reset_step2_heading'), style: textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                context.s('auth.reset_step2_body'),
                style: textTheme.bodyMedium,
              ),
              if (_devCode != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'DEV: code is $_devCode',
                    style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: context.s('auth.reset_field_code'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pwCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: context.s('auth.reset_field_new_password'),
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _resetPassword(),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            _loading
                ? const Center(child: CircularProgressIndicator())
                : FilledButton(
                    onPressed: _step2 ? _resetPassword : _requestCode,
                    child: Text(
                      _step2
                          ? context.s('auth.reset_btn_reset')
                          : context.s('auth.reset_btn_send_code'),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
