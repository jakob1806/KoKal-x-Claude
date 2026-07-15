import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';

/// Platzhalter-Venue, bis die Karte echte Daten über
/// `events_nearby`/`venues` lädt (siehe docs/03-api-concept.md, §2).
/// Koordinaten entsprechen backend/supabase/seed.sql.
class _VenueStub {
  const _VenueStub(this.name, this.lat, this.lng);
  final String name;
  final double lat;
  final double lng;
}

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  static const _muenchenCenter = LatLng(48.1351, 11.5820);

  static const _venues = [
    _VenueStub('Isarphilharmonie', 48.1226, 11.5763),
    _VenueStub('Herkulessaal der Residenz', 48.1424, 11.5802),
    _VenueStub('Prinzregententheater', 48.1444, 11.6039),
    _VenueStub('Bayerische Staatsoper', 48.1397, 11.5765),
    _VenueStub('St. Michael', 48.1394, 11.5698),
    _VenueStub('Allerheiligen-Hofkirche', 48.1414, 11.5786),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return FlutterMap(
      options: const MapOptions(
        initialCenter: _muenchenCenter,
        initialZoom: 12.5,
        minZoom: 10,
        maxZoom: 18,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'de.klassikmuenchen.klassik_muenchen',
        ),
        MarkerLayer(
          markers: [
            for (final venue in _venues)
              Marker(
                point: LatLng(venue.lat, venue.lng),
                width: 34,
                height: 34,
                alignment: Alignment.topCenter,
                child: _VenuePin(
                  label: venue.name,
                  color: colors.accentPrimary,
                  onTap: () => _openExternalMaps(venue),
                ),
              ),
          ],
        ),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution(
              '© OpenStreetMap-Mitwirkende',
              onTap: () => launchUrl(
                Uri.parse('https://www.openstreetmap.org/copyright'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openExternalMaps(_VenueStub venue) async {
    final query = Uri.encodeComponent(venue.name);
    final uri = Uri.parse(
      'https://www.openstreetmap.org/search?query=$query#map=17/${venue.lat}/${venue.lng}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _VenuePin extends StatelessWidget {
  const _VenuePin({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.music_note_rounded,
            color: Colors.white,
            size: 16,
          ),
        ),
      ),
    );
  }
}
