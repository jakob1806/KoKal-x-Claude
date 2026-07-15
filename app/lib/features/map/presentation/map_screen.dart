import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      color: colors.backgroundSecondary,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_outlined, size: 40, color: colors.textTertiary),
              const SizedBox(height: 12),
              Text(
                'Google-Maps-Integration folgt in Phase 1\n(siehe docs/03-api-concept.md, RPC events_nearby)',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textTertiary, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
