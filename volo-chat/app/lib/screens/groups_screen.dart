import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/account_service.dart';
import '../services/device_state.dart';
import '../services/social_service.dart';
import '../widgets/user_avatar.dart';
import 'chat_screen.dart';
import 'chat_widgets.dart';

/// Pick friends for a new group (or to add to an existing one).
class CreateGroupScreen extends StatefulWidget {
  final ChatGroup? addTo; // null → create a new group
  const CreateGroupScreen({super.key, this.addTo});
  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _name = TextEditingController();
  final Set<int> _picked = {};
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final social = context.read<SocialService>();
    final adding = widget.addTo != null;
    if (!adding && _name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Give the group a name, e.g. "Family Umrah 2026"')));
      return;
    }
    if (_picked.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick at least one friend')));
      return;
    }
    setState(() => _busy = true);
    final r = adding
        ? await social.addToGroup(widget.addTo!.id, _picked.toList())
        : await social.createGroup(_name.text.trim(), _picked.toList());
    if (!mounted) return;
    setState(() => _busy = false);
    if (!r.ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.error ?? 'Failed')));
      return;
    }
    if (adding) {
      Navigator.pop(context);
      return;
    }
    final g = ChatGroup.fromJson(Map<String, dynamic>.from(r.data['group'] as Map));
    Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => ChatScreen(thread: g.thread, title: g.name, subtitle: '${g.members.length} members')));
  }

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialService>();
    final already = widget.addTo?.members.map((m) => m.id).toSet() ?? <int>{};
    final friends = social.contacts.where((c) => !already.contains(c.user.id)).map((c) => c.user).toList();
    return Scaffold(
      appBar: AppBar(title: Text(widget.addTo == null ? 'New group' : 'Add to ${widget.addTo!.name}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.addTo == null) ...[
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  labelText: 'Group name',
                  hintText: 'e.g. Family Umrah 2026',
                  prefixIcon: Icon(Icons.groups_rounded),
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
          ],
          const Text('Choose contacts', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 6),
          if (friends.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No contacts to add yet — start a chat with someone first.'),
            ),
          ...friends.map((f) => CheckboxListTile(
                value: _picked.contains(f.id),
                onChanged: (v) => setState(() => v == true ? _picked.add(f.id) : _picked.remove(f.id)),
                secondary: UserAvatar(name: f.name, url: f.avatar),
                title: Text(f.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: f.username != null ? Text('@${f.username}') : null,
              )),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            onPressed: _busy ? null : _save,
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_rounded),
            label: Text(widget.addTo == null ? 'Create group' : 'Add ${_picked.length} to group'),
          ),
        ),
      ),
    );
  }
}

/// Members list, add people, leave group.
class GroupInfoScreen extends StatelessWidget {
  final int groupId;
  const GroupInfoScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialService>();
    final me = context.read<AccountService>();
    ChatGroup? g;
    for (final x in social.groups) {
      if (x.id == groupId) g = x;
    }
    if (g == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('You are no longer in this group')));
    }
    final group = g;
    return Scaffold(
      appBar: AppBar(title: Text(group.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.map_rounded, color: AppColors.emerald),
              title: const Text('Group map & meeting point', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('See where everyone is and set a place to meet'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => GroupMapScreen(group: group))),
            ),
          ),
          const SizedBox(height: 12),
          Text('${group.members.length} members',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ...group.members.map((m) => ListTile(
                leading: UserAvatar(name: m.name, url: m.avatar),
                title: Text(m.displayName + (m.id == me.me?.id ? ' (you)' : '')),
                subtitle: m.username != null ? Text('@${m.username}') : null,
                trailing: m.id == group.owner ? const Text('Admin', style: TextStyle(color: AppColors.gold)) : null,
              )),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => CreateGroupScreen(addTo: group))),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Add members'),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('Leave ${group.name}?'),
                  content: const Text('You will stop getting its messages and SOS alerts.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Leave')),
                  ],
                ),
              );
              if (ok != true || !context.mounted) return;
              await social.leaveGroup(group.id);
              if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Leave group'),
          ),
        ],
      ),
    );
  }
}

/// Asks for a short label ("Gate 79", "Clock tower") for a meeting point.
Future<String?> askMeetLabel(BuildContext context) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Set meeting point'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
            hintText: 'e.g. King Fahd Gate (79)', border: OutlineInputBorder()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Share')),
      ],
    ),
  );
}

/// Everyone in the group on one map + the meeting point.
class GroupMapScreen extends StatefulWidget {
  final ChatGroup group;
  const GroupMapScreen({super.key, required this.group});
  @override
  State<GroupMapScreen> createState() => _GroupMapScreenState();
}

