import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/account_service.dart';
import '../services/app_state.dart';

/// Login / Register / account management with cloud backup & restore.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _registerMode = false;
  bool _busy = false;
  bool _showPass = false;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _submit() async {
    final acct = context.read<AccountService>();
    final app = context.read<AppState>();
    if (_email.text.trim().isEmpty || _pass.text.isEmpty) {
      _snack('Please enter your email and password');
      return;
    }
    setState(() => _busy = true);
    try {
      if (_registerMode) {
        final r = await acct.register(
            _name.text.trim().isEmpty ? 'Pilgrim' : _name.text.trim(),
            _email.text,
            _pass.text);
        if (!mounted) return;
        _snack(r.ok ? 'Account created ✓ — your data is safe in the cloud' : (r.error ?? 'Error'));
        return;
      }

      final r = await acct.login(_email.text, _pass.text);
      if (!mounted) return;
      if (!r.ok) {
        _snack(r.error ?? 'Sign-in failed');
        return;
      }
      final cloud = r.data['data'];
      final hasCloud = cloud is Map && cloud.isNotEmpty;
      if (!hasCloud) {
        await acct.keepLocal();
        if (mounted) _snack('Signed in ✓');
        return;
      }
      if (!app.hasLocalData) {
        await acct.applyCloud(Map<String, dynamic>.from(cloud));
        if (mounted) _snack('Signed in ✓ — all your data has been restored');
        return;
      }
      // Both have data → let the user choose.
      final ts = int.tryParse('${r.data['data_updated']}') ?? 0;
      final when = ts == 0
          ? ''
          : DateFormat('d MMM yyyy, HH:mm')
              .format(DateTime.fromMillisecondsSinceEpoch(ts * 1000));
      final choice = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Which data would you like to keep?'),
          content: Text(
              'Your account has a cloud backup${when.isEmpty ? '' : ' ($when)'}, '
              'and this phone also has some data.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, 'local'),
                child: const Text('Keep this phone\'s data')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, 'cloud'),
                child: const Text('Restore from cloud')),
          ],
        ),
      );
      if (choice == 'cloud') {
        await acct.applyCloud(Map<String, dynamic>.from(cloud));
        if (mounted) _snack('Restored ✓');
      } else {
        await acct.keepLocal();
        if (mounted) _snack('This phone\'s data has been saved to the cloud ✓');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final acct = context.watch<AccountService>();
    return Scaffold(
      appBar: AppBar(title: Text(acct.loggedIn ? 'My Account' : 'Sign in / Sign up')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: acct.loggedIn ? _accountView(acct) : _authForm(),
      ),
    );
  }

  List<Widget> _authForm() => [
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset('assets/images/logo.png', width: 110, height: 110),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _registerMode
              ? 'Create an account — your trip, visits, notes and pairing stay safe, even if you reinstall the app.'
              : 'Sign in — all your data will be restored.',
          textAlign: TextAlign.center,
          style: const TextStyle(height: 1.5),
        ),
        const SizedBox(height: 18),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Sign in'), icon: Icon(Icons.login_rounded)),
            ButtonSegment(
                value: true, label: Text('Sign up'), icon: Icon(Icons.person_add_rounded)),
          ],
          selected: {_registerMode},
          onSelectionChanged: (v) => setState(() => _registerMode = v.first),
        ),
        const SizedBox(height: 16),
        if (_registerMode) ...[
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.person_rounded),
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_rounded),
              border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pass,
          obscureText: !_showPass,
          decoration: InputDecoration(
            labelText: 'Password (at least 6 characters)',
            prefixIcon: const Icon(Icons.lock_rounded),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(_showPass ? Icons.visibility_off_rounded : Icons.visibility_rounded),
              onPressed: () => setState(() => _showPass = !_showPass),
            ),
          ),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
              : Text(_registerMode ? 'Create account' : 'Sign in'),
        ),
        const SizedBox(height: 14),
        Text(
          'The app works fully without an account (guest mode). If you forget your password, the administrator can reset it.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55)),
        ),
      ];

  List<Widget> _accountView(AccountService acct) => [
        Card(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [AppColors.emerald, AppColors.emeraldDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
            ),
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.gold,
                  child: Text(
                    (acct.name?.isNotEmpty ?? false) ? acct.name![0].toUpperCase() : '?',
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.slate),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(acct.name ?? '',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                      Text(acct.email ?? '',
                          style: TextStyle(color: AppColors.goldLight.withValues(alpha: 0.95))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: Icon(
                acct.backingUp ? Icons.cloud_upload_rounded : Icons.cloud_done_rounded,
                color: acct.lastError == null ? Colors.green : Colors.orange),
            title: Text(acct.backingUp
                ? 'Backing up…'
                : acct.lastBackupAt == null
                    ? 'No backup yet'
                    : 'Last backup: ${DateFormat('d MMM, HH:mm').format(acct.lastBackupAt!)}'),
            subtitle: Text(acct.lastError ??
                'Every change is saved to the cloud automatically (trip, visits, notes, favourites, expenses, hotel, settings, pairing).'),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        final ok = await acct.backupNow(force: true);
                        if (mounted) {
                          setState(() => _busy = false);
                          _snack(ok ? 'Backed up ✓' : (acct.lastError ?? 'Failed'));
                        }
                      },
                icon: const Icon(Icons.cloud_upload_rounded),
                label: const Text('Backup now'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 56)),
                onPressed: _busy
                    ? null
                    : () async {
                        final sure = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Restore from cloud?'),
                            content: const Text(
                                'The data currently on this phone will be replaced by the cloud backup.'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel')),
                              FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Restore')),
                            ],
                          ),
                        );
                        if (sure != true) return;
                        setState(() => _busy = true);
                        final ok = await acct.restoreFromCloud();
                        if (mounted) {
                          setState(() => _busy = false);
                          _snack(ok ? 'Restored ✓' : (acct.lastError ?? 'Failed'));
                        }
                      },
                icon: const Icon(Icons.cloud_download_rounded),
                label: const Text('Restore'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  await acct.logout();
                  if (mounted) {
                    setState(() => _busy = false);
                    _snack('Signed out (your data is still on this phone)');
                  }
                },
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Sign out'),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
          onPressed: _busy ? null : () => _deleteAccount(acct),
          icon: const Icon(Icons.delete_forever_rounded),
          label: const Text('Delete account'),
        ),
      ];

  Future<void> _deleteAccount(AccountService acct) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permanently delete your account?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Your cloud backup will be erased. The data on this phone will remain.'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: 'Confirm password', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    final r = await acct.deleteAccount(ctrl.text);
    if (mounted) {
      setState(() => _busy = false);
      _snack(r.ok ? 'Account deleted' : (r.error ?? 'Failed'));
    }
  }
}
