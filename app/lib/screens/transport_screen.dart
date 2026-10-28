import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import '../services/site_service.dart';

/// Bin-Mukhtar Travels services: one-tap WhatsApp transport request and
/// Umrah packages (both managed from the website admin panel).
class TransportScreen extends StatefulWidget {
  const TransportScreen({super.key});
  @override
  State<TransportScreen> createState() => _TransportScreenState();
}

class _TransportScreenState extends State<TransportScreen> {
  String _service = 'Airport pickup';
  final _peopleCtrl = TextEditingController(text: '2');
  final _dateCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  static const _services = [
    'Airport pickup',
    'Makkah ⇄ Madinah transfer',
    'Ziyarat tour (full day)',
    'Taif day trip',
    'Hotel booking help',
    'Other',
  ];

  @override
  void dispose() {
    _peopleCtrl.dispose();
    _dateCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendWhatsApp(SiteService site) async {
    var number = site.whatsapp.replaceAll(RegExp(r'[^0-9]'), '');
    if (number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Sponsor WhatsApp number is not set yet (website admin → Umrah Trip App settings).')));
      return;
    }
    final msg = Uri.encodeComponent('Assalamu alaikum, Bin-Mukhtar Travels 🌙\n'
        'Request from the Umrah Trip app:\n'
        '• Service: $_service\n'
        '• Travellers: ${_peopleCtrl.text.trim()}\n'
        '• Date: ${_dateCtrl.text.trim().isEmpty ? '-' : _dateCtrl.text.trim()}\n'
        '${_noteCtrl.text.trim().isEmpty ? '' : '• Note: ${_noteCtrl.text.trim()}\n'}'
        'JazakAllahu khayran.');
    final ok = await launchUrl(Uri.parse('https://wa.me/$number?text=$msg'),
        mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not open WhatsApp.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final site = context.watch<SiteService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Transport & Packages')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [AppColors.emerald, AppColors.emeraldDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  ClipOval(
                      child: Image.asset('assets/images/sponsor_binmukhtar.png',
                          width: 54, height: 54)),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bin-Mukhtar Travels',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 17)),
                        Text('Official travel partner — request on WhatsApp',
                            style: TextStyle(color: AppColors.goldLight, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Request form
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Request transport',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _services
                        .map((s) => ChoiceChip(
                              label: Text(s),
                              selected: _service == s,
                              onSelected: (_) => setState(() => _service = s),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _peopleCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'People', border: OutlineInputBorder(), isDense: true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _dateCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Date (e.g. 15 Nov)',
                              border: OutlineInputBorder(),
                              isDense: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _noteCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                        border: OutlineInputBorder(),
                        isDense: true),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => _sendWhatsApp(site),
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Send request on WhatsApp'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Text('Umrah Packages',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          if (site.packages.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                    'Packages will appear here once added from the website admin (Umrah Trip App settings).',
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6))),
              ),
            )
          else
            ...site.packages.map((p) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const Icon(Icons.card_travel_rounded,
                        color: AppColors.gold, size: 30),
                    title: Text(p.title,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(p.details),
                    trailing: Text(p.price,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.emerald,
                            fontSize: 15)),
                    onTap: () {
                      _service = 'Other';
                      _noteCtrl.text = 'Package inquiry: ${p.title} (${p.price})';
                      _sendWhatsApp(site);
                    },
                  ),
                )),
        ],
      ),
    );
  }
}
