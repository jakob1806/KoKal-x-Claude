import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/map_providers.dart';

class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  static const _muenchenCenter = LatLng(48.1351, 11.5820);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final venuesAsync = ref.watch(mapVenuesProvider);
    final venues = venuesAsync.valueOrNull ?? const <MapVenue>[];
    final venueById = {for (final v in venues) v.id: v};

    return Stack(
      children: [
        FlutterMap(
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
            MarkerClusterLayerWidget(
              options: MarkerClusterLayerOptions(
                maxClusterRadius: 60,
                size: const Size(36, 36),
                markers: [
                  for (final venue in venues)
                    Marker(
                      key: ValueKey<String>(venue.id),
                      point: LatLng(venue.lat, venue.lng),
                      width: 34,
                      height: 34,
                      alignment: Alignment.topCenter,
                      child: _VenuePin(color: colors.accentPrimary),
                    ),
                ],
                builder: (context, markers) => _ClusterBubble(
                  count: markers.length,
                  color: colors.accentPrimary,
                ),
                onMarkerTap: (marker) {
                  final key = marker.key;
                  if (key is! ValueKey<String>) return;
                  final venue = venueById[key.value];
                  if (venue != null) _showVenueSheet(context, venue);
                },
              ),
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
        ),
        if (venuesAsync.isLoading && !venuesAsync.hasValue)
          const Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(child: CircularProgressIndicator()),
          ),
        if (venuesAsync.hasError)
          Positioned(
            top: AppSpacing.md,
            left: AppSpacing.screenPaddingMobile,
            right: AppSpacing.screenPaddingMobile,
            child: _ErrorBanner(message: '${venuesAsync.error}'),
          ),
      ],
    );
  }

  void _showVenueSheet(BuildContext context, MapVenue venue) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _VenuePreviewSheet(venue: venue),
    );
  }
}

Future<void> _openExternalMaps(MapVenue venue) async {
  final Uri uri;
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      uri = Uri.parse(
        'https://maps.apple.com/?daddr=${venue.lat},${venue.lng}&q=${Uri.encodeComponent(venue.name)}',
      );
    case TargetPlatform.android:
      uri = Uri.parse(
        'geo:${venue.lat},${venue.lng}?q=${venue.lat},${venue.lng}(${Uri.encodeComponent(venue.name)})',
      );
    default:
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${venue.lat},${venue.lng}',
      );
  }
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class _VenuePin extends StatelessWidget {
  const _VenuePin({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

class _ClusterBubble extends StatelessWidget {
  const _ClusterBubble({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
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
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(10),
      color: colors.backgroundElevated,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Text(
          'Karte konnte nicht geladen werden: $message',
          style: TextStyle(color: colors.error, fontSize: 12.5),
        ),
      ),
    );
  }
}

class _VenuePreviewSheet extends StatelessWidget {
  const _VenuePreviewSheet({required this.venue});

  final MapVenue venue;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPaddingMobile,
          AppSpacing.lg,
          AppSpacing.screenPaddingMobile,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(venue.name, style: Theme.of(context).textTheme.titleLarge),
            if (venue.addressCity != null) ...[
              const SizedBox(height: 4),
              Text(
                venue.addressCity!,
                style: TextStyle(color: colors.textSecondary),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(
              venue.upcomingEventCount > 0
                  ? '${venue.upcomingEventCount} kommende Veranstaltung${venue.upcomingEventCount == 1 ? '' : 'en'}'
                  : 'Keine kommenden Veranstaltungen',
              style: TextStyle(color: colors.textTertiary, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openExternalMaps(venue),
                    icon: const Icon(Icons.directions_rounded),
                    label: const Text('Route'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push('/venue/${venue.slug}');
                    },
                    child: const Text('Details ansehen'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
