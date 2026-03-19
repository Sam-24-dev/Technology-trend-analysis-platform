import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'router/app_router.dart';

void main() {
  usePathUrlStrategy();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static final GoRouter _router = createAppRouter();

  static const Color _brandSeed = Color(0xFF0F62FE);

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: _brandSeed,
      brightness: Brightness.light,
    );

    final TextTheme baseTextTheme = GoogleFonts.interTextTheme();
    final Color appBackground = const Color(0xFFF7F9FC);
    return MaterialApp.router(
      title: 'Technology Trend Analysis Platform',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      scrollBehavior: const _AppScrollBehavior(),
      theme: ThemeData(
        colorScheme: colorScheme.copyWith(
          onSurface: const Color(0xFF0F172A),
          onSurfaceVariant: const Color(0xFF475569),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: appBackground,
        textTheme: baseTextTheme.copyWith(
          headlineLarge: baseTextTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
          headlineMedium: baseTextTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
          titleLarge: baseTextTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
          titleMedium: baseTextTheme.titleMedium?.copyWith(
            color: const Color(0xFF1E293B),
          ),
          titleSmall: baseTextTheme.titleSmall?.copyWith(
            color: const Color(0xFF334155),
          ),
          bodyLarge: baseTextTheme.bodyLarge?.copyWith(
            fontSize: 16,
            height: 1.45,
            color: const Color(0xFF1E293B),
          ),
          bodyMedium: baseTextTheme.bodyMedium?.copyWith(
            fontSize: 14,
            height: 1.45,
            color: const Color(0xFF1E293B),
          ),
          bodySmall: baseTextTheme.bodySmall?.copyWith(
            fontSize: 12,
            height: 1.4,
            color: const Color(0xFF475569),
          ),
          labelLarge: baseTextTheme.labelLarge?.copyWith(
            color: const Color(0xFF334155),
          ),
          labelMedium: baseTextTheme.labelMedium?.copyWith(
            color: const Color(0xFF475569),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: const Color(0xFFDFE6F1)),
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: colorScheme.onSurface,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: baseTextTheme.titleLarge?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        chipTheme: ChipThemeData(
          labelStyle: baseTextTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          side: BorderSide.none,
        ),
        dividerTheme: const DividerThemeData(color: Color(0xFFE2E8F0)),
      ),
    );
  }
}

class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const <PointerDeviceKind>{
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.unknown,
  };
}
