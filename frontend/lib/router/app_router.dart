import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/github_dashboard.dart';
import '../screens/home_screen.dart';
import '../screens/main_screen.dart';
import '../screens/reddit_dashboard.dart';
import '../screens/stackoverflow_dashboard.dart';
import '../screens/trends_tech_screen.dart';

class AppRoutes {
  static const String home = '/';
  static const String github = '/github';
  static const String stackoverflow = '/stackoverflow';
  static const String reddit = '/reddit';
  static const String trendsTech = '/trends/:tech';
}

String _normalizeInitialLocation(String initialLocation) {
  if (initialLocation.startsWith('/#/')) {
    return initialLocation.substring(2);
  }
  if (initialLocation.startsWith('#/')) {
    return initialLocation.substring(1);
  }
  if (initialLocation.startsWith('#')) {
    final normalized = initialLocation.substring(1);
    return normalized.isEmpty ? AppRoutes.home : normalized;
  }
  return initialLocation;
}

GoRouter createAppRouter({String initialLocation = AppRoutes.home}) {
  final String normalizedInitialLocation = _normalizeInitialLocation(
    initialLocation,
  );

  return GoRouter(
    initialLocation: normalizedInitialLocation,
    routes: <RouteBase>[
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) {
          return MainScreen(currentLocation: state.uri.path, child: child);
        },
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (BuildContext context, GoRouterState state) =>
                const NoTransitionPage<void>(child: HomeScreen()),
          ),
          GoRoute(
            path: AppRoutes.github,
            pageBuilder: (BuildContext context, GoRouterState state) =>
                const NoTransitionPage<void>(child: GithubDashboard()),
          ),
          GoRoute(
            path: AppRoutes.stackoverflow,
            pageBuilder: (BuildContext context, GoRouterState state) =>
                const NoTransitionPage<void>(child: StackOverflowDashboard()),
          ),
          GoRoute(
            path: AppRoutes.reddit,
            pageBuilder: (BuildContext context, GoRouterState state) =>
                const NoTransitionPage<void>(child: RedditDashboard()),
          ),
          GoRoute(
            path: AppRoutes.trendsTech,
            pageBuilder: (BuildContext context, GoRouterState state) {
              final String tech = state.pathParameters['tech'] ?? 'unknown';
              return NoTransitionPage<void>(
                child: TrendsTechScreen(technology: tech),
              );
            },
          ),
        ],
      ),
    ],
    errorBuilder: (BuildContext context, GoRouterState state) {
      return MainScreen(
        currentLocation: state.uri.path,
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Ruta no encontrada. Regresa al inicio desde el menu.',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    },
  );
}
