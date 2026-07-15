import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/calendar/presentation/calendar_screen.dart';
import '../../features/event_detail/presentation/event_detail_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/map/presentation/map_screen.dart';
import '../../features/persons/presentation/ensemble_detail_screen.dart';
import '../../features/persons/presentation/person_detail_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/venues/presentation/venue_detail_screen.dart';
import '../widgets/app_shell.dart';

/// Routing-Baum nach docs/05-navigation-structure.md.
/// Deep-Link-Schema: muc-classical://event/{slug} etc. (§3 im selben Dokument).
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/home',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/search',
              builder: (context, state) => const SearchScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/map',
              builder: (context, state) => const MapScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/calendar',
              builder: (context, state) => const CalendarScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/event/:slug',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) =>
          EventDetailScreen(slug: state.pathParameters['slug']!),
    ),
    GoRoute(
      path: '/person/:slug',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) =>
          PersonDetailScreen(slug: state.pathParameters['slug']!),
    ),
    GoRoute(
      path: '/ensemble/:slug',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) =>
          EnsembleDetailScreen(slug: state.pathParameters['slug']!),
    ),
    GoRoute(
      path: '/venue/:slug',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) =>
          VenueDetailScreen(slug: state.pathParameters['slug']!),
    ),
  ],
);
