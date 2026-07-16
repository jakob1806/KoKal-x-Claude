import 'package:flutter/material.dart';

class EventFilters {
  const EventFilters({
    this.dateRange,
    this.genreIds = const {},
    this.maxPrice,
    this.accessibleOnly = false,
    this.openAirOnly = false,
  });

  final DateTimeRange? dateRange;
  final Set<String> genreIds;
  final double? maxPrice;
  final bool accessibleOnly;
  final bool openAirOnly;

  static const empty = EventFilters();

  bool get isActive =>
      dateRange != null ||
      genreIds.isNotEmpty ||
      maxPrice != null ||
      accessibleOnly ||
      openAirOnly;

  int get activeCount => [
    dateRange != null,
    genreIds.isNotEmpty,
    maxPrice != null,
    accessibleOnly,
    openAirOnly,
  ].where((active) => active).length;
}
