import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Round profile photo with the first letter of the name as a fallback.
class UserAvatar extends StatelessWidget {
  final String name;
  final String? url;
  final double radius;
  const UserAvatar({super.key, required this.name, this.url, this.radius = 22});

  @override
  Widget build(BuildContext context) {
    final has = (url ?? '').isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.gold,
      foregroundImage: has ? NetworkImage(url!) : null,
      onForegroundImageError: has ? (_, __) {} : null,
      child: Text(name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
          style: TextStyle(
              fontSize: radius * 0.85, fontWeight: FontWeight.w800, color: AppColors.slate)),
    );
  }
}