class _GroupMapScreenState extends State<GroupMapScreen> {
  final _map = MapController();
  List<MemberLocation> _members = [];
  MeetPoint? _meet;
  Timer? _timer;
  bool _picking = false;
  bool _fitted = false;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final social = context.read<SocialService>();
    if (social.shareGroupLocation) await social.pushLocationNow();
    final r = await social.groupLocations(widget.group.id);
    if (!mounted || r == null) return;
    setState(() {
      _members = r.$1;
      _meet = r.$2;
    });
    if (!_fitted) {
      _fitted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
    }
  }

  List<LatLng> get _points => [
        for (final m in _members)
          if (m.lat != null && m.lng != null) LatLng(m.lat!, m.lng!),
        if (_meet != null) LatLng(_meet!.lat, _meet!.lng),
      ];

  void _fit() {
    final pts = _points;
    try {
      if (pts.isEmpty) return;
      if (pts.length == 1) {
        _map.move(pts.first, 16.5);
      } else {
        _map.fitCamera(CameraFit.coordinates(
            coordinates: pts, padding: const EdgeInsets.all(60), maxZoom: 17));
      }
    } catch (_) {}
  }

  Future<void> _setMeetAt(LatLng p) async {
    setState(() => _picking = false);
    final label = await askMeetLabel(context);
    if (label == null || !mounted) return;
    final r = await context.read<SocialService>().setMeet(widget.group.thread, p.latitude, p.longitude, label);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(r.ok ? 'Meeting point shared with the group' : (r.error ?? 'Failed'))));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialService>();
    final app = context.watch<DeviceState>();
    final myPos = app.position;
    final fresh = DateTime.now().subtract(const Duration(minutes: 10));
    return Scaffold(
      appBar: AppBar(title: Text(widget.group.name)),
      body: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.share_location_rounded, color: AppColors.emerald),
            title: const Text('Share my live location with my groups',
                style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(social.shareGroupLocation ? 'ON — members can see you on this map' : 'Off'),
            value: social.shareGroupLocation,
            onChanged: (v) async {
              await social.setShareGroupLocation(v);
              _load();
            },
          ),
          Expanded(
            child: Stack(children: [
              FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: myPos != null
                      ? LatLng(myPos.latitude, myPos.longitude)
                      : const LatLng(21.4225, 39.8262),
                  initialZoom: 15,
                  maxZoom: 18.5,
                  interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                  onTap: (_, p) {
                    if (_picking) _setMeetAt(p);
                  },
                  onLongPress: (_, p) => _setMeetAt(p),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.bwpexperts.umrah_journey',
                    maxNativeZoom: 19,
                  ),
                  MarkerLayer(markers: [
                    if (_meet != null)
                      Marker(
                        point: LatLng(_meet!.lat, _meet!.lng),
                        width: 120,
                        height: 58,
                        child: Column(children: [
                          const Icon(Icons.push_pin_rounded, color: Colors.redAccent, size: 34),
                          Text(_meet!.label.isEmpty ? 'Meet here' : _meet!.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w900, color: Colors.redAccent)),
                        ]),
                      ),
                    for (final m in _members)
                      if (m.lat != null && m.lng != null)
                        Marker(
                          point: LatLng(m.lat!, m.lng!),
                          width: 80,
                          height: 66,
                          child: Opacity(
                            opacity: (m.at != null && m.at!.isAfter(fresh)) ? 1 : 0.5,
                            child: Column(children: [
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                    color: m.me ? Colors.blue : AppColors.emerald, shape: BoxShape.circle),
                                child: UserAvatar(name: m.user.name, url: m.user.avatar, radius: 18),
                              ),
                              Text(m.me ? 'Me' : m.user.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: m.me ? Colors.blue : AppColors.emerald)),
                            ]),
                          ),
                        ),
                  ]),
                ],
              ),
              Positioned(
                left: 4,
                bottom: 2,
                child: Text('© OpenStreetMap',
                    style: TextStyle(fontSize: 9, color: Colors.black.withValues(alpha: 0.6))),
              ),
              Positioned(
                right: 10,
                top: 10,
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: IconButton(
                    tooltip: 'Show everyone',
                    icon: const Icon(Icons.center_focus_strong_rounded, color: AppColors.emerald),
                    onPressed: _fit,
                  ),
                ),
              ),
              if (_picking)
                Positioned(
                  left: 12,
                  right: 12,
                  top: 10,
                  child: Card(
                    color: AppColors.emerald,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(children: [
                        const Expanded(
                          child: Text('Tap the map where everyone should meet',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        ),
                        TextButton(
                            onPressed: () => setState(() => _picking = false),
                            child: const Text('Cancel', style: TextStyle(color: Colors.white))),
                      ]),
                    ),
                  ),
                ),
            ]),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (_meet != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.push_pin_rounded, color: Colors.redAccent),
                    title: Text(_meet!.label.isEmpty ? 'Meeting point' : _meet!.label,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(
                        'Set by ${_meet!.by} at ${DateFormat('HH:mm').format(_meet!.at)}'
                        '${myPos != null ? ' · ${fmtDistance(const Distance().as(LengthUnit.Meter, LatLng(myPos.latitude, myPos.longitude), LatLng(_meet!.lat, _meet!.lng)))} from you' : ''}'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        tooltip: 'Remove',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () async {
                          await social.clearMeet(widget.group.thread);
                          _load();
                        },
                      ),
                      FilledButton.icon(
                        onPressed: () => openWalkingRoute(_meet!.lat, _meet!.lng),
                        icon: const Icon(Icons.directions_walk_rounded, size: 18),
                        label: const Text('Route'),
                      ),
                    ]),
                  ),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => _picking = true),
                      icon: const Icon(Icons.add_location_alt_rounded),
                      label: Text(_meet == null ? 'Set meeting point' : 'Change meeting point'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: myPos == null ? null : () => _setMeetAt(LatLng(myPos.latitude, myPos.longitude)),
                      icon: const Icon(Icons.my_location_rounded),
                      label: const Text('Meet where I am'),
                    ),
                  ),
                ]),
                Text(
                  '${_members.where((m) => m.lat != null).length} of ${_members.length} sharing location · long-press the map to drop a pin',
                  style: TextStyle(
                      fontSize: 11.5, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
