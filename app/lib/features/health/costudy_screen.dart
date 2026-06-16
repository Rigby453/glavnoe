// Экран совместной учёбы (Co-study, Ф3).
// Позволяет добавлять друзей, видеть кто учится прямо сейчас,
// запускать/завершать собственную сессию и смотреть таблицу лидеров за неделю.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      if (mounted) {
        setState(() {
          _friends = friends;
          _leaderboard = board;
        });
        final studying = friends.where((f) => f['in_session'] == true).toList();
        if (studying.isNotEmpty && mounted && ref.read(_activeSessionProvider) == null) {
          final names = studying.map((f) => (f['email'] as String).split('@').first).join(', ');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$names ${studying.length == 1 ? 'is' : 'are'} studying now! 📚'),
              action: SnackBarAction(
                label: 'Start too',
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
        title: const Text('Add study buddy'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Email address'),
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Add'),
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
          SnackBar(content: Text('Not found: $email')),
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
        title: const Text('Join a session'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Session code (8 characters)',
            hintText: 'e.g. a1b2c3d4',
          ),
          autofocus: true,
          maxLength: 8,
          textCapitalization: TextCapitalization.none,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Join'),
          ),
        ],
      ),
    );
    if (code == null || code.isEmpty || !mounted) return;
    try {
      final info = await ref.read(apiClientProvider).getSessionByCode(code);
      // Show info and let user start their own synchronized session
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Study together'),
          content: Text(
            '${info['user_email']} has been studying for ${info['elapsed_minutes']} min.\nJoin their session?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Start')),
          ],
        ),
      );
      if (confirmed == true) await _startSession();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session not found or has ended')),
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

  String _formatElapsed() {
    final h = _elapsed ~/ 3600;
    final m = (_elapsed % 3600) ~/ 60;
    final s = _elapsed % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final inSession = ref.watch(_activeSessionProvider) != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Co-study'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            onPressed: _addFriend,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Карточка сессии
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      inSession ? Icons.menu_book : Icons.menu_book_outlined,
                      size: 48,
                      color: inSession
                          ? colorScheme.primary
                          : colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 12),
                    if (inSession) ...[
                      Text(_formatElapsed(), style: textTheme.displaySmall),
                      const SizedBox(height: 4),
                      Text('Session in progress', style: textTheme.bodySmall),
                      if (_sessionCode != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Code: $_sessionCode',
                              style: textTheme.titleLarge?.copyWith(
                                letterSpacing: 4,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.copy_outlined, size: 18),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _sessionCode!));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Code copied!')),
                                );
                              },
                            ),
                          ],
                        ),
                        Text('Share this code with a friend', style: textTheme.bodySmall),
                      ],
                      const SizedBox(height: 16),
                      FilledButton.tonal(
                        onPressed: _endSession,
                        child: const Text('End session'),
                      ),
                    ] else ...[
                      Text('Ready to focus?', style: textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        "Start a session and your friends will see you're studying",
                        style: textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _startSession,
                        child: const Text('Start session'),
                      ),
                      TextButton(
                        onPressed: _joinByCode,
                        child: const Text('Join a session by code'),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Секция друзей
            Row(
              children: [
                Text('Study buddies', style: textTheme.titleSmall),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add'),
                  onPressed: _addFriend,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loadingFriends)
              const Center(child: CircularProgressIndicator())
            else if (_friends.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No buddies yet. Add a friend by email!',
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

            const SizedBox(height: 16),

            // Таблица лидеров
            Text('This week', style: textTheme.titleSmall),
            const SizedBox(height: 8),
            if (_leaderboard.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No sessions yet this week.',
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
    return ListTile(
      leading: CircleAvatar(
        child: Text(email.substring(0, 1).toUpperCase()),
      ),
      title: Text(email),
      subtitle: inSession
          ? Text(
              'Studying${minutes != null && minutes > 0 ? ' · ${minutes}m' : ''}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          : const Text('Idle'),
      trailing: IconButton(
        icon: const Icon(Icons.person_remove_outlined, size: 20),
        onPressed: onRemove,
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
      leading: Text(medal, style: const TextStyle(fontSize: 24)),
      title: Text(
        entry['email'] as String,
        style: isMe ? const TextStyle(fontWeight: FontWeight.bold) : null,
      ),
      subtitle: isMe ? const Text('You') : null,
      trailing: Text(label, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
