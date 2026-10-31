import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/account_service.dart';
import '../services/social_service.dart';
import '../widgets/user_avatar.dart';
import 'call_screen.dart';

/// List of recent calls: who, incoming/outgoing/missed, when, how long.
class CallHistoryView extends StatefulWidget {
  const CallHistoryView({super.key});
  @override
  State<CallHistoryView> createState() => _CallHistoryViewState();
}

class _CallHistoryViewState extends State<CallHistoryView> {
  @override
  void initState() {
    super.initState();
    context.read<SocialService>().refreshCallHistory();
  }

  String _when(DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(t.year, t.month, t.day);
    final hm = DateFormat('HH:mm').format(t);
    if (d == today) return 'Today, $hm';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday, $hm';
    if (now.difference(t).inDays < 7) return '${DateFormat('EEEE').format(t)}, $hm';
    return DateFormat('d MMM yyyy, HH:mm').format(t);
  }

  String _dur(int s) {
    if (s <= 0) return '';
    final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${sec}s';
    return '${sec}s';
  }

  ({IconData icon, Color color, String label}) _kind(CallRecord c) {
    if (c.answered) {
      return c.outgoing
          ? (icon: Icons.call_made_rounded, color: Colors.green, label: 'Outgoing')
          : (icon: Icons.call_received_rounded, color: Colors.green, label: 'Incoming');
    }
    if (c.outgoing) {
      final l = switch (c.status) {
        'declined' => 'Declined',
        'busy' => 'Busy',
        'ringing' => 'Ringing…',
        _ => 'Not answered',
      };
      return (icon: Icons.call_made_rounded, color: Colors.orange, label: l);
    }
    final l = switch (c.status) {
      'declined' => 'Declined by you',
      'busy' => 'Missed (you were busy)',
      'ringing' => 'Ringing…',
      _ => 'Missed',
    };
    return (icon: Icons.call_missed_rounded, color: Colors.redAccent, label: l);
  }

  void _callBack(CallRecord c, {bool? video}) {
    Navigator.of(context).push(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CallScreen.outgoing(
            thread: c.thread,
            peerName: c.peer,
            peerAvatar: c.avatar,
            video: video ?? c.video)));
  }

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialService>();
    final loggedIn = context.watch<AccountService>().loggedIn;
    final calls = social.callHistory;
    if (!loggedIn) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Sign in to see your calls.', textAlign: TextAlign.center),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: social.refreshCallHistory,
      child: calls.isEmpty
          ? ListView(children: [
              const SizedBox(height: 80),
              const Icon(Icons.call_rounded, size: 56, color: AppColors.emerald),
              const SizedBox(height: 10),
              Text(
                social.callHistoryError ?? 'No calls yet',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
            ])
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: calls.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
              itemBuilder: (_, i) {
                final c = calls[i];
                final k = _kind(c);
                final d = _dur(c.duration);
                return ListTile(
                  leading: UserAvatar(name: c.peer, url: c.avatar),
                  title: Text(c.peer,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: c.missedByMe ? Colors.redAccent : null)),
                  subtitle: Row(children: [
                    Icon(k.icon, size: 16, color: k.color),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${k.label} · ${_when(c.at)}${d.isNotEmpty ? ' · $d' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                  trailing: IconButton(
                    tooltip: c.video ? 'Video call' : 'Voice call',
                    icon: Icon(c.video ? Icons.videocam_rounded : Icons.call_rounded,
                        color: AppColors.emerald),
                    onPressed: () => _callBack(c),
                  ),
                  onTap: () => _callBack(c),
                );
              },
            ),
    );
  }
}
