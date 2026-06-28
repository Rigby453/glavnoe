// Экран совместной учёбы (Co-study, Ф3).
// Restyle: Kaname §4.2 — плоские карточки (surface1 + hairline + R14),
// hairline-разделители вместо ListTile, Phosphor-иконки, KaiMascot в
// пустых состояниях, overflow-safe на 320px / textScale 1.5.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/plurals.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/kai_loader.dart';
import '../../features/mascot/kai_mascot.dart';
import '../../services/api/api_client.dart';

// Активная сессия: null = нет сессии, иначе ID сессии
final _activeSessionProvider = StateProvider<String?>((ref) => null);
final _sessionStartProvider = StateProvider<DateTime?>((ref) => null);

class CoStudyScreen extends ConsumerStatefulWidget {
  const CoStudyScreen({super.key});

  @override
  ConsumerState<CoStudyScreen> createState() => _CoStudyScreenState();
}

class _CoStudyScreenState extends ConsumerState<CoStudyScreen> {
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _leaderboard = [];
  List<Map<String, dynamic>> _groups = [];
  bool _loadingFriends = true;
  Timer? _timer;
  int _elapsed = 0; // секунды с начала сессии
  String? _sessionCode;

  @override
  void initState() {
    super.initState();
    _load();
    // Тикаем каждую секунду пока идёт сессия
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final start = ref.read(_sessionStartProvider);
      if (start != null && mounted) {
        setState(() {
          _elapsed = DateTime.now().difference(start).inSeconds;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadingFriends = true);
    try {
      final api = ref.read(apiClientProvider);
      final friends = await api.getFriends();
      final board = await api.getLeaderboard();
      final groups = await api.getStudyGroups();
      if (mounted) {
        setState(() {
          _friends = friends;
          _leaderboard = board;
          _groups = groups;
        });
        final studying = friends.where((f) => f['in_session'] == true).toList();
        if (studying.isNotEmpty && mounted && ref.read(_activeSessionProvider) == null) {
          final names =
              studying.map((f) => (f['email'] as String).split('@').first).join(', ');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                studying.length == 1
                    ? context
                        .s('costudy.friends_studying_one')
                        .replaceFirst('{name}', names)
                    : context
                        .s('costudy.friends_studying_many')
                        .replaceFirst('{names}', names),
              ),
              action: SnackBarAction(
                label: context.s('costudy.start_too'),
                onPressed: _startSession,
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingFriends = false);
  }

  Future<void> _addFriend() async {
    final ctrl = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.s('costudy.add_buddy_title')),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(labelText: ctx.s('costudy.email_label')),
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.s('btn.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(ctx.s('btn.add')),
          ),
        ],
      ),
    );
    if (email == null || email.isEmpty) return;
    try {
      await ref.read(apiClientProvider).addFriend(email);
      _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.s('costudy.not_found_email').replaceFirst('{email}', email),
            ),
          ),
        );
      }
    }
  }

  Future<void> _startSession() async {
    try {
      final data = await ref.read(apiClientProvider).startSession();
      ref.read(_activeSessionProvider.notifier).state = data['id'] as String;
      ref.read(_sessionStartProvider.notifier).state = DateTime.now();
      setState(() {
        _elapsed = 0;
        _sessionCode = data['code'] as String?;
      });
    } catch (_) {}
  }

  Future<void> _joinByCode() async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.s('costudy.join_session_title')),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            labelText: ctx.s('costudy.session_code_hint_label'),
            hintText: ctx.s('costudy.session_code_eg'),
          ),
          autofocus: true,
          maxLength: 8,
          textCapitalization: TextCapitalization.none,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.s('btn.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(ctx.s('costudy.join')),
          ),
        ],
      ),
    );
    if (code == null || code.isEmpty || !mounted) return;
    try {
      final info = await ref.read(apiClientProvider).getSessionByCode(code);
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.s('costudy.study_together')),
          content: Text(
            plCoStudyJoin(
              ctx,
              '${info['user_email']}',
              (info['elapsed_minutes'] as num?)?.toInt() ?? 0,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.s('btn.cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.s('costudy.start')),
            ),
          ],
        ),
      );
      if (confirmed == true) await _startSession();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.s('costudy.session_not_found'))),
        );
      }
    }
  }

  Future<void> _endSession() async {
    final sessionId = ref.read(_activeSessionProvider);
    if (sessionId == null) return;
    final minutes = (_elapsed / 60).ceil();
    try {
      await ref.read(apiClientProvider).endSession(sessionId, minutes);
      ref.read(_activeSessionProvider.notifier).state = null;
      ref.read(_sessionStartProvider.notifier).state = null;
      setState(() {
        _elapsed = 0;
        _sessionCode = null;
      });
      _load(); // обновляем таблицу лидеров
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Study groups (настоящие учебные группы)
  // ---------------------------------------------------------------------------

  Future<void> _createGroup() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.s('costudy.create_group')),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(labelText: ctx.s('costudy.group_name_label')),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.s('btn.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(ctx.s('costudy.create_group')),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    try {
      final group = await ref.read(apiClientProvider).createStudyGroup(name);
      await _load();
      if (!mounted) return;
      // Показываем код новой группы, чтобы владелец мог поделиться.
      final code = group['code'] as String? ?? '';
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(group['name'] as String? ?? ''),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Text(
                  '${ctx.s('costudy.session_code_label')} $code',
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(letterSpacing: 4),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(PhosphorIcons.copy(), size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(ctx.s('costudy.code_copied'))),
                  );
                },
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.s('btn.done')),
            ),
          ],
        ),
      );
    } catch (_) {}
  }

  Future<void> _joinGroupByCode() async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.s('costudy.join_group')),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            labelText: ctx.s('costudy.session_code_hint_label'),
            hintText: ctx.s('costudy.session_code_eg'),
          ),
          autofocus: true,
          maxLength: 8,
          textCapitalization: TextCapitalization.none,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.s('btn.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(ctx.s('costudy.request_join')),
          ),
        ],
      ),
    );
    if (code == null || code.isEmpty || !mounted) return;
    try {
      await ref.read(apiClientProvider).joinStudyGroup(code);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.s('costudy.request_sent'))),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.s('costudy.group_not_found'))),
        );
      }
    }
  }

  Future<void> _leaveGroup(Map<String, dynamic> group) async {
    final isOwner = group['is_owner'] == true;
    if (isOwner) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.s('costudy.leave_group')),
          content: Text(ctx.s('costudy.leave_group_owner_warning')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.s('btn.cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.s('costudy.leave_group')),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    try {
      await ref.read(apiClientProvider).leaveStudyGroup(group['id'] as String);
      await _load();
    } catch (_) {}
  }

  /// Открывает детали группы. Для владельца показывает pending-заявки.
  Future<void> _openGroup(Map<String, dynamic> group) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _GroupDetailSheet(
        groupId: group['id'] as String,
        onChanged: _load,
      ),
    );
  }

  /// Форматирует elapsed-секунды для таймера сессии.
  /// >= 1 часа: локализованный шаблон costudy.timer_hm ({h}ч {m}м).
  /// < 1 часа:  MM:SS (числа — универсальный формат).
  String _formatElapsed(BuildContext context) {
    final h = _elapsed ~/ 3600;
    final m = (_elapsed % 3600) ~/ 60;
    final s = _elapsed % 60;
    if (h > 0) {
      return context
          .s('costudy.timer_hm')
          .replaceFirst('{h}', '$h')
          .replaceFirst('{m}', m.toString().padLeft(2, '0'));
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final inSession = ref.watch(_activeSessionProvider) != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.s('costudy.title')),
        actions: [
          // Обновить — нейтральный, не акцентный
          IconButton(
            icon: Icon(PhosphorIcons.arrowsClockwise(), size: 20, color: ext.textMuted),
            onPressed: _load,
          ),
          // Добавить друга — нейтральный
          IconButton(
            icon: Icon(PhosphorIcons.userPlus(), size: 20, color: ext.textMuted),
            tooltip: context.s('costudy.add_buddy_title'),
            onPressed: _addFriend,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          // 24dp screen margin — spec §4
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
          children: [
            // Карточка сессии — object card §4.2
            _SessionCard(
              inSession: inSession,
              elapsed: _formatElapsed(context),
              sessionCode: _sessionCode,
              onStart: _startSession,
              onEnd: _endSession,
              onJoinByCode: _joinByCode,
            ),

            const SizedBox(height: 24),

            // Секция групп. Заголовок в Expanded, кнопки в Wrap —
            // на 320px они переносятся на следующую строку без overflow.
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    context.s('costudy.groups'),
                    style: textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Flexible(
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    children: [
                      TextButton.icon(
                        icon: Icon(PhosphorIcons.userPlus(), size: 16),
                        label: Text(context.s('costudy.join_group')),
                        onPressed: _joinGroupByCode,
                      ),
                      TextButton.icon(
                        icon: Icon(PhosphorIcons.plus(), size: 16),
                        label: Text(context.s('costudy.create_group')),
                        onPressed: _createGroup,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_groups.isEmpty)
              _EmptyState(
                bodyKey: 'costudy.no_groups',
                ctaLabel: context.s('costudy.create_group'),
                onCta: _createGroup,
              )
            else
              ...(_groups.map(
                (g) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _GroupCard(
                    group: g,
                    onTap: () => _openGroup(g),
                    onLeave: () => _leaveGroup(g),
                  ),
                ),
              )),

            const SizedBox(height: 24),

            // Секция друзей
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.s('costudy.study_buddies'),
                    style: textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  icon: Icon(PhosphorIcons.userPlus(), size: 16),
                  label: Text(context.s('btn.add')),
                  onPressed: _addFriend,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loadingFriends)
              Center(child: KaiLoader(label: context.s('loading.buddies')))
            else if (_friends.isEmpty)
              _EmptyState(
                bodyKey: 'costudy.no_buddies',
                ctaLabel: context.s('costudy.add_by_email'),
                onCta: _addFriend,
              )
            else
              // Друзья — dense hairline-divided rows в одном контейнере (§4.2)
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ext.border, width: 0.5),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < _friends.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          thickness: 0.5,
                          color: ext.border,
                          indent: 56,
                        ),
                      _FriendRow(
                        friend: _friends[i],
                        onRemove: () async {
                          await ref
                              .read(apiClientProvider)
                              .removeFriend(_friends[i]['id'] as String);
                          _load();
                        },
                      ),
                    ],
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Таблица лидеров — dense hairline-divided rows (§4.2)
            Text(context.s('costudy.this_week'), style: textTheme.titleSmall),
            const SizedBox(height: 8),
            if (_leaderboard.isEmpty)
              _EmptyState(
                bodyKey: 'costudy.no_sessions_week',
                ctaLabel: context.s('costudy.start_session'),
                onCta: _startSession,
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ext.border, width: 0.5),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < _leaderboard.length; i++) ...[
                      if (i > 0)
                        Divider(height: 1, thickness: 0.5, color: ext.border),
                      _LeaderboardRow(entry: _leaderboard[i]),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Карточка текущей сессии — object card §4.2
// ---------------------------------------------------------------------------

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.inSession,
    required this.elapsed,
    required this.sessionCode,
    required this.onStart,
    required this.onEnd,
    required this.onJoinByCode,
  });

  final bool inSession;
  final String elapsed; // уже отформатированная строка
  final String? sessionCode;
  final VoidCallback onStart;
  final VoidCallback onEnd;
  final VoidCallback onJoinByCode;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    final code = sessionCode; // локальная переменная для null-safety в замыканиях

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ext.border, width: 0.5),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Иконка книги — fill + accent только в активной сессии
          Icon(
            inSession
                ? PhosphorIcons.bookOpen(PhosphorIconsStyle.fill)
                : PhosphorIcons.bookOpen(),
            size: 40,
            color: inSession ? colorScheme.primary : ext.textMuted,
          ),
          const SizedBox(height: 12),
          if (inSession) ...[
            // Таймер — displaySmall (monospaced числа)
            Text(elapsed, style: textTheme.displaySmall),
            const SizedBox(height: 4),
            Text(
              context.s('costudy.session_in_progress'),
              style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
            ),
            if (code != null) ...[
              const SizedBox(height: 12),
              // Блок кода сессии — surfaceElevated + hairline + R8
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: ext.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ext.border, width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        '${context.s('costudy.session_code_label')} $code',
                        style: textTheme.titleLarge?.copyWith(letterSpacing: 4),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(PhosphorIcons.copy(), size: 18, color: ext.textMuted),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(context.s('costudy.code_copied'))),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.s('costudy.share_code'),
                style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),
            // Завершить — outlined, НЕ primary (primary = Start на экране в целом)
            OutlinedButton(
              onPressed: onEnd,
              child: Text(context.s('costudy.end_session')),
            ),
          ] else ...[
            Text(context.s('costudy.ready_to_focus'), style: textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              context.s('costudy.session_prompt'),
              style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // FilledButton — единственное первичное действие на экране
            FilledButton(
              onPressed: onStart,
              child: Text(context.s('costudy.start_session')),
            ),
            TextButton(
              onPressed: onJoinByCode,
              child: Text(context.s('costudy.join_by_code')),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Object card группы §4.2: surface1 + hairline + R14, ведущая иконка,
// название + участники, trailing chevron + leave button
// ---------------------------------------------------------------------------

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.onTap,
    required this.onLeave,
  });

  final Map<String, dynamic> group;
  final VoidCallback onTap;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final name = group['name'] as String? ?? '';
    final isOwner = group['is_owner'] == true;
    final memberCount = (group['member_count'] as num?)?.toInt() ?? 0;
    final pending = (group['pending_count'] as num?)?.toInt() ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ext.border, width: 0.5),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Ведущая иконка — нейтральный квадрат R8
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: ext.border.withAlpha(80),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(PhosphorIcons.users(), size: 18, color: ext.textMuted),
                ),
                const SizedBox(width: 12),
                // Название + число участников — Expanded избегает overflow
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        context
                            .s('costudy.members_count')
                            .replaceFirst('{count}', '$memberCount'),
                        style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Бейдж pending-заявок — только владельцу, акцентный
                if (isOwner && pending > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$pending',
                      style: textTheme.labelSmall
                          ?.copyWith(color: colorScheme.onPrimary),
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                // Chevron — навигационный affordance
                Icon(PhosphorIcons.caretRight(), size: 16, color: ext.textMuted),
                // Кнопка выхода из группы
                IconButton(
                  icon: Icon(PhosphorIcons.signOut(), size: 18, color: ext.textMuted),
                  visualDensity: VisualDensity.compact,
                  tooltip: context.s('costudy.leave_group'),
                  onPressed: onLeave,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Строка друга — dense row §4.2 (нет ListTile)
// ---------------------------------------------------------------------------

class _FriendRow extends StatelessWidget {
  const _FriendRow({required this.friend, required this.onRemove});

  final Map<String, dynamic> friend;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final inSession = friend['in_session'] == true;
    final minutes = friend['session_minutes'] as int?;
    final email = friend['email'] as String;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    // Локализованный счётчик минут для статуса «Studying · Xm»
    final minuteStr = (minutes != null && minutes > 0)
        ? ' · ${context.s('costudy.timer_m').replaceFirst('{m}', '$minutes')}'
        : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Аватар — инициал на нейтральном фоне
          CircleAvatar(
            radius: 18,
            backgroundColor: ext.border.withAlpha(120),
            child: Text(
              email.isNotEmpty ? email[0].toUpperCase() : '?',
              style: textTheme.labelMedium?.copyWith(color: ext.textMuted),
            ),
          ),
          const SizedBox(width: 12),
          // Email + статус — Expanded обрезает длинные адреса
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(email, style: textTheme.bodyMedium, overflow: TextOverflow.ellipsis),
                if (inSession)
                  // Статус «Studying» — accent только для активного состояния
                  Text(
                    '${context.s('costudy.studying_label')}$minuteStr',
                    style:
                        textTheme.bodySmall?.copyWith(color: colorScheme.primary),
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  Text(
                    context.s('costudy.friend_idle'),
                    style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // Удалить — нейтральный textMuted
          IconButton(
            icon: Icon(PhosphorIcons.userMinus(), size: 18, color: ext.textMuted),
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Строка таблицы лидеров — dense row §4.2
// ---------------------------------------------------------------------------

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.entry});

  final Map<String, dynamic> entry;

  // Медаль или ранг. Unicode: 🥇🥈🥉 для 1-2-3, далее #N.
  static String _rankLabel(int rank) => switch (rank) {
        1 => '\u{1F947}',
        2 => '\u{1F948}',
        3 => '\u{1F949}',
        _ => '#$rank',
      };

  @override
  Widget build(BuildContext context) {
    final isMe = entry['is_me'] == true;
    final rank = entry['rank'] as int;
    final minutes = entry['minutes'] as int;
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    // Локализованный формат продолжительности
    final durationLabel = hours > 0
        ? context
            .s('costudy.timer_hm')
            .replaceFirst('{h}', '$hours')
            .replaceFirst('{m}', '$mins')
        : context.s('costudy.timer_m').replaceFirst('{m}', '$minutes');

    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Ранг — фиксированная ширина 32dp, не ломает layout
          SizedBox(
            width: 32,
            child: Text(
              _rankLabel(rank),
              style: const TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          // Email + подпись «Это ты» — Expanded избегает overflow
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry['email'] as String,
                  style: isMe ? textTheme.titleSmall : textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                if (isMe)
                  Text(
                    context.s('costudy.you'),
                    style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
                  ),
              ],
            ),
          ),
          // Продолжительность — вторичная информация
          Text(
            durationLabel,
            style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Пустое состояние §4.2 invitation pattern:
// KaiMascot(neutral, 64) + одна строка + verb button. Без "it's empty".
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.bodyKey,
    required this.ctaLabel,
    required this.onCta,
  });

  final String bodyKey;
  final String ctaLabel;
  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const KaiMascot(size: 64, emotion: KaiEmotion.neutral),
            const SizedBox(height: 12),
            Text(
              context.s(bodyKey),
              style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onCta,
              child: Text(ctaLabel),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Нижний лист с деталями группы.
// Содержит: handle · заголовок + ✕ · код группы · pending-заявки · участники.
// ---------------------------------------------------------------------------

class _GroupDetailSheet extends ConsumerStatefulWidget {
  const _GroupDetailSheet({required this.groupId, required this.onChanged});
  final String groupId;
  final Future<void> Function() onChanged;

  @override
  ConsumerState<_GroupDetailSheet> createState() => _GroupDetailSheetState();
}

class _GroupDetailSheetState extends ConsumerState<_GroupDetailSheet> {
  Map<String, dynamic>? _detail;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _loading = true);
    try {
      final d = await ref.read(apiClientProvider).getStudyGroup(widget.groupId);
      if (mounted) setState(() => _detail = d);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _accept(String userId) async {
    try {
      await ref.read(apiClientProvider).acceptGroupMember(widget.groupId, userId);
      await _loadDetail();
      await widget.onChanged();
    } catch (_) {}
  }

  Future<void> _decline(String userId) async {
    try {
      await ref.read(apiClientProvider).declineGroupMember(widget.groupId, userId);
      await _loadDetail();
      await widget.onChanged();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar §4.3
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: ext.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          if (_loading || _detail == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: KaiLoader()),
            )
          else
            // Flexible позволяет контенту занять до оставшейся высоты экрана
            // и прокручиваться, если участников много
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: _buildContent(context, _detail!),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, Map<String, dynamic> detail) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    final isOwner = detail['is_owner'] == true;
    final members =
        (detail['members'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final accepted = members.where((m) => m['status'] == 'accepted').toList();
    final pending = members.where((m) => m['status'] == 'pending').toList();
    final code = detail['code'] as String? ?? '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок + крестик закрытия §4.3
        Row(
          children: [
            Expanded(
              child: Text(
                detail['name'] as String? ?? '',
                style: textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: Icon(PhosphorIcons.x(), size: 20),
              tooltip: context.s('btn.close'),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
        Divider(height: 16, thickness: 0.5, color: ext.border),

        // Постоянный код группы — виден всем участникам
        if (code.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: ext.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ext.border, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.s('costudy.group_code_label'),
                  style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        code,
                        style: textTheme.titleLarge?.copyWith(letterSpacing: 4),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(PhosphorIcons.copy(), size: 20, color: ext.textMuted),
                      visualDensity: VisualDensity.compact,
                      tooltip: context.s('costudy.copy_code'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(context.s('costudy.code_copied'))),
                        );
                      },
                    ),
                  ],
                ),
                Text(
                  context.s('costudy.share_code'),
                  style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Pending-заявки — только для владельца
        if (isOwner && pending.isNotEmpty) ...[
          Text(context.s('costudy.pending_requests'), style: textTheme.titleSmall),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ext.border, width: 0.5),
            ),
            child: Column(
              children: [
                for (int i = 0; i < pending.length; i++) ...[
                  if (i > 0) Divider(height: 1, thickness: 0.5, color: ext.border),
                  _PendingRow(
                    member: pending[i],
                    onAccept: () => _accept(pending[i]['user_id'] as String),
                    onDecline: () => _decline(pending[i]['user_id'] as String),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Участники группы
        Text(context.s('costudy.study_buddies'), style: textTheme.titleSmall),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ext.border, width: 0.5),
          ),
          child: accepted.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    context.s('costudy.no_buddies'),
                    style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
                    textAlign: TextAlign.center,
                  ),
                )
              : Column(
                  children: [
                    for (int i = 0; i < accepted.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          thickness: 0.5,
                          color: ext.border,
                          indent: 56,
                        ),
                      _MemberRow(
                        member: accepted[i],
                        ownerBadge: accepted[i]['role'] == 'owner'
                            ? context.s('costudy.group_owner_badge')
                            : null,
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Строка pending-заявки (внутри GroupDetailSheet)
// ---------------------------------------------------------------------------

class _PendingRow extends StatelessWidget {
  const _PendingRow({
    required this.member,
    required this.onAccept,
    required this.onDecline,
  });

  final Map<String, dynamic> member;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final email = member['email'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              email,
              style: textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Принять — fill + accent (активное действие)
          IconButton(
            icon: Icon(
              PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
              size: 20,
              color: colorScheme.primary,
            ),
            visualDensity: VisualDensity.compact,
            tooltip: context.s('costudy.accept'),
            onPressed: onAccept,
          ),
          // Отклонить — нейтральный textMuted
          IconButton(
            icon: Icon(PhosphorIcons.x(), size: 20, color: ext.textMuted),
            visualDensity: VisualDensity.compact,
            tooltip: context.s('costudy.decline'),
            onPressed: onDecline,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Строка участника группы (внутри GroupDetailSheet)
// ---------------------------------------------------------------------------

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member, this.ownerBadge});

  final Map<String, dynamic> member;
  final String? ownerBadge;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    final email = member['email'] as String? ?? '?';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Аватар с инициалом
          CircleAvatar(
            radius: 18,
            backgroundColor: ext.border.withAlpha(120),
            child: Text(
              email.isNotEmpty ? email[0].toUpperCase() : '?',
              style: textTheme.labelMedium?.copyWith(color: ext.textMuted),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email,
                  style: textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                if (ownerBadge != null)
                  Text(
                    ownerBadge!,
                    style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
