import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Erzeugt eine .ics-Datei für ein einzelnes Event und öffnet das
/// System-Teilen-Menü. iOS/Android bieten für `text/calendar`-Dateien
/// dort direkt „Zum Kalender hinzufügen" an — kein eigener Kalender-Picker
/// nötig (siehe docs/05-navigation-structure.md, „Kalender synchronisieren").
class IcsExport {
  const IcsExport._();

  static Future<void> shareEvent({
    required String uid,
    required String title,
    required DateTime start,
    String? description,
    DateTime? end,
    int? durationMinutes,
    String? location,
    String? url,
  }) async {
    final effectiveEnd =
        end ?? start.add(Duration(minutes: durationMinutes ?? 120));
    final ics = _buildIcs(
      uid: uid,
      title: title,
      description: description,
      start: start,
      end: effectiveEnd,
      location: location,
      url: url,
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/event_$uid.ics');
    await file.writeAsString(ics);

    await Share.shareXFiles([
      XFile(file.path, mimeType: 'text/calendar'),
    ], subject: title);
  }

  static String _buildIcs({
    required String uid,
    required String title,
    required DateTime start,
    required DateTime end,
    String? description,
    String? location,
    String? url,
  }) {
    final lines = [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//Klassik München//DE',
      'BEGIN:VEVENT',
      'UID:$uid@klassikmuenchen.de',
      'DTSTAMP:${_formatUtc(DateTime.now())}',
      'DTSTART:${_formatUtc(start)}',
      'DTEND:${_formatUtc(end)}',
      'SUMMARY:${_escape(title)}',
      if (description != null && description.isNotEmpty)
        'DESCRIPTION:${_escape(description)}',
      if (location != null && location.isNotEmpty)
        'LOCATION:${_escape(location)}',
      if (url != null && url.isNotEmpty) 'URL:$url',
      'END:VEVENT',
      'END:VCALENDAR',
    ];
    return lines.join('\r\n');
  }

  static String _formatUtc(DateTime d) {
    final utc = d.toUtc();
    String pad2(int n) => n.toString().padLeft(2, '0');
    return '${utc.year}${pad2(utc.month)}${pad2(utc.day)}T${pad2(utc.hour)}${pad2(utc.minute)}${pad2(utc.second)}Z';
  }

  /// Escaping nach RFC 5545 §3.3.11 — Reihenfolge ist wichtig, Backslash zuerst.
  static String _escape(String s) => s
      .replaceAll('\\', '\\\\')
      .replaceAll(',', '\\,')
      .replaceAll(';', '\\;')
      .replaceAll('\n', '\\n');
}
