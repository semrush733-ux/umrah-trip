import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/api.dart';
import '../core/theme.dart';
import '../services/account_service.dart';
import '../services/device_state.dart';
import '../services/notifications_service.dart';
import '../services/social_service.dart';
import '../widgets/user_avatar.dart';
import '../widgets/volo_logo.dart';
import 'calls_screen.dart';
import 'chat_screen.dart';
import 'groups_screen.dart';
import 'sos_screen.dart';
import 'status_screens.dart';

const kInviteText =
    "Let's chat on Volo Chat — free messages, HD voice & video calls and Status. Download: https://github.com/semrush733-ux/umrah-trip/releases/tag/volo-latest";

/// Main shell: Chats · Status · Calls · Settings.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), NotificationsService.instance.requestPermission);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SocialService>();
    final unread = s.totalUnread;
    final missed = s.missedCallsUnseen;
    final status = s.unseenStatusCount;
    return Scaffold(
      body: IndexedStack(index: _tab, children: const [
        ChatsTab(),
        StatusTab(),
        CallsTab(),
        SettingsTab(),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        indicatorColor: VoloColors.violet.withValues(alpha: 0.25),
        onDestinationSelected: (i) {
          setState(() => _tab = i);
          if (i == 1) s.refreshStatus();
          if (i == 2) {
            s.refreshCallHistory();
            s.markCallsSeen();
          }
        },
        destinations: [
          NavigationDestination(
              icon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Icons.chat_bubble_outline_rounded)),
              selectedIcon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Icons.chat_bubble_rounded)),
              label: 'Chats'),
          NavigationDestination(
              icon: Badge(isLabelVisible: status > 0, smallSize: 9, child: const Icon(Icons.motion_photos_on_outlined)),
              selectedIcon: const Icon(Icons.motion_photos_on_rounded),
              label: 'Status'),
          NavigationDestination(
              icon: Badge(isLabelVisible: missed > 0, label: Text('$missed'), child: const Icon(Icons.call_outlined)),
              selectedIcon: const Icon(Icons.call_rounded),
              label: 'Calls'),
          const NavigationDestination(
              icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'Settings'),
        ],
      ),
    );
  }
}

String chatTime(DateTime t) {
  final now = DateTime.now();
  if (t.year == now.year && t.month == now.month && t.day == now.day) return DateFormat('HH:mm').format(t);
  final y = now.subtract(const Duration(days: 1));
  if (t.year == y.year && t.month == y.month && t.day == y.day) return 'Yesterday';
  if (now.difference(t).inDays < 7) return DateFormat('EEE').format(t);
  return DateFormat('d/M/yy').format(t);
}

void openChat(BuildContext context, String thread) {
  final s = context.read<SocialService>();
  final c = s.contactFor(thread);
  final g = s.groupFor(thread);
  Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatScreen(
            thread: thread,
            title: c?.user.displayName ?? g?.name ?? 'Chat',
            subtitle: g != null ? '${g.members.length} members' : (c?.user.phone),
          )));
}

// ============================================================ Chats

