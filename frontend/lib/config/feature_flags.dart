class FeatureFlags {
  FeatureFlags._();

  /// Partial cutover flag for historical bridge JSON assets.
  ///
  /// Default enabled to prefer bridge JSON, with CSV fallback still available.
  static const bool useHistoryBridgeJson = bool.fromEnvironment(
    'USE_HISTORY_BRIDGE_JSON',
    defaultValue: true,
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

  /// Enables public Reddit sentiment JSON bridge consumption.
  static const bool useRedditSentimentPublicJson = bool.fromEnvironment(
    'USE_REDDIT_SENTIMENT_PUBLIC_JSON',
    defaultValue: true,
  );

  /// Optional absolute URL for Reddit public sentiment payload.
  /// If empty, frontend falls back to local bridge asset.
  static const String redditSentimentPublicUrl = String.fromEnvironment(
    'REDDIT_SENTIMENT_PUBLIC_URL',
    defaultValue: '',
  );

  /// Enables public Reddit topics history JSON bridge consumption.
  static const bool useRedditTopicsHistoryJson = bool.fromEnvironment(
    'USE_REDDIT_TOPICS_HISTORY_JSON',
    defaultValue: true,
  );

  /// Optional absolute URL for Reddit topics history payload.
  /// If empty, frontend falls back to local bridge asset.
  static const String redditTopicsHistoryUrl = String.fromEnvironment(
    'REDDIT_TOPICS_HISTORY_URL',
    defaultValue: '',
  );

  /// Enables public Reddit intersection history JSON bridge consumption.
  static const bool useRedditIntersectionHistoryJson = bool.fromEnvironment(
    'USE_REDDIT_INTERSECTION_HISTORY_JSON',
    defaultValue: true,
  );

  /// Optional absolute URL for Reddit intersection history payload.
  /// If empty, frontend falls back to local bridge asset.
  static const String redditIntersectionHistoryUrl = String.fromEnvironment(
    'REDDIT_INTERSECTION_HISTORY_URL',
    defaultValue: '',
  );

  /// Enables public GitHub frameworks history JSON bridge consumption.
  static const bool useGithubFrameworksHistoryJson = bool.fromEnvironment(
    'USE_GITHUB_FRAMEWORKS_HISTORY_JSON',
    defaultValue: true,
  );

  /// Optional absolute URL for GitHub frameworks history payload.
  /// If empty, frontend falls back to local bridge asset.
  static const String githubFrameworksHistoryUrl = String.fromEnvironment(
    'GITHUB_FRAMEWORKS_HISTORY_URL',
    defaultValue: '',
  );

  /// Enables public GitHub correlation history JSON bridge consumption.
  static const bool useGithubCorrelationHistoryJson = bool.fromEnvironment(
    'USE_GITHUB_CORRELATION_HISTORY_JSON',
    defaultValue: true,
  );

  /// Optional absolute URL for GitHub correlation history payload.
  /// If empty, frontend falls back to local bridge asset.
  static const String githubCorrelationHistoryUrl = String.fromEnvironment(
    'GITHUB_CORRELATION_HISTORY_URL',
    defaultValue: '',
  );

  /// Optional base URL for remote JSON assets (GitHub Pages, CDN, etc).
  /// If empty, frontend falls back to local bridge assets.
  static const String remoteAssetsBaseUrl = String.fromEnvironment(
    'REMOTE_ASSETS_BASE_URL',
    defaultValue: '',
  );

  static String buildRemoteAssetUrl(String fileName) {
    final String base = remoteAssetsBaseUrl.trim();
    if (base.isEmpty) {
      return '';
    }
    if (base.endsWith('/')) {
      return '$base$fileName';
    }
    return '$base/$fileName';
  }
}
