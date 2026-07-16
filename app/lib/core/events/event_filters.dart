import 'package:flutter/material.dart';

class EventFilters {
  const EventFilters({
    this.dateRange,
    this.genreIds = const {},
    this.maxPrice,
    this.accessibleOnly = false,
    this.openAirOnly = false,
    this.maxDistanceKm,
  });

  final DateTimeRange? dateRange;
  final Set<String> genreIds;
  final double? maxPrice;
  final bool accessibleOnly;
  final bool openAirOnly;
  final double? maxDistanceKm;

  static const empty = EventFilters();

  bool get isActive =>
      dateRange != null ||
      genreIds.isNotEmpty ||
      maxPrice != null ||
      accessibleOnly ||
      openAirOnly ||
      maxDistanceKm != null;

  int get activeCount => [
    dateRange != null,
    genreIds.isNotEmpty,
    maxPrice != null,
    accessibleOnly,
    openAirOnly,
    maxDistanceKm != null,
  ].where((active) => active).length;
}
