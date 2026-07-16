import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:url_launcher/url_launcher.dart';

/// Öffnet die native Karten-App mit Route zu lat/lng — Apple Maps auf iOS,
/// geo:-Intent auf Android (öffnet dort die vom Nutzer gewählte Standard-
/// App), sonst Google-Maps-Web als Fallback. Gemeinsam genutzt von Karte
/// und VenueDetail, damit "Route zu diesem Ort" überall gleich funktioniert
/// statt nur auf der Karte echte Turn-by-Turn-fähige Deeplinks zu haben.
Future<void> openExternalMaps({
  required double lat,
  required double lng,
  required String name,
}) async {
  final Uri uri;
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      uri = Uri.parse(
        'https://maps.apple.com/?daddr=$lat,$lng&q=${Uri.encodeComponent(name)}',
      );
    case TargetPlatform.android:
      uri = Uri.parse(
        'geo:$lat,$lng?q=$lat,$lng(${Uri.encodeComponent(name)})',
      );
    default:
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
      );
  }
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
