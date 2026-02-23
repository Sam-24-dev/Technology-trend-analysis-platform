class FeatureFlags {
  FeatureFlags._();

  /// Partial cutover flag for historical bridge JSON assets.
  ///
  /// Default is disabled to preserve current CSV-only behavior.
  static const bool useHistoryBridgeJson = bool.fromEnvironment(
    'USE_HISTORY_BRIDGE_JSON',
    defaultValue: false,
  );
}
