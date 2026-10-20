import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, Clipboard, ClipboardData;
import 'package:flutter_tts/flutter_tts.dart';

import '../core/theme.dart';

/// Duas & Azkar — Umrah, travel and daily remembrances with Arabic text,
/// transliteration, Urdu + English meaning, references, copy and listen.
/// Fully offline (TTS uses the device engine).
class DuasScreen extends StatefulWidget {
  const DuasScreen({super.key});
  @override
  State<DuasScreen> createState() => _DuasScreenState();
}

class _DuasScreenState extends State<DuasScreen> {
  List<dynamic> _categories = [];
  final FlutterTts _tts = FlutterTts();
  String? _speakingKey;

  @override
  void initState() {
    super.initState();
    rootBundle.loadString('assets/data/duas.json').then((raw) {
      if (mounted) {
        setState(() =>
            _categories = (json.decode(raw) as Map<String, dynamic>)['categories']);
      }
    });
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _speak(String key, String arabic) async {
    if (_speakingKey == key) {
      await _tts.stop();
      setState(() => _speakingKey = null);
      return;
    }
    try {
      await _tts.setLanguage('ar-SA');
    } catch (_) {}
    setState(() => _speakingKey = key);
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _speakingKey = null);
    });
    await _tts.speak(arabic);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _categories.isEmpty ? 1 : _categories.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Duas & Azkar'),
          bottom: _categories.isEmpty
              ? null
              : TabBar(
                  tabs: _categories
                      .map<Widget>((c) => Tab(text: c['title_en'] as String))
                      .toList(),
                ),
        ),
        body: _categories.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: _categories.map<Widget>((c) {
                  final items = c['items'] as List;
                  return ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final d = items[i] as Map<String, dynamic>;
                      final key = '${c['id']}-$i';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(d['title'] as String,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15.5)),
                                  ),
                                  IconButton(
                                    tooltip: 'Listen',
                                    icon: Icon(
                                        _speakingKey == key
                                            ? Icons.stop_rounded
                                            : Icons.volume_up_rounded,
                                        color: AppColors.emerald),
                                    onPressed: () =>
                                        _speak(key, d['arabic'] as String),
                                  ),
                                  IconButton(
                                    tooltip: 'Copy',
                                    icon: const Icon(Icons.copy_rounded, size: 19),
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(
                                          text:
                                              '${d['arabic']}\n\n${d['translit']}\n${d['urdu']}'));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                              content: Text('Copied ✓')));
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Directionality(
                                textDirection: TextDirection.rtl,
                                child: Text(d['arabic'] as String,
                                    style: const TextStyle(
                                        fontSize: 21,
                                        height: 1.9,
                                        fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(height: 10),
                              Text(d['translit'] as String,
                                  style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      fontSize: 13,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.75))),
                              const SizedBox(height: 8),
                              Directionality(
                                textDirection: TextDirection.rtl,
                                child: Text(d['urdu'] as String,
                                    style:
                                        const TextStyle(fontSize: 14.5, height: 1.7)),
                              ),
                              const SizedBox(height: 6),
                              Text(d['english'] as String,
                                  style: const TextStyle(fontSize: 13, height: 1.5)),
                              const SizedBox(height: 8),
                              Text('Ref: ${d['ref']}',
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.gold.withValues(alpha: 0.95),
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
      ),
    );
  }
}
