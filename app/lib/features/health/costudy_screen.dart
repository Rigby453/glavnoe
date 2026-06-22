// Экран совместной учёбы (Co-study, Ф3).
// Позволяет добавлять друзей, видеть кто учится прямо сейчас,
// запускать/завершать собственную сессию и смотреть таблицу лидеров за неделю.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/plurals.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/kai_loader.dart';
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
          final names = studying.map((f) => (f['email'] as String).split('@').first).join(', ');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                studying.length == 1
                    ? context.s('costudy.friends_studying_one').replaceFirst('{name}', names)
                    : context.s('costudy.friends_studying_many').replaceFirst('{names}', names),
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
          // FilledButton — единственное первичное действие в диалоге
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.s('btn.cancel'))),
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
    } catch (e) {
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
  // Study groups (настоящие группы)
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.s('btn.cancel'))),
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
              Text(
                '${ctx.s('costudy.session_code_label')} $code',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      letterSpacing: 4,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_outlined, size: 18),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.s('btn.cancel'))),
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

  /// Открывает детали группы. Для владельца показывает pending-заявки
  /// с кнопками «Принять» / «Отклонить».
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

  String _formatElapsed() {
    final h = _elapsed ~/ 3600;
    final m = (_elapsed % 3600) ~/ 60;
    final s = _elapsed % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final inSession = ref.watch(_activeSessionProvider) != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.s('costudy.title')),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: ext.textMuted),
            onPressed: _load,
          ),
          IconButton(
            icon: Icon(Icons.person_add_outlined, color: ext.textMuted),
            onPressed: _addFriend,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          // 24dp screen margin — spec §4.1
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
          children: [
            // Карточка сессии
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Иконка книги: accent только в активной сессии (единственный акцент на экране)
                    // В неактивном состоянии — нейтральный textMuted
                    Icon(
                      inSession ? Icons.menu_book : Icons.menu_book_outlined,
                      size: 48,
                      color: inSession
                          ? Theme.of(context).colorScheme.primary
                          : ext.textMuted,
                    ),
                    const SizedBox(height: 12),
                    if (inSession) ...[
                      // Таймер — displaySmall (display font, крупный)
                      Text(_formatElapsed(), style: textTheme.displaySmall),
                      const SizedBox(height: 4),
                      Text(
                        context.s('costudy.session_in_progress'),
                        style: textTheme.bodySmall,
                      ),
                      if (_sessionCode != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Код сессии — titleLarge, широкий трекинг
                            Text(
                              '${context.s('costudy.session_code_label')} $_sessionCode',
                              style: textTheme.titleLarge?.copyWith(
                                letterSpacing: 4,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(Icons.copy_outlined, size: 18, color: ext.textMuted),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _sessionCode!));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(context.s('costudy.code_copied'))),
                                );
                              },
                            ),
                          ],
                        ),
                        Text(context.s('costudy.share_code'), style: textTheme.bodySmall),
                      ],
                      const SizedBox(height: 16),
                      // Tonal — вторичное действие (завершить менее важно чем кнопка Start)
                      FilledButton.tonal(
                        onPressed: _endSession,
                        child: Text(context.s('costudy.end_session')),
                      ),
                    ] else ...[
                      // Заголовок в состоянии покоя — titleMedium
                      Text(context.s('costudy.ready_to_focus'), style: textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        context.s('costudy.session_prompt'),
                        style: textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      // FilledButton — единственное первичное действие на экране
                      FilledButton(
                        onPressed: _startSession,
                        child: Text(context.s('costudy.start_session')),
                      ),
                      // TextButton — вторичный навигационный нудж
                      TextButton(
                        onPressed: _joinByCode,
                        child: Text(context.s('costudy.join_by_code')),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Секция групп (настоящие учебные группы)
            Row(
              children: [
                Text(context.s('costudy.groups'), style: textTheme.titleSmall),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.group_add_outlined, size: 16),
                  label: Text(context.s('costudy.join_group')),
                  onPressed: _joinGroupByCode,
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(context.s('costudy.create_group')),
                  onPressed: _createGroup,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_groups.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  context.s('costudy.no_groups'),
                  style: textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              )
            else
              ...(_groups.map(
                (g) => _GroupTile(
                  group: g,
                  onTap: () => _openGroup(g),
                  onLeave: () => _leaveGroup(g),
                ),
              )),

            const SizedBox(height: 24),

            // Секция друзей
            Row(
              children: [
                // titleSmall — секционный подзаголовок (body font, w600)
                Text(context.s('costudy.study_buddies'), style: textTheme.titleSmall),
                const Spacer(),
                // TextButton — навигационный нудж (не основное действие)
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(context.s('btn.add')),
                  onPressed: _addFriend,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loadingFriends)
              // KaiLoader заменяет CircularProgressIndicator
              Center(child: KaiLoader(label: context.s('loading.buddies')))
            else if (_friends.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  context.s('costudy.no_buddies'),
                  style: textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              )
            else
              ...(_friends.map(
                (f) => _FriendTile(
                  friend: f,
                  onRemove: () async {
                    await ref
                        .read(apiClientProvider)
                        .removeFriend(f['id'] as String);
                    _load();
                  },
                ),
              )),

            const SizedBox(height: 24),

            // Таблица лидеров
            Text(context.s('costudy.this_week'), style: textTheme.titleSmall),
            const SizedBox(height: 8),
            if (_leaderboard.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  context.s('costudy.no_sessions_week'),
                  style: textTheme.bodySmall,
                ),
              )
            else
              ...(_leaderboard.map((e) => _LeaderboardTile(entry: e))),
          ],
        ),
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.friend, required this.onRemove});
  final Map<String, dynamic> friend;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final inSession = friend['in_session'] == true;
    final minutes = friend['session_minutes'] as int?;
    final email = friend['email'] as String;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return ListTile(
      leading: CircleAvatar(
        // Avatar — нейтральный (surface + textMuted label)
        backgroundColor: ext.border,
        child: Text(
          email.substring(0, 1).toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: ext.textMuted,
              ),
        ),
      ),
      title: Text(email),
      subtitle: inSession
          ? Text(
              // "Studying · Xm" — accent color для активного состояния (единственный)
              '${context.s('costudy.studying_label')}${minutes != null && minutes > 0 ? ' · ${minutes}m' : ''}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            )
          : Text(
              context.s('costudy.friend_idle'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
      trailing: IconButton(
        icon: Icon(Icons.person_remove_outlined, size: 20, color: ext.textMuted),
        onPressed: onRemove,
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({
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
    final name = group['name'] as String? ?? '';
    final isOwner = group['is_owner'] == true;
    final memberCount = (group['member_count'] as num?)?.toInt() ?? 0;
    final pending = (group['pending_count'] as num?)?.toInt() ?? 0;

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: ext.border,
        child: Icon(Icons.groups_outlined, size: 20, color: ext.textMuted),
      ),
      title: Text(name),
      subtitle: Text(
        context.s('costudy.members_count').replaceFirst('{count}', '$memberCount'),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Бейдж с числом ожидающих заявок — только у владельца, акцентом.
          if (isOwner && pending > 0)
            Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$pending',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          IconButton(
            icon: Icon(Icons.logout, size: 20, color: ext.textMuted),
            tooltip: context.s('costudy.leave_group'),
            onPressed: onLeave,
          ),
        ],
      ),
    );
  }
}

