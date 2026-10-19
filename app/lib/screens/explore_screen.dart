import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/strings.dart';
import '../services/app_state.dart';
import '../widgets/destination_card.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  String _query = '';
  String? _region;
  String? _category; // mosque / islamic_historical / museum / nature / attraction / family
  bool _freeOnly = false;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = S.of(context);

    var list = app.repo.all.where((d) => d.matches(_query)).toList();
    if (_region != null) list = list.where((d) => d.region == _region).toList();
    if (_category != null) {
      list = list.where((d) => d.categories.contains(_category)).toList();
    }
    if (_freeOnly) list = list.where((d) => d.isFreeVerified).toList();

    final categories = <(String, String)>[
      ('islamic_historical', s.islamicSites),
      ('mosque', s.mosques),
      ('museum', s.museums),
      ('nature', s.natureMountains),
      ('attraction', s.attractions),
      ('family', s.familyFriendly),
    ];

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(s.explore,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: s.searchHint,
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _chip(s.all, _region == null && _category == null && !_freeOnly, () {
                  setState(() {
                    _region = null;
                    _category = null;
                    _freeOnly = false;
                  });
                }),
                ...app.repo.regions.map((r) => _chip(
                    s.regionName(r), _region == r, () => setState(() => _region = _region == r ? null : r))),
                ...categories.map((c) => _chip(c.$2, _category == c.$1,
                    () => setState(() => _category = _category == c.$1 ? null : c.$1))),
                _chip(s.freeEntry, _freeOnly, () => setState(() => _freeOnly = !_freeOnly)),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? Center(child: Text('—  ${s.all}: 0'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => DestinationCard(destination: list[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: FilterChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
        ),
      );
}
