import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// "Vergangene Veranstaltungen" auf Personen-/Ensemble-Detail — bisher nur
/// als Zähltext ("N vergangene Veranstaltungen") ohne tatsächliche Liste.
/// Eingeklappt per Default: potenziell lang bei aktiven Ensembles/Personen,
/// sollte "Kommende Veranstaltungen" nicht optisch dominieren.
class PastEventsExpansion extends StatelessWidget {
  const PastEventsExpansion({super.key, required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final colors = context.appColors;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: Text(
          '${rows.length} vergangene Veranstaltung${rows.length == 1 ? '' : 'en'}',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        children: rows,
      ),
    );
  }
}