/// Нижний лист с деталями группы. Для владельца показывает pending-заявки
/// с кнопками «Принять» / «Отклонить» (запрошенный «тумблер приглашений»).
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
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final detail = _detail;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: _loading || detail == null
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: KaiLoader()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: () {
                  final isOwner = detail['is_owner'] == true;
                  final members =
                      (detail['members'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
                  final accepted =
                      members.where((m) => m['status'] == 'accepted').toList();
                  final pending =
                      members.where((m) => m['status'] == 'pending').toList();

                  return <Widget>[
                    Row(
                      children: [
                        Text(detail['name'] as String? ?? '', style: textTheme.titleMedium),
                        const SizedBox(width: 8),
                        Text(
                          '${context.s('costudy.session_code_label')} ${detail['code'] ?? ''}',
                          style: textTheme.bodySmall?.copyWith(letterSpacing: 2),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Pending-заявки (только владельцу) — «тумблер приглашений».
                    if (isOwner && pending.isNotEmpty) ...[
                      Text(context.s('costudy.pending_requests'), style: textTheme.titleSmall),
                      const SizedBox(height: 4),
                      ...pending.map(
                        (m) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(m['email'] as String? ?? ''),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.check_circle_outline,
                                    color: Theme.of(context).colorScheme.primary),
                                tooltip: context.s('costudy.accept'),
                                onPressed: () => _accept(m['user_id'] as String),
                              ),
                              IconButton(
                                icon: Icon(Icons.cancel_outlined, color: ext.textMuted),
                                tooltip: context.s('costudy.decline'),
                                onPressed: () => _decline(m['user_id'] as String),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Участники.
                    Text(context.s('costudy.study_buddies'), style: textTheme.titleSmall),
                    const SizedBox(height: 4),
                    ...accepted.map(
                      (m) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: ext.border,
                          child: Text(
                            (m['email'] as String? ?? '?').substring(0, 1).toUpperCase(),
                            style: textTheme.labelMedium?.copyWith(color: ext.textMuted),
                          ),
                        ),
                        title: Text(m['email'] as String? ?? ''),
                        subtitle: m['role'] == 'owner'
                            ? Text(context.s('costudy.group_owner_badge'))
                            : null,
                      ),
                    ),
                  ];
                }(),
              ),
      ),
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  const _LeaderboardTile({required this.entry});
  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final isMe = entry['is_me'] == true;
    final rank = entry['rank'] as int;
    final minutes = entry['minutes'] as int;
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    final label = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';
    final medal = rank == 1
        ? '\u{1F947}'
        : rank == 2
        ? '\u{1F948}'
        : rank == 3
        ? '\u{1F949}'
        : '#$rank';

    return ListTile(
      leading: Text(medal, style: const TextStyle(fontSize: 22)),
      title: Text(
        entry['email'] as String,
        // Своя строка — w600 (titleSmall weight) для выделения без акцента
        style: isMe
            ? Theme.of(context).textTheme.titleSmall
            : Theme.of(context).textTheme.bodyMedium,
      ),
      subtitle: isMe ? Text(context.s('costudy.you')) : null,
      trailing: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).extension<FocusThemeExtension>()!.textMuted,
            ),
      ),
    );
  }
}
