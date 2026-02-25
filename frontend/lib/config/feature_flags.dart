class FeatureFlags {
  FeatureFlags._();

  /// Partial cutover flag for historical bridge JSON assets.
  ///
  /// Default disabled to preserve current CSV-only behavior.
  static const bool useHistoryBridgeJson = bool.fromEnvironment(
    'USE_HISTORY_BRIDGE_JSON',
    defaultValue: false,
  );

  /// Enables public run manifest consumption in frontend.
  static const bool usePublicRunManifest = bool.fromEnvironment(
    'USE_PUBLIC_RUN_MANIFEST',
    defaultValue: true,
  );

  /// Keeps CSV fallback active while cutover is still in progress.
  static const bool enableCsvFallback = bool.fromEnvironment(
    'ENABLE_CSV_FALLBACK',
    defaultValue: true,
  );
}