class ChatsTab extends StatefulWidget {
  const ChatsTab({super.key});
  @override
  State<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<ChatsTab> {
  String _q = '';
  bool _searching = false;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SocialService>();
    final threads = <(String, String, String?, ChatMessage?, bool)>[];
    for (final c in s.contacts) {
      threads.add((c.thread, c.user.displayName, c.user.avatar, s.latest[c.thread], c.user.online));
    }
    for (final g in s.groups) {
      threads.add((g.thread, g.name, null, s.latest[g.thread], false));
    }
    var list = threads.where((t) => t.$4 != null).toList()
      ..sort((a, b) => b.$4!.id.compareTo(a.$4!.id));
    if (_q.isNotEmpty) {
      list = threads.where((t) => t.$2.toLowerCase().contains(_q.toLowerCase())).toList();
    }
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Search…', filled: false, border: InputBorder.none),
                onChanged: (v) => setState(() => _q = v),
              )
            : const Row(children: [
                VoloLogo(size: 30),
                SizedBox(width: 10),
                Text('Volo Chat'),
              ]),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
            onPressed: () => setState(() {
              _searching = !_searching;
              _q = '';
            }),
          ),
          IconButton(
            tooltip: 'SOS',
            icon: const Icon(Icons.sos_rounded, color: Colors.redAccent),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SosScreen())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: VoloColors.mint,
        foregroundColor: VoloColors.ink,
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewChatScreen())),
        child: const Icon(Icons.add_comment_rounded),
      ),
      body: RefreshIndicator(
        onRefresh: s.refreshAll,
        child: list.isEmpty
            ? ListView(children: [
                const SizedBox(height: 110),
                const Center(child: VoloLogo(size: 90)),
                const SizedBox(height: 20),
                const Center(
                  child: Text('Start your first chat', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text('Tap + and add a friend by their phone number.',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                ),
              ])
            : ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final (thread, title, avatar, m, online) = list[i];
                  final u = s.unreadFor(thread);
                  final isGroup = thread.startsWith('grp:');
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Stack(children: [
                      isGroup
                          ? const CircleAvatar(
                              radius: 26,
                              backgroundColor: VoloColors.violet,
                              child: Icon(Icons.groups_rounded, color: Colors.white))
                          : UserAvatar(name: title, url: avatar, radius: 26),
                      if (online)
                        Positioned(
                          right: 1,
                          bottom: 1,
                          child: Container(
                            width: 13,
                            height: 13,
                            decoration: BoxDecoration(
                              color: VoloColors.mint,
                              shape: BoxShape.circle,
                              border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                            ),
                          ),
                        ),
                    ]),
                    title: Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    subtitle: m == null
                        ? null
                        : Row(children: [
                            if (m.mine && m.type != 'system') ...[
                              Icon(Icons.done_all_rounded, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                              const SizedBox(width: 3),
                            ],
                            Expanded(
                              child: Text(
                                isGroup && !m.mine && m.name.isNotEmpty ? '${m.name}: ${m.preview}' : m.preview,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: u > 0 ? FontWeight.w700 : FontWeight.w400),
                              ),
                            ),
                          ]),
                    trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                      if (m != null)
                        Text(chatTime(m.at),
                            style: TextStyle(
                                fontSize: 12,
                                color: u > 0 ? VoloColors.mint : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                fontWeight: u > 0 ? FontWeight.w800 : FontWeight.w400)),
                      const SizedBox(height: 4),
                      if (u > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: VoloColors.mint, borderRadius: BorderRadius.circular(12)),
                          child: Text('$u',
                              style: const TextStyle(color: VoloColors.ink, fontSize: 12, fontWeight: FontWeight.w900)),
                        ),
                    ]),
                    onTap: () => openChat(context, thread),
                  );
                },
              ),
      ),
    );
  }
}

/// Contacts list + add by number + new group.
class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});
  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  Future<void> _add() async {
    final ctrl = TextEditingController(text: '+92');
    final q = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New contact'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
                labelText: 'Phone number', helperText: 'With country code, or @username / email', prefixIcon: Icon(Icons.phone_rounded)),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Add')),
        ],
      ),
    );
    if (q == null || q.isEmpty || !mounted) return;
    final r = await context.read<SocialService>().addContact(q);
    if (!mounted) return;
    if (r.ok) {
      final thread = '${(r.data['contact'] as Map)['thread']}';
      Navigator.of(context).pop();
      openChat(context, thread);
    } else {
      final notFound = r.status == 404;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(r.error ?? 'Failed'),
        action: notFound
            ? SnackBarAction(
                label: 'Invite',
                onPressed: () => Share.share(kInviteText))
            : null,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SocialService>();
    final list = [...s.contacts]..sort((a, b) => a.user.displayName.toLowerCase().compareTo(b.user.displayName.toLowerCase()));
    return Scaffold(
      appBar: AppBar(title: const Text('New chat')),
      body: ListView(children: [
        ListTile(
          leading: const CircleAvatar(backgroundColor: VoloColors.mint, child: Icon(Icons.person_add_alt_1_rounded, color: VoloColors.ink)),
          title: const Text('New contact', style: TextStyle(fontWeight: FontWeight.w800)),
          subtitle: const Text('Add by phone number'),
          onTap: _add,
        ),
        ListTile(
          leading: const CircleAvatar(backgroundColor: VoloColors.violet, child: Icon(Icons.group_add_rounded, color: Colors.white)),
          title: const Text('New group', style: TextStyle(fontWeight: FontWeight.w800)),
          subtitle: const Text('Family, friends, travel buddies'),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateGroupScreen())),
        ),
        ListTile(
          leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.share_rounded, color: Colors.white)),
          title: const Text('Invite friends', style: TextStyle(fontWeight: FontWeight.w800)),
          onTap: () => Share.share(kInviteText),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
          child: Text('Contacts on Volo Chat (${list.length})',
              style: TextStyle(fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
        ),
        ...list.map((c) => ListTile(
              leading: UserAvatar(name: c.user.displayName, url: c.user.avatar),
              title: Text(c.user.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(c.user.about, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () {
                Navigator.of(context).pop();
                openChat(context, c.thread);
              },
            )),
      ]),
    );
  }
}

