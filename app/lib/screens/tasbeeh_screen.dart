import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme.dart';

/// Digital tasbeeh with haptic feedback + Tawaf (7) and Sa'i (7) lap counters.
/// Counts persist across app restarts.
class TasbeehScreen extends StatefulWidget {
  const TasbeehScreen({super.key});
  @override
  State<TasbeehScreen> createState() => _TasbeehScreenState();
}

enum _Mode { tasbeeh, tawaf, sai }

class _TasbeehScreenState extends State<TasbeehScreen> {
  _Mode _mode = _Mode.tasbeeh;
  int _tasbeeh = 0;
  int _tawaf = 0;
  int _sai = 0;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      setState(() {
        _tasbeeh = p.getInt('cnt_tasbeeh') ?? 0;
        _tawaf = p.getInt('cnt_tawaf') ?? 0;
        _sai = p.getInt('cnt_sai') ?? 0;
      });
    });
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    p.setInt('cnt_tasbeeh', _tasbeeh);
    p.setInt('cnt_tawaf', _tawaf);
    p.setInt('cnt_sai', _sai);
  }

  int get _count => switch (_mode) {
        _Mode.tasbeeh => _tasbeeh,
        _Mode.tawaf => _tawaf,
        _Mode.sai => _sai,
      };

  int? get _target => _mode == _Mode.tasbeeh ? null : 7;

  void _increment() {
    HapticFeedback.mediumImpact();
    setState(() {
      switch (_mode) {
        case _Mode.tasbeeh:
          _tasbeeh++;
          if (_tasbeeh % 33 == 0) HapticFeedback.heavyImpact();
        case _Mode.tawaf:
          if (_tawaf < 7) _tawaf++;
          if (_tawaf == 7) HapticFeedback.heavyImpact();
        case _Mode.sai:
          if (_sai < 7) _sai++;
          if (_sai == 7) HapticFeedback.heavyImpact();
      }
    });
    _save();
  }

  void _reset() {
    setState(() {
      switch (_mode) {
        case _Mode.tasbeeh:
          _tasbeeh = 0;
        case _Mode.tawaf:
          _tawaf = 0;
        case _Mode.sai:
          _sai = 0;
      }
    });
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final done = _target != null && _count >= _target!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasbeeh Counter'),
        actions: [
          IconButton(
              tooltip: 'Reset',
              onPressed: _reset,
              icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          SegmentedButton<_Mode>(
            segments: const [
              ButtonSegment(value: _Mode.tasbeeh, label: Text('Tasbeeh')),
              ButtonSegment(value: _Mode.tawaf, label: Text('Tawaf 7')),
              ButtonSegment(value: _Mode.sai, label: Text("Sa'i 7")),
            ],
            selected: {_mode},
            onSelectionChanged: (v) => setState(() => _mode = v.first),
          ),
          const SizedBox(height: 8),
          if (_mode == _Mode.tasbeeh)
            Text('33 par halki vibration — SubhanAllah · Alhamdulillah · Allahu Akbar',
                style: TextStyle(
                    fontSize: 12,
                    color:
                        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)))
          else
            Text(
                done
                    ? (_mode == _Mode.tawaf
                        ? 'Tawaf complete — pray 2 rak\'ah at Maqam Ibrahim 🤲'
                        : "Sa'i complete — may Allah accept it 🤲")
                    : 'Counting ${_mode == _Mode.tawaf ? 'Tawaf circuits' : "Sa'i lengths"} — tap after each one',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: done ? FontWeight.w700 : FontWeight.w400,
                    color: done
                        ? Colors.green
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6))),
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: _increment,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                        colors: done
                            ? [Colors.green.shade600, Colors.green.shade900]
                            : [AppColors.emerald, AppColors.emeraldDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    boxShadow: [
                      BoxShadow(
                          color: (done ? Colors.green : AppColors.gold)
                              .withValues(alpha: 0.4),
                          blurRadius: 44,
                          spreadRadius: 4),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _target == null ? '$_count' : '$_count / $_target',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 62,
                              fontWeight: FontWeight.w800),
                        ),
                        Text('TAP',
                            style: TextStyle(
                                color: AppColors.goldLight.withValues(alpha: 0.9),
                                letterSpacing: 6,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_mode == _Mode.tasbeeh)
            Padding(
              padding: const EdgeInsets.only(bottom: 26),
              child: Text(
                'Cycle: ${(_tasbeeh ~/ 100) + 1}  ·  In cycle: ${_tasbeeh % 100}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            )
          else
            const SizedBox(height: 26),
        ],
      ),
    );
  }
}
