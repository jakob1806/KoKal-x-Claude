import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/favorite_button.dart';
import '../../../core/widgets/genre_artwork.dart';

final _eventProvider = FutureProvider.family<Map<String, dynamic>?, String>((
  ref,
  slug,
) async {
  return Supabase.instance.client
      .from('events')
      .select('''
        id, slug, title, subtitle, description_de,
        start_datetime, duration_minutes, has_intermission,
        ticket_url, price_min, price_max, price_currency, is_free,
        website_url, accessibility, status,
        venues(slug, name, address_street, address_zip, address_city),
        organizers(name),
        event_genres(genres(slug, label_de)),
        event_works(position, after_intermission, works(title, catalog_number, composer:persons(full_name))),
        event_participants(role, persons(slug, full_name), ensembles(slug, name))
      ''')
      .eq('slug', slug)
      .neq('status', 'draft')
      .maybeSingle();
});

const _statusLabel = {
  'scheduled': null,
  'sold_out': 'Ausverkauft',
  'cancelled': 'Abgesagt',
  'postponed': 'Verschoben',
};

const _roleLabel = {
  'komponist': 'Komponist:in',
  'dirigent': 'Dirigent:in',
  'solist': 'Solist:in',
  'chorleiter': 'Chorleiter:in',
  'moderator': 'Moderator:in',
};

