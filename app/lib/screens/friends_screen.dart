import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/account_service.dart';
import '../services/pair_state.dart';
import '../services/social_service.dart';
import 'account_screen.dart';
import 'chat_screen.dart';

/// Chats & friends: add people by email or @username, accept requests,
/// open chats (and the couple-pairing partner chat).
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});
  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _addCtrl = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final s = context.read<SocialService>();
    s.refreshFriends();
    s.refreshInbox();
  }

  @override
  void dispose() {
    _addCtrl.dispose();
    super.dispose();
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _add() async {
    final q = _addCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() => _busy = true);
    final r = await context.read<SocialService>().addFriend(q);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.ok) _addCtrl.clear();
    _snack(r.ok ? '${r.data['message'] ?? 'Request sent'}' : (r.error ?? 'Failed'));
  }

  Future<void> _setUsername(AccountService acct) async {
    final ctrl = TextEditingController(text: acct.username ?? '');
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose your username'),
        content: TextField(
          controller: ctrl,
          autocorrect: false,
          decoration: const InputDecoration(
              prefixText: '@',
              helperText: '3–20 characters: letters, numbers, _ or .',
              border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (v == null || v.isEmpty) return;
    final r = await acct.updateProfile(newUsername: v);
    if (mounted) _snack(r.ok ? 'Username saved: @${acct.username}' : (r.error ?? 'Failed'));
  }

  @override
  Widget build(BuildContext context) {
    final acct = context.watch<AccountService>();
    final social = context.watch<SocialService>();
    final pair = context.watch<PairState>();

    if (!acct.loggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chats')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(Icons.forum_rounded, size: 64, color: AppColors.emerald),
            const SizedBox(height: 12),
            const Text(
              'Sign in to chat, call and add friends by email or username.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const AccountScreen())),
              child: const Text('Sign in / Sign up'),
            ),
            if (pair.paired) ...[
              const SizedBox(height: 24),
              _partnerTile(pair),
            ],
          ],
        ),
      );
    }

    final incoming = social.friends.where((f) => !f.accepted && f.incoming).toList();
    final outgoing = social.friends.where((f) => !f.accepted && !f.incoming).toList();
    final accepted = social.friends.where((f) => f.accepted).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: RefreshIndicator(
        onRefresh: () async {
          await social.refreshFriends();
          await social.refreshInbox();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // My username card
            Card(
              child: ListTile(
                leading: const Icon(Icons.alternate_email_rounded, color: AppColors.emerald),
                title: Text(acct.username == null ? 'Set your username' : '@${acct.username}',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(acct.username == null
                    ? 'Friends can add you by username or by ${acct.email}'
                    : 'Friends can add you by @${acct.username} or ${acct.email}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (acct.username != null)
                    IconButton(
                      tooltip: 'Copy',
                      icon: const Icon(Icons.copy_rounded, size: 19),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: '@${acct.username}'));
                        _snack('Copied');
                      },
                    ),
                  IconButton(
                    tooltip: 'Edit',
                    icon: const Icon(Icons.edit_rounded, size: 19),
                    onPressed: () => _setUsername(acct),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 12),

            // Add friend
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Add a friend',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _addCtrl,
                            autocorrect: false,
                            keyboardType: TextInputType.emailAddress,
                            onSubmitted: (_) => _add(),
                            decoration: const InputDecoration(
                                hintText: 'Email or @username',
                                prefixIcon: Icon(Icons.person_add_alt_1_rounded),
                                border: OutlineInputBorder(),
                                isDense: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                          onPressed: _busy ? null : _add,
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            if (pair.paired) ...[
              _partnerTile(pair),
              const SizedBox(height: 12),
            ],

            if (incoming.isNotEmpty) ...[
              const _Header('Friend requests'),
              ...incoming.map((f) => Card(
                    child: ListTile(
                      leading: _avatar(f.name),
                      title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(f.username != null ? '@${f.username}' : 'wants to be your friend'),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          tooltip: 'Decline',
                          icon: const Icon(Icons.close_rounded, color: Colors.redAccent),
                          onPressed: () => social.respond(f, false),
                        ),
                        IconButton.filled(
                          tooltip: 'Accept',
                          style: IconButton.styleFrom(backgroundColor: AppColors.emerald),
                          icon: const Icon(Icons.check_rounded, color: Colors.white),
                          onPressed: () => social.respond(f, true),
                        ),
                      ]),
                    ),
                  )),
              const SizedBox(height: 8),
            ],

            const _Header('Chats'),
            if (accepted.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('No friends yet — add someone by email or username above.',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
              )
            else
              ...accepted.map((f) {
                final unread = social.unreadFor(f.thread) > 0;
                return Card(
                  child: ListTile(
                    leading: _avatar(f.name),
                    title: Text(f.name,
                        style: TextStyle(
                            fontWeight: unread ? FontWeight.w900 : FontWeight.w700)),
                    subtitle: Text(f.username != null ? '@${f.username}' : ''),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (unread)
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                              color: Colors.redAccent, shape: BoxShape.circle),
                        ),
                      PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'remove') {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text('Remove ${f.name}?'),
                                content: const Text('Your chat history with this friend will be deleted.'),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Cancel')),
                                  FilledButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Remove')),
                                ],
                              ),
                            );
                            if (ok == true) social.removeFriend(f);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'remove', child: Text('Remove friend')),
                        ],
                      ),
                    ]),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ChatScreen(
                            thread: f.thread,
                            title: f.name,
                            subtitle: f.username != null ? '@${f.username}' : null))),
                  ),
                );
              }),

            if (outgoing.isNotEmpty) ...[
              const SizedBox(height: 8),
              const _Header('Sent requests'),
              ...outgoing.map((f) => Card(
                    child: ListTile(
                      leading: _avatar(f.name),
                      title: Text(f.name),
                      subtitle: const Text('Waiting for them to accept'),
                      trailing: TextButton(
                          onPressed: () => social.removeFriend(f), child: const Text('Cancel')),
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _partnerTile(PairState pair) => Card(
        child: ListTile(
          leading: const CircleAvatar(
            backgroundColor: Colors.pinkAccent,
            child: Icon(Icons.favorite_rounded, color: Colors.white),
          ),
          title: Text(pair.partner?.name ?? 'Paired partner',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: const Text('Couple pairing chat · voice & video calls'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ChatScreen(
                  thread: 'pair:${pair.code}',
                  title: pair.partner?.name ?? 'Partner',
                  subtitle: 'Couple pairing'))),
        ),
      );

  Widget _avatar(String name) => CircleAvatar(
        backgroundColor: AppColors.emerald,
        child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      );
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 4),
        child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      );
}
