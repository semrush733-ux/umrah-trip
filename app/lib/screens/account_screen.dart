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
      _snack('Email aur password likhein');
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
        _snack(r.ok ? 'Account ban gaya ✓ — data cloud par mehfooz' : (r.error ?? 'Error'));
        return;
      }

      final r = await acct.login(_email.text, _pass.text);
      if (!mounted) return;
      if (!r.ok) {
        _snack(r.error ?? 'Login failed');
        return;
      }
      final cloud = r.data['data'];
      final hasCloud = cloud is Map && cloud.isNotEmpty;
      if (!hasCloud) {
        await acct.keepLocal();
        if (mounted) _snack('Login ho gaya ✓');
        return;
      }
      if (!app.hasLocalData) {
        await acct.applyCloud(Map<String, dynamic>.from(cloud));
        if (mounted) _snack('Login ho gaya ✓ — aapka sara data wapas aa gaya');
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
          title: const Text('Kaunsa data rakhna hai?'),
          content: Text(
              'Aapke account mein cloud backup mojood hai${when.isEmpty ? '' : ' ($when)'}, '
              'aur is phone par bhi kuch data hai.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, 'local'),
                child: const Text('Is phone ka rakhein')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, 'cloud'),
                child: const Text('Cloud se restore')),
          ],
        ),
      );
      if (choice == 'cloud') {
        await acct.applyCloud(Map<String, dynamic>.from(cloud));
        if (mounted) _snack('Restore ho gaya ✓');
      } else {
        await acct.keepLocal();
        if (mounted) _snack('Is phone ka data cloud par save ho gaya ✓');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final acct = context.watch<AccountService>();
    return Scaffold(
      appBar: AppBar(title: Text(acct.loggedIn ? 'My Account' : 'Login / Sign up')),
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
              ? 'Account banayen — aapka trip, visits, notes aur pairing hamesha mehfooz rahenge, app dobara install karne par bhi.'
              : 'Login karein — aapka sara data wapas aa jayega.',
          textAlign: TextAlign.center,
          style: const TextStyle(height: 1.5),
        ),
        const SizedBox(height: 18),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Login'), icon: Icon(Icons.login_rounded)),
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
                labelText: 'Naam',
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
            labelText: 'Password (kam az kam 6)',
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
              : Text(_registerMode ? 'Account banayen' : 'Login'),
        ),
        const SizedBox(height: 14),
        Text(
          'Account ke baghair bhi app poori chalti hai (Guest mode). Password bhool jayen to admin se reset karwa sakte hain.',
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
                ? 'Backup ho raha hai…'
                : acct.lastBackupAt == null
                    ? 'Abhi backup nahi hua'
                    : 'Last backup: ${DateFormat('d MMM, HH:mm').format(acct.lastBackupAt!)}'),
            subtitle: Text(acct.lastError ??
                'Har tabdeeli khud-ba-khud cloud par save hoti hai (trip, visits, notes, favourites, kharche, hotel, settings, pairing).'),
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
                          _snack(ok ? 'Backup ho gaya ✓' : (acct.lastError ?? 'Failed'));
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
                            title: const Text('Cloud se restore?'),
                            content: const Text(
                                'Is phone ka maujooda data cloud backup se badal diya jayega.'),
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
                          _snack(ok ? 'Restore ho gaya ✓' : (acct.lastError ?? 'Failed'));
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
                    _snack('Logout ho gaya (data is phone par bhi mojood hai)');
                  }
                },
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Logout'),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
          onPressed: _busy ? null : () => _deleteAccount(acct),
          icon: const Icon(Icons.delete_forever_rounded),
          label: const Text('Account delete karein'),
        ),
      ];

  Future<void> _deleteAccount(AccountService acct) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Account hamesha ke liye delete?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Cloud backup mita diya jayega. Is phone ka data rahega.'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: 'Password confirm', border: OutlineInputBorder()),
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
      _snack(r.ok ? 'Account delete ho gaya' : (r.error ?? 'Failed'));
    }
  }
}
