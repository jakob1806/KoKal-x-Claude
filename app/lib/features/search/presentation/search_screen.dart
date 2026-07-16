import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/events/filtered_events_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/event_filter_sheet.dart';
import '../../../core/widgets/genre_artwork.dart';
import '../../home/application/home_providers.dart';

final _queryProvider = StateProvider<String>((ref) => '');

final _searchResultsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final query = ref.watch(_queryProvider).trim();
      if (query.length < 2) return [];

      final results = await Supabase.instance.client.rpc(
        'search_all',
        params: {'q': query, 'result_limit': 8},
      );

      final user = ref.read(currentUserProvider);
      if (user != null) {
        unawaited(
          Supabase.instance.client.from('search_history').insert({
            'user_id': user.id,
            'query': query,
          }),
        );
      }

      return (results as List).cast<Map<String, dynamic>>();
    });

final _searchHistoryProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final rows = await Supabase.instance.client
      .from('search_history')
      .select('query')
      .eq('user_id', user.id)
      .order('created_at', ascending: false)
      .limit(20);

  final seen = <String>{};
  for (final row in rows as List) {
    seen.add(row['query'] as String);
  }
  return seen.take(6).toList();
});

const _typeLabel = {
  'event': 'Veranstaltungen',
  'person': 'Personen',
  'ensemble': 'Ensembles',
  'venue': 'Orte',
};

const _typeIcon = {
  'event': Icons.event_rounded,
  'person': Icons.person_rounded,
  'ensemble': Icons.groups_rounded,
  'venue': Icons.place_rounded,
};

const _typeRoute = {
  'event': '/event',
  'person': '/person',
  'ensemble': '/ensemble',
  'venue': '/venue',
};

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(_queryProvider.notifier).state = value;
    });
  }

  void _selectQuery(String value) {
    _debounce?.cancel();
    _controller.text = value;
    _controller.selection = TextSelection.collapsed(offset: value.length);
    ref.read(_queryProvider.notifier).state = value;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final query = ref.watch(_queryProvider);
    final resultsAsync = ref.watch(_searchResultsProvider);
    final filters = ref.watch(eventFiltersProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPaddingMobile,
          vertical: AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(AppRadius.button),
                      border: Border.all(color: colors.separator),
                    ),
                    child: TextField(
                      controller: _controller,
                      onChanged: _onChanged,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        icon: Icon(
                          Icons.search_rounded,
                          color: colors.textTertiary,
                          size: 20,
                        ),
                        hintText: 'Werk, Komponist, Ensemble, Ort …',
                        hintStyle: TextStyle(
                          color: colors.textTertiary,
                          fontSize: 14,
                        ),
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: colors.textTertiary,
                                  size: 18,
                                ),
                                onPressed: () {
                                  _controller.clear();
                                  ref.read(_queryProvider.notifier).state = '';
                                },
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _FilterButton(
                  activeCount: filters.activeCount,
                  onTap: () => showEventFilterSheet(context),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Expanded(
              child: filters.isActive
                  ? ref
                        .watch(filteredEventsProvider)
                        .when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (e, _) => Center(
                            child: Text(
                              'Filter fehlgeschlagen: $e',
                              style: TextStyle(color: colors.error),
                            ),
                          ),
                          data: (events) => _FilteredResultsList(
                            events: events,
                            colors: colors,
                          ),
                        )
                  : query.trim().length < 2
                  ? _EmptyState(colors: colors, onSelect: _selectQuery)
                  : resultsAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(
                        child: Text(
                          'Suche fehlgeschlagen: $e',
                          style: TextStyle(color: colors.error),
                        ),
                      ),
                      data: (results) =>
                          _ResultsList(results: results, colors: colors),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.activeCount, required this.onTap});

  final int activeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final active = activeCount > 0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? colors.accentPrimary : colors.backgroundSecondary,
          borderRadius: BorderRadius.circular(AppRadius.button),
          border: Border.all(
            color: active ? colors.accentPrimary : colors.separator,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              Icons.tune_rounded,
              color: active ? Colors.white : colors.textSecondary,
              size: 20,
            ),
            if (active)
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: colors.accentSecondary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$activeCount',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilteredResultsList extends StatelessWidget {
  const _FilteredResultsList({required this.events, required this.colors});

  final List<HomeEventItem> events;
  final AppColorsExtension colors;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Center(
        child: Text(
          'Keine Veranstaltungen für diese Filter.',
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.textTertiary, fontSize: 13),
        ),
      );
    }

    return ListView.separated(
      itemCount: events.length,
      separatorBuilder: (_, __) => Divider(color: colors.separator, height: 1),
      itemBuilder: (context, i) {
        final e = events[i];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: SizedBox(
            width: 48,
            height: 48,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: GenreArtwork(genre: e.genre),
            ),
          ),
          title: Text(
            e.title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          subtitle: Text(
            e.venueAndTime,
            style: TextStyle(color: colors.textSecondary, fontSize: 12.5),
          ),
          onTap: () => context.push('/event/${e.slug}'),
        );
      },
    );
  }
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState({required this.colors, required this.onSelect});
  final AppColorsExtension colors;
  final ValueChanged<String> onSelect;

  static const _suggestions = [
    'Bach',
    'Kirchenmusik',
    'Herkulessaal',
    'Kostenlos',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(_searchHistoryProvider);

    return ListView(
      children: [
        historyAsync.maybeWhen(
          data: (history) => history.isEmpty
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Suchverlauf',
                        style: Theme.of(
                          context,
                        ).textTheme.labelSmall?.copyWith(letterSpacing: 1),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      for (final q in history)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.history_rounded,
                            color: colors.textTertiary,
                            size: 20,
                          ),
                          title: Text(
                            q,
                            style: TextStyle(
                              fontSize: 14,
                              color: colors.textPrimary,
                            ),
                          ),
                          onTap: () => onSelect(q),
                        ),
                    ],
                  ),
                ),
          orElse: () => const SizedBox.shrink(),
        ),
        Text(
          'Vorschläge',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(letterSpacing: 1),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _suggestions
              .map(
                (c) => ActionChip(label: Text(c), onPressed: () => onSelect(c)),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({required this.results, required this.colors});
  final List<Map<String, dynamic>> results;
  final AppColorsExtension colors;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return Center(
        child: Text(
          'Keine Treffer.',
          style: TextStyle(color: colors.textTertiary, fontSize: 13),
        ),
      );
    }

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final r in results) {
      grouped.putIfAbsent(r['result_type'] as String, () => []).add(r);
    }

    return ListView(
      children: [
        for (final type in _typeLabel.keys)
          if (grouped[type] != null) ...[
            Text(
              '${_typeLabel[type]}',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(letterSpacing: 1),
            ),
            const SizedBox(height: 4),
            for (final r in grouped[type]!)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _typeIcon[type],
                  color: colors.accentPrimary,
                  size: 22,
                ),
                title: Text(
                  r['title'] ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                subtitle: r['subtitle'] != null
                    ? Text(
                        r['subtitle'],
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12.5,
                        ),
                      )
                    : null,
                onTap: () => context.push('${_typeRoute[type]}/${r['slug']}'),
              ),
            const SizedBox(height: AppSpacing.lg),
          ],
      ],
    );
  }
}
