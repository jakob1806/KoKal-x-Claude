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
  sonstiges,
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
