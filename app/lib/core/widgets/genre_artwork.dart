import 'package:flutter/material.dart';

/// Abstraktes, genre-spezifisches Platzhalter-Artwork für Events ohne Bild
/// (siehe docs/04-design-system.md, §6) — kein graues Icon, sondern ein auf
/// die Marke abgestimmter Gradient, bis ein echtes Veranstaltungsbild vorliegt.
enum EventGenre {
  oper,
  konzert,
  chormusik,
  kirchenmusik,
  kammermusik,
  orchester,
  sonstiges;

  /// Bildet den Postgres-Enum-Slug (genre_type, siehe
  /// docs/02-database-schema.md) auf die schmalere UI-Palette ab — Werte
  /// ohne eigenes Artwork (orgel, jazz, neue_musik, ...) fallen auf
  /// [sonstiges] bzw. den nächstliegenden visuellen Verwandten zurück.
  static EventGenre fromSlug(String? slug) => switch (slug) {
    'oper' => EventGenre.oper,
    'konzert' => EventGenre.konzert,
    'chormusik' => EventGenre.chormusik,
    'kirchenmusik' => EventGenre.kirchenmusik,
    'orgel' => EventGenre.kirchenmusik,
    'kammermusik' => EventGenre.kammermusik,
    'liederabend' => EventGenre.kammermusik,
    'orchester' => EventGenre.orchester,
    _ => EventGenre.sonstiges,
  };
}

class GenreArtwork extends StatelessWidget {
  const GenreArtwork({required this.genre, this.borderRadius, super.key});

  final EventGenre genre;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final gradient = switch (genre) {
      EventGenre.kirchenmusik => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF3A1420), Color(0xFF171012)],
      ),
      EventGenre.orchester => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF3A2C15), Color(0xFF14100C)],
      ),
      EventGenre.chormusik => const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [Color(0xFF4A2129), Color(0xFF120E10)],
      ),
      EventGenre.oper => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF5A1E2E), Color(0xFF1A1013)],
      ),
      EventGenre.kammermusik => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1C1F22), Color(0xFF0F1113)],
      ),
      _ => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF232326), Color(0xFF121214)],
      ),
    };
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(16),
      child: Container(decoration: BoxDecoration(gradient: gradient)),
    );
  }
}