// ============================================================ Calls tab

class CallsTab extends StatelessWidget {
  const CallsTab({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Calls')),
        body: const CallHistoryView(),
      );
}

// ============================================================ Settings

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  Future<void> _edit(BuildContext context, String title, String initial, Future<dynamic> Function(String) save,
      {int max = 40}) async {
    final ctrl = TextEditingController(text: initial);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctrl, autofocus: true, maxLength: max),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (v == null) return;
    final r = await save(v);
    if (context.mounted && r is ApiResult && !r.ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.error ?? 'Failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final acct = context.watch<AccountService>();
    final s = context.watch<SocialService>();
    final dev = context.watch<DeviceState>();
    final me = acct.me;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(gradient: VoloColors.brandGradient, borderRadius: BorderRadius.circular(24)),
          child: Row(children: [
            GestureDetector(
              onTap: () async {
                final x = await ImagePicker()
                    .pickImage(source: ImageSource.gallery, maxWidth: 600, maxHeight: 600, imageQuality: 80);
                if (x != null) await acct.setAvatar(await x.readAsBytes());
              },
              child: Stack(children: [
                UserAvatar(name: me?.displayName ?? '?', url: me?.avatar, radius: 36),
                const Positioned(
                  right: 0,
                  bottom: 0,
                  child: CircleAvatar(radius: 12, backgroundColor: VoloColors.mint, child: Icon(Icons.camera_alt_rounded, size: 13, color: VoloColors.ink)),
                ),
              ]),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(me?.displayName ?? '', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                Text(me?.phone ?? '', style: const TextStyle(color: Colors.white70)),
                if (me?.username != null) Text('@${me!.username}', style: const TextStyle(color: VoloColors.mint)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        Card(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.person_rounded),
              title: const Text('Name'),
              subtitle: Text(me?.name ?? ''),
              onTap: () => _edit(context, 'Your name', me?.name ?? '', (v) => acct.updateProfile(name: v)),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('About'),
              subtitle: Text(me?.about ?? ''),
              onTap: () => _edit(context, 'About', me?.about ?? '', (v) => acct.updateProfile(about: v), max: 140),
            ),
            ListTile(
              leading: const Icon(Icons.alternate_email_rounded),
              title: const Text('Username'),
              subtitle: Text(me?.username != null ? '@${me!.username}' : 'Not set — lets people find you without your number'),
              onTap: () => _edit(context, 'Username', me?.username ?? '', (v) => acct.updateProfile(username: v), max: 20),
            ),
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Email'),
              subtitle: Text(me?.email == null ? 'Not added' : '${me!.email}${me.emailVerified ? '  ✓ verified' : ''}'),
            ),
          ]),
        ),
        Card(
          child: Column(children: [
            SwitchListTile(
              secondary: const Icon(Icons.dark_mode_rounded),
              title: const Text('Dark mode'),
              value: dev.themeMode == ThemeMode.dark,
              onChanged: (v) => dev.setThemeMode(v ? ThemeMode.dark : ThemeMode.light),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.share_location_rounded),
              title: const Text('Share live location with my groups'),
              subtitle: const Text('Members see you on the group map'),
              value: s.shareGroupLocation,
              onChanged: s.setShareGroupLocation,
            ),
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('Notifications'),
              subtitle: const Text('Allow messages and calls to alert you'),
              onTap: () => NotificationsService.instance.requestPermission(),
            ),
            ListTile(
              leading: const Icon(Icons.sos_rounded, color: Colors.redAccent),
              title: const Text('SOS'),
              subtitle: const Text('Send your location to your groups in an emergency'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SosScreen())),
            ),
          ]),
        ),
        Card(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Log out'),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Log out?'),
                    content: const Text('You can sign in again with your phone number.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log out')),
                    ],
                  ),
                );
                if (ok == true) acct.logout();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
              title: const Text('Delete my account', style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete account?'),
                    content: const Text('Your profile, contacts, groups and status updates will be removed. This cannot be undone.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Delete')),
                    ],
                  ),
                );
                if (ok == true) acct.deleteAccount();
              },
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text('Volo Chat · by BWP Experts',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 12)),
        ),
      ]),
    );
  }
}
