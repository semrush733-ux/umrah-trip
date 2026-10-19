import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Dedicated sponsor page for Bin-Mukhtar Travels.
class SponsorScreen extends StatelessWidget {
  const SponsorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Our Sponsor')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.slate.withValues(alpha: 0.12),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset('assets/images/sponsor_binmukhtar.png',
                    width: 200, height: 200),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Center(
            child: Text('Sponsored by',
                style: TextStyle(fontSize: 13, letterSpacing: 2)),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text('BIN-MUKHTAR TRAVELS',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: AppColors.emerald)),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('About our sponsor',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  SizedBox(height: 8),
                  Text(
                    'Umrah Trip is proudly sponsored by Bin-Mukhtar Travels — '
                    'serving pilgrims with Umrah travel arrangements, guidance '
                    'and care throughout their blessed journey.\n\n'
                    'May Allah accept the Umrah and Ziyarat of every traveller '
                    'who uses this app, and reward all who made it possible.',
                    style: TextStyle(height: 1.55),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('App by',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  SizedBox(height: 6),
                  Text('BWP Experts · bwpexperts.com',
                      style: TextStyle(height: 1.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
