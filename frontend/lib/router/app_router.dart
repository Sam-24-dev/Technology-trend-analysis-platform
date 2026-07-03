import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/github_dashboard.dart' deferred as github_dashboard;
import '../screens/home_screen.dart';
import '../screens/main_screen.dart';
import '../screens/reddit_dashboard.dart' deferred as reddit_dashboard;
import '../screens/stackoverflow_dashboard.dart'
    deferred as stackoverflow_dashboard;
import '../screens/trends_tech_screen.dart' deferred as trends_tech_screen;

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
                NoTransitionPage<void>(
                  child: _DeferredRoute(
                    loadLibrary: github_dashboard.loadLibrary,
                    builder: () => github_dashboard.GithubDashboard(),
                  ),
                ),
          ),
          GoRoute(
            path: AppRoutes.stackoverflow,
            pageBuilder: (BuildContext context, GoRouterState state) =>
                NoTransitionPage<void>(
                  child: _DeferredRoute(
                    loadLibrary: stackoverflow_dashboard.loadLibrary,
                    builder: () =>
                        stackoverflow_dashboard.StackOverflowDashboard(),
                  ),
                ),
          ),
          GoRoute(
            path: AppRoutes.reddit,
            pageBuilder: (BuildContext context, GoRouterState state) =>
                NoTransitionPage<void>(
                  child: _DeferredRoute(
                    loadLibrary: reddit_dashboard.loadLibrary,
                    builder: () => reddit_dashboard.RedditDashboard(),
                  ),
                ),
          ),
          GoRoute(
            path: AppRoutes.trendsTech,
            pageBuilder: (BuildContext context, GoRouterState state) {
              final String tech = state.pathParameters['tech'] ?? 'unknown';
              return NoTransitionPage<void>(
                child: _DeferredRoute(
                  loadLibrary: trends_tech_screen.loadLibrary,
                  builder: () =>
                      trends_tech_screen.TrendsTechScreen(technology: tech),
                ),
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

typedef _DeferredRouteBuilder = Widget Function();

class _DeferredRoute extends StatefulWidget {
  final Future<void> Function() loadLibrary;
  final _DeferredRouteBuilder builder;

  const _DeferredRoute({required this.loadLibrary, required this.builder});

  @override
  State<_DeferredRoute> createState() => _DeferredRouteState();
}

class _DeferredRouteState extends State<_DeferredRoute> {
  late Future<void> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadRoute();
  }

  @override
  void didUpdateWidget(covariant _DeferredRoute oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loadLibrary != widget.loadLibrary) {
      _loadFuture = _loadRoute();
    }
  }

  Future<void> _loadRoute() async {
    try {
      await widget.loadLibrary();
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'app_router',
          context: ErrorDescription('loading a deferred route library'),
        ),
      );
      rethrow;
    }
  }

  void _retryLoad() {
    setState(() {
      _loadFuture = _loadRoute();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text('No se pudo cargar la página.'),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _retryLoad,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return widget.builder();
      },
    );
  }
}