class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_eventProvider(slug));
    final colors = context.appColors;

    return Scaffold(
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler beim Laden: $e')),
        data: (event) {
          if (event == null) {
            return Center(
              child: Text(
                'Veranstaltung nicht gefunden',
                style: TextStyle(color: colors.textSecondary),
              ),
            );
          }

          final genreSlugs = (event['event_genres'] as List)
              .map((g) => g['genres']?['slug'] as String?)
              .whereType<String>()
              .toList();
          final primaryGenre = EventGenre.fromSlug(
            genreSlugs.isEmpty ? null : genreSlugs.first,
          );
          final genreLabels = (event['event_genres'] as List)
              .map((g) => g['genres']?['label_de'] as String?)
              .whereType<String>()
              .toList();

          final start = DateTime.tryParse(event['start_datetime'] ?? '');
          final venue = event['venues'] as Map<String, dynamic>?;
          final works = (event['event_works'] as List)
            ..sort(
              (a, b) => (a['position'] as int).compareTo(b['position'] as int),
            );
          final participants = event['event_participants'] as List;
          final accessibility =
              (event['accessibility'] as Map<String, dynamic>?) ?? {};
          final statusBadge = _statusLabel[event['status']];

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 260,
                    pinned: true,
                    backgroundColor: colors.backgroundPrimary,
                    iconTheme: const IconThemeData(color: Colors.white),
                    actions: [
                      FavoriteButton(
                        eventId: event['id'],
                        activeColor: colors.accentPrimary,
                        inactiveColor: Colors.white,
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.ios_share_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: () => Share.share(
                          '${event['title']}${venue != null ? ' · ${venue['name']}' : ''}'
                          '${event['website_url'] != null ? '\n${event['website_url']}' : ''}',
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          GenreArtwork(genre: primaryGenre),
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0x59000000),
                                  Colors.transparent,
                                  Color(0xBF000000),
                                ],
                                stops: [0.0, 0.35, 1.0],
                              ),
                            ),
                          ),
                          if (statusBadge != null)
                            Positioned(
                              left: 16,
                              bottom: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.error,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  statusBadge,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenPaddingMobile,
                      AppSpacing.lg,
                      AppSpacing.screenPaddingMobile,
                      AppSpacing.huge,
                    ),
                    sliver: SliverList.list(
                      children: [
                        Text(
                          event['title'] ?? '',
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        if (event['subtitle'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            event['subtitle'],
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final label in genreLabels)
                              Chip(
                                label: Text(
                                  label,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                            if (event['is_free'] == true)
                              Chip(
                                label: const Text(
                                  'Kostenlos',
                                  style: TextStyle(fontSize: 11),
                                ),
                                backgroundColor: colors.success.withValues(
                                  alpha: 0.15,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          [
                            if (start != null)
                              '${_weekday(start)}, ${start.day}.${start.month}.${start.year} · ${_time(start)} Uhr',
                            if (event['duration_minutes'] != null)
                              '${event['duration_minutes']} Min.${event['has_intermission'] == true ? ' inkl. Pause' : ''}',
                          ].join(' — '),
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        if (venue != null) ...[
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () =>
                                context.push('/venue/${venue['slug']}'),
                            child: Text(
                              '${venue['name']} — ${venue['address_street']}, ${venue['address_zip']} ${venue['address_city']}',
                              style: TextStyle(
                                color: colors.accentPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        if (event['description_de'] != null) ...[
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            event['description_de'],
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ],
                        if (works.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xl),
                          Text(
                            'Programm',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          for (final w in works)
                            _ProgramRow(work: w, colors: colors),
                        ],
                        if (participants.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xl),
                          Text(
                            'Mitwirkende',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final p in participants)
                                _ParticipantChip(
                                  participant: p,
                                  colors: colors,
                                ),
                            ],
                          ),
                        ],
                        if (accessibility.values.any((v) => v == true)) ...[
                          const SizedBox(height: AppSpacing.xl),
                          Text(
                            'Barrierefreiheit',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: 8,
                            children: [
                              if (accessibility['wheelchair'] == true)
                                const Chip(label: Text('Rollstuhlgerecht')),
                              if (accessibility['hearing_loop'] == true)
                                const Chip(label: Text('Induktionsschleife')),
                              if (accessibility['sign_language'] == true)
                                const Chip(label: Text('Gebärdensprache')),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _TicketBar(event: event, colors: colors),
              ),
            ],
          );
        },
      ),
    );
  }

  String _weekday(DateTime d) =>
      const ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'][d.weekday - 1];
  String _time(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _ProgramRow extends StatelessWidget {
  const _ProgramRow({required this.work, required this.colors});
  final dynamic work;
  final AppColorsExtension colors;

  @override
  Widget build(BuildContext context) {
    final w = work['works'] as Map<String, dynamic>?;
    if (w == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (work['after_intermission'] == true)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                '— PAUSE —',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.accentSecondary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (w['composer']?['full_name'] != null)
                Expanded(
                  flex: 2,
                  child: Text(
                    w['composer']['full_name'],
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              Expanded(
                flex: 3,
                child: Text(
                  w['title'] ?? '',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ParticipantChip extends StatelessWidget {
  const _ParticipantChip({required this.participant, required this.colors});
  final dynamic participant;
  final AppColorsExtension colors;

  @override
  Widget build(BuildContext context) {
    final person = participant['persons'] as Map<String, dynamic>?;
    final ensemble = participant['ensembles'] as Map<String, dynamic>?;
    final name = person?['full_name'] ?? ensemble?['name'];
    if (name == null) return const SizedBox.shrink();
    final role = _roleLabel[participant['role']];

    return GestureDetector(
      onTap: () {
        if (person != null) {
          context.push('/person/${person['slug']}');
        } else if (ensemble != null) {
          context.push('/ensemble/${ensemble['slug']}');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: colors.separator),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          role != null ? '$name · $role' : name,
          style: TextStyle(
            fontSize: 12.5,
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _TicketBar extends StatelessWidget {
  const _TicketBar({required this.event, required this.colors});
  final Map<String, dynamic> event;
  final AppColorsExtension colors;

  @override
  Widget build(BuildContext context) {
    final priceMin = event['price_min'];
    final isFree = event['is_free'] == true;
    final ticketUrl = event['ticket_url'] as String?;

    String priceText;
    if (isFree) {
      priceText = 'Kostenlos';
    } else if (priceMin != null) {
      priceText = 'ab ${priceMin.toString()} €';
    } else {
      priceText = 'Preis auf Anfrage';
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenPaddingMobile,
        AppSpacing.md,
        AppSpacing.screenPaddingMobile,
        AppSpacing.md + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: colors.glass,
        border: Border(top: BorderSide(color: colors.separator, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            priceText,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (ticketUrl != null)
            ElevatedButton(
              onPressed: () => launchUrl(
                Uri.parse(ticketUrl),
                mode: LaunchMode.externalApplication,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accentPrimary,
              ),
              child: const Text('Tickets'),
            ),
        ],
      ),
    );
  }
}
