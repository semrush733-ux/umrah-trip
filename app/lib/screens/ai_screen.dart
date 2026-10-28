import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/app_state.dart';
import '../services/site_service.dart';

/// AI travel assistant — questions answered through the website's secure
/// proxy (the API key lives on the server, never in the app).
class AiScreen extends StatefulWidget {
  const AiScreen({super.key});
  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _Msg {
  final bool me;
  final String text;
  const _Msg(this.me, this.text);
}

class _AiScreenState extends State<AiScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final List<_Msg> _messages = [
    const _Msg(false,
        'Assalamu alaikum! 🌙 I am your Umrah travel assistant. Ask me anything about ziyarat, routes, timings or Umrah rulings.\n(For religious rulings, please always confirm with a qualified scholar.)'),
  ];
  bool _busy = false;

  static const _suggestions = [
    'When is the best time to visit Masjid Quba?',
    'Plan a one-day ziyarat itinerary in Madinah',
    'How do I perform the seven circuits of Tawaf?',
    'How should I plan a day trip to Taif?',
  ];

  Future<void> _send([String? preset]) async {
    final q = (preset ?? _ctrl.text).trim();
    if (q.isEmpty || _busy) return;
    _ctrl.clear();
    setState(() {
      _messages.add(_Msg(true, q));
      _busy = true;
    });
    _jump();
    final app = context.read<AppState>();
    final site = context.read<SiteService>();
    final ctx =
        'User is an Umrah pilgrim using the Umrah Trip app. Active city: ${app.activeRegion}. '
        'Planned visits: ${app.planner.counters().planned}, visited: ${app.planner.counters().visited}. '
        'Answer briefly and practically in the user\'s language (British English unless they write in Urdu). '
        'For fiqh rulings advise confirming with a scholar; never invent facts, fees or times.';
    final answer = await site.askAi(q, context: ctx);
    if (!mounted) return;
    setState(() {
      _messages.add(_Msg(false, answer));
      _busy = false;
    });
    _jump();
  }

  void _jump() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent + 80,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final site = context.watch<SiteService>();
    return Scaffold(
      appBar: AppBar(title: const Text('AI Assistant')),
      body: Column(
        children: [
          if (!site.aiEnabled)
            Container(
              width: double.infinity,
              color: Colors.orange.withValues(alpha: 0.15),
              padding: const EdgeInsets.all(10),
              child: const Text(
                'AI has not been set up on the website yet (Admin → Umrah Trip App → AI API key). The chat will work as soon as the key is added.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(14),
              itemCount: _messages.length + (_busy ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _messages.length) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Row(children: [
                      SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 10),
                      Text('Thinking…'),
                    ]),
                  );
                }
                final m = _messages[i];
                return Align(
                  alignment:
                      m.me ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
                  child: Container(
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * 0.82),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: m.me
                          ? AppColors.emerald
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(m.me ? 16 : 4),
                        bottomRight: Radius.circular(m.me ? 4 : 16),
                      ),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 8),
                      ],
                    ),
                    child: SelectableText(m.text,
                        style: TextStyle(
                            color: m.me ? Colors.white : null, height: 1.45)),
                  ),
                );
              },
            ),
          ),
          if (_messages.length <= 1)
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: _suggestions
                    .map((s) => Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: ActionChip(
                              label: Text(s, style: const TextStyle(fontSize: 12)),
                              onPressed: () => _send(s)),
                        ))
                    .toList(),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Type your question…',
                        filled: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton.small(
                    onPressed: _busy ? null : _send,
                    child: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
