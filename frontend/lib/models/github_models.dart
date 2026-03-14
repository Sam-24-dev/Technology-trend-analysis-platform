class LenguajeModel {
  final String lenguaje;
  final int reposCount;
  final double porcentaje;

  LenguajeModel({
    required this.lenguaje,
    required this.reposCount,
    required this.porcentaje,
  });

  factory LenguajeModel.fromMap(Map<String, dynamic> map) {
    return LenguajeModel(
      lenguaje: map['lenguaje']?.toString() ?? '',
      reposCount: int.tryParse(map['repos_count']?.toString() ?? '0') ?? 0,
      porcentaje: double.tryParse(map['porcentaje']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class GithubLanguagePublicLeaderModel {
  final String lenguaje;
  final int reposCount;
  final double sharePct;

  const GithubLanguagePublicLeaderModel({
    required this.lenguaje,
    required this.reposCount,
    required this.sharePct,
  });

  factory GithubLanguagePublicLeaderModel.fromMap(Map<String, dynamic> map) {
    return GithubLanguagePublicLeaderModel(
      lenguaje: map['lenguaje']?.toString() ?? '',
      reposCount: int.tryParse(map['repos_count']?.toString() ?? '0') ?? 0,
      sharePct: double.tryParse(map['share_pct']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class GithubLanguagePublicSummaryModel {
  final GithubLanguagePublicLeaderModel? leader;
  final GithubLanguagePublicLeaderModel? runnerUp;
  final int languageCount;
  final int totalClassifiableRepos;
  final int leaderGapRepos;
  final double leaderGapSharePct;

  const GithubLanguagePublicSummaryModel({
    required this.leader,
    required this.runnerUp,
    required this.languageCount,
    required this.totalClassifiableRepos,
    required this.leaderGapRepos,
    required this.leaderGapSharePct,
  });

  factory GithubLanguagePublicSummaryModel.fromMap(Map<String, dynamic> map) {
    GithubLanguagePublicLeaderModel? parseLeader(String key) {
      final dynamic raw = map[key];
      if (raw is! Map) {
        return null;
      }
      return GithubLanguagePublicLeaderModel.fromMap(
        raw.cast<String, dynamic>(),
      );
    }

    return GithubLanguagePublicSummaryModel(
      leader: parseLeader('leader'),
      runnerUp: parseLeader('runner_up'),
      languageCount:
          int.tryParse(map['language_count']?.toString() ?? '0') ?? 0,
      totalClassifiableRepos:
          int.tryParse(map['total_classifiable_repos']?.toString() ?? '0') ?? 0,
      leaderGapRepos:
          int.tryParse(map['leader_gap_repos']?.toString() ?? '0') ?? 0,
      leaderGapSharePct:
          double.tryParse(map['leader_gap_share_pct']?.toString() ?? '0') ??
          0.0,
    );
  }
}

class GithubLanguagePublicModel {
  final String generatedAtUtc;
  final String dataset;
  final String sourceMode;
  final String sourcePath;
  final String sourceUpdatedAtUtc;
  final int languageCount;
  final List<GithubLanguagePublicLeaderModel> languages;
  final GithubLanguagePublicSummaryModel summary;

  const GithubLanguagePublicModel({
    required this.generatedAtUtc,
    required this.dataset,
    required this.sourceMode,
    required this.sourcePath,
    required this.sourceUpdatedAtUtc,
    required this.languageCount,
    required this.languages,
    required this.summary,
  });

  factory GithubLanguagePublicModel.fromMap(Map<String, dynamic> map) {
    final List<dynamic> rawLanguages = (map['languages'] as List?) ?? const [];
    return GithubLanguagePublicModel(
      generatedAtUtc: map['generated_at_utc']?.toString() ?? '',
      dataset: map['dataset']?.toString() ?? '',
      sourceMode: map['source_mode']?.toString() ?? '',
      sourcePath: map['source_path']?.toString() ?? '',
      sourceUpdatedAtUtc: map['source_updated_at_utc']?.toString() ?? '',
      languageCount:
          int.tryParse(map['language_count']?.toString() ?? '0') ?? 0,
      languages: rawLanguages
          .whereType<Map>()
          .map(
            (dynamic item) => GithubLanguagePublicLeaderModel.fromMap(
              item.cast<String, dynamic>(),
            ),
          )
          .toList(),
      summary: GithubLanguagePublicSummaryModel.fromMap(
        (map['summary'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
    );
  }
}

class FrameworkCommitModel {
  final String framework;
  final String repo;
  final int commits2025;
  final int ranking;
  final int? activeContributors;
  final int? mergedPrs;
  final int? closedIssues;
  final int? releasesCount;
  final int? commitsPrev;
  final int? deltaCommits;
  final double? growthPct;
  final String? trendDirection;

  FrameworkCommitModel({
    required this.framework,
    required this.repo,
    required this.commits2025,
    required this.ranking,
    this.activeContributors,
    this.mergedPrs,
    this.closedIssues,
    this.releasesCount,
    this.commitsPrev,
    this.deltaCommits,
    this.growthPct,
    this.trendDirection,
  });

  static int? _parseNullableInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.toInt();
    }
    final String text = value.toString().trim();
    if (text.isEmpty) {
      return null;
    }
    return int.tryParse(text);
  }

  static double? _parseNullableDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    final String text = value.toString().trim();
    if (text.isEmpty) {
      return null;
    }
    return double.tryParse(text);
  }

  factory FrameworkCommitModel.fromMap(Map<String, dynamic> map) {
    return FrameworkCommitModel(
      framework: map['framework']?.toString() ?? '',
      repo: map['repo']?.toString() ?? '',
      commits2025: int.tryParse(map['commits_2025']?.toString() ?? '0') ?? 0,
      ranking: int.tryParse(map['ranking']?.toString() ?? '0') ?? 0,
      activeContributors: _parseNullableInt(map['active_contributors']),
      mergedPrs: _parseNullableInt(map['merged_prs']),
      closedIssues: _parseNullableInt(map['closed_issues']),
      releasesCount: _parseNullableInt(map['releases_count']),
      commitsPrev: _parseNullableInt(map['commits_prev']),
      deltaCommits: _parseNullableInt(map['delta_commits']),
      growthPct: _parseNullableDouble(map['growth_pct']),
      trendDirection: map['trend_direction']?.toString().trim().isEmpty ?? true
          ? null
          : map['trend_direction']?.toString().trim(),
    );
  }
}

class CorrelacionModel {
  final String repoName;
  final int stars;
  final int contributors;
  final String language;
  final double engagementRatio;
  final double contributorsPer1kStars;
  final double? expectedContributors;
  final double? contributorsDeltaVsTrend;
  final double? outlierScore;
  final String? trendBucket;
  final String? snapshotDateUtc;

  CorrelacionModel({
    required this.repoName,
    required this.stars,
    required this.contributors,
    required this.language,
    this.engagementRatio = 0.0,
    this.contributorsPer1kStars = 0.0,
    this.expectedContributors,
    this.contributorsDeltaVsTrend,
    this.outlierScore,
    this.trendBucket,
    this.snapshotDateUtc,
  });

  factory CorrelacionModel.fromMap(Map<String, dynamic> map) {
    final int stars = FrameworkCommitModel._parseNullableInt(map['stars']) ?? 0;
    final int contributors =
        FrameworkCommitModel._parseNullableInt(map['contributors']) ?? 0;
    final double derivedEngagement = stars == 0 ? 0.0 : contributors / stars;
    final double derivedPer1k = stars == 0 ? 0.0 : derivedEngagement * 1000;
    return CorrelacionModel(
      repoName: map['repo_name']?.toString() ?? '',
      stars: stars,
      contributors: contributors,
      language: map['language']?.toString() ?? '',
      engagementRatio:
          FrameworkCommitModel._parseNullableDouble(map['engagement_ratio']) ??
          derivedEngagement,
      contributorsPer1kStars:
          FrameworkCommitModel._parseNullableDouble(
            map['contributors_per_1k_stars'],
          ) ??
          derivedPer1k,
      expectedContributors: FrameworkCommitModel._parseNullableDouble(
        map['expected_contributors'],
      ),
      contributorsDeltaVsTrend: FrameworkCommitModel._parseNullableDouble(
        map['contributors_delta_vs_trend'],
      ),
      outlierScore: FrameworkCommitModel._parseNullableDouble(
        map['outlier_score'],
      ),
      trendBucket: map['trend_bucket']?.toString().trim().isEmpty ?? true
          ? null
          : map['trend_bucket']?.toString().trim(),
      snapshotDateUtc:
          map['snapshot_date_utc']?.toString().trim().isEmpty ?? true
          ? null
          : map['snapshot_date_utc']?.toString().trim(),
    );
  }
}

class GithubCorrelationHistorySummaryModel {
  final double correlationValue;
  final CorrelacionModel? topStarsRepo;
  final CorrelacionModel? topContributorsRepo;
  final CorrelacionModel? topEngagementRepo;
  final CorrelacionModel? positiveOutlierRepo;
  final CorrelacionModel? negativeOutlierRepo;
  final int itemCount;
  final String? latestSnapshotDate;
  final String? previousSnapshotDate;

  const GithubCorrelationHistorySummaryModel({
    required this.correlationValue,
    required this.topStarsRepo,
    required this.topContributorsRepo,
    required this.topEngagementRepo,
    required this.positiveOutlierRepo,
    required this.negativeOutlierRepo,
    required this.itemCount,
    required this.latestSnapshotDate,
    required this.previousSnapshotDate,
  });

  factory GithubCorrelationHistorySummaryModel.fromMap(
    Map<String, dynamic> map,
  ) {
    CorrelacionModel? parseRepo(String key) {
      final dynamic raw = map[key];
      if (raw is! Map) {
        return null;
      }
      return CorrelacionModel.fromMap(raw.cast<String, dynamic>());
    }

    String? parseDate(String key) {
      final String text = map[key]?.toString().trim() ?? '';
      return text.isEmpty ? null : text;
    }

    return GithubCorrelationHistorySummaryModel(
      correlationValue:
          FrameworkCommitModel._parseNullableDouble(map['correlation_value']) ??
          0.0,
      topStarsRepo: parseRepo('top_stars_repo'),
      topContributorsRepo: parseRepo('top_contributors_repo'),
      topEngagementRepo: parseRepo('top_engagement_repo'),
      positiveOutlierRepo: parseRepo('positive_outlier_repo'),
      negativeOutlierRepo: parseRepo('negative_outlier_repo'),
      itemCount: FrameworkCommitModel._parseNullableInt(map['item_count']) ?? 0,
      latestSnapshotDate: parseDate('latest_snapshot_date'),
      previousSnapshotDate: parseDate('previous_snapshot_date'),
    );
  }
}

class GithubCorrelationSnapshotModel {
  final String date;
  final String? path;
  final String? sourceType;
  final int itemCount;
  final double correlationValue;
  final List<CorrelacionModel> items;

  const GithubCorrelationSnapshotModel({
    required this.date,
    required this.path,
    required this.sourceType,
    required this.itemCount,
    required this.correlationValue,
    required this.items,
  });

  factory GithubCorrelationSnapshotModel.fromMap(Map<String, dynamic> map) {
    final List<dynamic> rawItems = (map['items'] as List?) ?? const [];
    return GithubCorrelationSnapshotModel(
      date: map['date']?.toString() ?? '',
      path: map['path']?.toString().trim().isEmpty ?? true
          ? null
          : map['path']?.toString().trim(),
      sourceType: map['source_type']?.toString().trim().isEmpty ?? true
          ? null
          : map['source_type']?.toString().trim(),
      itemCount: FrameworkCommitModel._parseNullableInt(map['item_count']) ?? 0,
      correlationValue:
          FrameworkCommitModel._parseNullableDouble(map['correlation_value']) ??
          0.0,
      items: rawItems
          .whereType<Map>()
          .map(
            (dynamic item) =>
                CorrelacionModel.fromMap(item.cast<String, dynamic>()),
          )
          .toList(),
    );
  }
}

class GithubCorrelationHistoryModel {
  final String sourceMode;
  final int snapshotCount;
  final String? latestSnapshotDate;
  final String? previousSnapshotDate;
  final int itemCount;
  final bool hasHistoricalComparison;
  final GithubCorrelationHistorySummaryModel summary;
  final List<CorrelacionModel> latestItems;
  final List<GithubCorrelationSnapshotModel> snapshots;

  const GithubCorrelationHistoryModel({
    required this.sourceMode,
    required this.snapshotCount,
    required this.latestSnapshotDate,
    required this.previousSnapshotDate,
    required this.itemCount,
    required this.hasHistoricalComparison,
    required this.summary,
    required this.latestItems,
    required this.snapshots,
  });

  factory GithubCorrelationHistoryModel.fromMap(Map<String, dynamic> map) {
    final List<dynamic> rawLatest = (map['latest_items'] as List?) ?? const [];
    final List<dynamic> rawSnapshots = (map['snapshots'] as List?) ?? const [];
    final String latestSnapshotDate =
        map['latest_snapshot_date']?.toString().trim() ?? '';
    final String previousSnapshotDate =
        map['previous_snapshot_date']?.toString().trim() ?? '';
    return GithubCorrelationHistoryModel(
      sourceMode: map['source_mode']?.toString() ?? '',
      snapshotCount:
          FrameworkCommitModel._parseNullableInt(map['snapshot_count']) ?? 0,
      latestSnapshotDate: latestSnapshotDate.isEmpty
          ? null
          : latestSnapshotDate,
      previousSnapshotDate: previousSnapshotDate.isEmpty
          ? null
          : previousSnapshotDate,
      itemCount: FrameworkCommitModel._parseNullableInt(map['item_count']) ?? 0,
      hasHistoricalComparison:
          map['has_historical_comparison']?.toString().toLowerCase() == 'true',
      summary: GithubCorrelationHistorySummaryModel.fromMap(
        (map['summary'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
      latestItems: rawLatest
          .whereType<Map>()
          .map(
            (dynamic item) =>
                CorrelacionModel.fromMap(item.cast<String, dynamic>()),
          )
          .toList(),
      snapshots: rawSnapshots
          .whereType<Map>()
          .map(
            (dynamic item) => GithubCorrelationSnapshotModel.fromMap(
              item.cast<String, dynamic>(),
            ),
          )
          .toList(),
    );
  }
}

class GithubFrameworkHistoryItemModel {
  final String framework;
  final String repo;
  final int ranking;
  final int commits2025;
  final int? activeContributors;
  final int? mergedPrs;
  final int? closedIssues;
  final int? releasesCount;
  final int? commitsPrev;
  final int? deltaCommits;
  final double? growthPct;
  final String? trendDirection;
  final int? activeContributorsPrev;
  final int? deltaActiveContributors;
  final double? growthActiveContributorsPct;
  final int? mergedPrsPrev;
  final int? deltaMergedPrs;
  final double? growthMergedPrsPct;
  final int? closedIssuesPrev;
  final int? deltaClosedIssues;
  final double? growthClosedIssuesPct;
  final int? releasesCountPrev;
  final int? deltaReleasesCount;
  final double? growthReleasesCountPct;

  const GithubFrameworkHistoryItemModel({
    required this.framework,
    required this.repo,
    required this.ranking,
    required this.commits2025,
    required this.activeContributors,
    required this.mergedPrs,
    required this.closedIssues,
    required this.releasesCount,
    required this.commitsPrev,
    required this.deltaCommits,
    required this.growthPct,
    required this.trendDirection,
    required this.activeContributorsPrev,
    required this.deltaActiveContributors,
    required this.growthActiveContributorsPct,
    required this.mergedPrsPrev,
    required this.deltaMergedPrs,
    required this.growthMergedPrsPct,
    required this.closedIssuesPrev,
    required this.deltaClosedIssues,
    required this.growthClosedIssuesPct,
    required this.releasesCountPrev,
    required this.deltaReleasesCount,
    required this.growthReleasesCountPct,
  });

  factory GithubFrameworkHistoryItemModel.fromMap(Map<String, dynamic> map) {
    return GithubFrameworkHistoryItemModel(
      framework: map['framework']?.toString() ?? '',
      repo: map['repo']?.toString() ?? '',
      ranking: FrameworkCommitModel._parseNullableInt(map['ranking']) ?? 0,
      commits2025:
          FrameworkCommitModel._parseNullableInt(map['commits_2025']) ?? 0,
      activeContributors: FrameworkCommitModel._parseNullableInt(
        map['active_contributors'],
      ),
      mergedPrs: FrameworkCommitModel._parseNullableInt(map['merged_prs']),
      closedIssues: FrameworkCommitModel._parseNullableInt(
        map['closed_issues'],
      ),
      releasesCount: FrameworkCommitModel._parseNullableInt(
        map['releases_count'],
      ),
      commitsPrev: FrameworkCommitModel._parseNullableInt(map['commits_prev']),
      deltaCommits: FrameworkCommitModel._parseNullableInt(
        map['delta_commits'],
      ),
      growthPct: FrameworkCommitModel._parseNullableDouble(map['growth_pct']),
      trendDirection: map['trend_direction']?.toString().trim().isEmpty ?? true
          ? null
          : map['trend_direction']?.toString().trim(),
      activeContributorsPrev: FrameworkCommitModel._parseNullableInt(
        map['active_contributors_prev'],
      ),
      deltaActiveContributors: FrameworkCommitModel._parseNullableInt(
        map['delta_active_contributors'],
      ),
      growthActiveContributorsPct: FrameworkCommitModel._parseNullableDouble(
        map['growth_active_contributors_pct'],
      ),
      mergedPrsPrev: FrameworkCommitModel._parseNullableInt(
        map['merged_prs_prev'],
      ),
      deltaMergedPrs: FrameworkCommitModel._parseNullableInt(
        map['delta_merged_prs'],
      ),
      growthMergedPrsPct: FrameworkCommitModel._parseNullableDouble(
        map['growth_merged_prs_pct'],
      ),
      closedIssuesPrev: FrameworkCommitModel._parseNullableInt(
        map['closed_issues_prev'],
      ),
      deltaClosedIssues: FrameworkCommitModel._parseNullableInt(
        map['delta_closed_issues'],
      ),
      growthClosedIssuesPct: FrameworkCommitModel._parseNullableDouble(
        map['growth_closed_issues_pct'],
      ),
      releasesCountPrev: FrameworkCommitModel._parseNullableInt(
        map['releases_count_prev'],
      ),
      deltaReleasesCount: FrameworkCommitModel._parseNullableInt(
        map['delta_releases_count'],
      ),
      growthReleasesCountPct: FrameworkCommitModel._parseNullableDouble(
        map['growth_releases_count_pct'],
      ),
    );
  }
}

class GithubFrameworkHistorySummaryModel {
  final String? leaderFramework;
  final int? leaderCommits;
  final String? maxGrowthFramework;
  final int? maxGrowthDelta;
  final String? maxDropFramework;
  final int? maxDropDelta;
  final int missingMetricsFrameworks;

  const GithubFrameworkHistorySummaryModel({
    required this.leaderFramework,
    required this.leaderCommits,
    required this.maxGrowthFramework,
    required this.maxGrowthDelta,
    required this.maxDropFramework,
    required this.maxDropDelta,
    required this.missingMetricsFrameworks,
  });

  factory GithubFrameworkHistorySummaryModel.fromMap(Map<String, dynamic> map) {
    return GithubFrameworkHistorySummaryModel(
      leaderFramework: map['leader_framework']?.toString(),
      leaderCommits: FrameworkCommitModel._parseNullableInt(
        map['leader_commits'],
      ),
      maxGrowthFramework: map['max_growth_framework']?.toString(),
      maxGrowthDelta: FrameworkCommitModel._parseNullableInt(
        map['max_growth_delta'],
      ),
      maxDropFramework: map['max_drop_framework']?.toString(),
      maxDropDelta: FrameworkCommitModel._parseNullableInt(
        map['max_drop_delta'],
      ),
      missingMetricsFrameworks:
          FrameworkCommitModel._parseNullableInt(
            map['missing_metrics_frameworks'],
          ) ??
          0,
    );
  }
}

class GithubFrameworkMonthlySeriesModel {
  final String framework;
  final List<GithubFrameworkMonthlyPointModel> points;

  const GithubFrameworkMonthlySeriesModel({
    required this.framework,
    required this.points,
  });

  factory GithubFrameworkMonthlySeriesModel.fromMap(Map<String, dynamic> map) {
    final List<dynamic> rawPoints = (map['points'] as List?) ?? const [];
    return GithubFrameworkMonthlySeriesModel(
      framework: map['framework']?.toString() ?? '',
      points: rawPoints
          .whereType<Map>()
          .map(
            (item) => GithubFrameworkMonthlyPointModel.fromMap(
              item.cast<String, dynamic>(),
            ),
          )
          .toList(),
    );
  }
}

class GithubFrameworkMonthlyPointModel {
  final String month;
  final int commits;

  const GithubFrameworkMonthlyPointModel({
    required this.month,
    required this.commits,
  });

  factory GithubFrameworkMonthlyPointModel.fromMap(Map<String, dynamic> map) {
    return GithubFrameworkMonthlyPointModel(
      month: map['month']?.toString() ?? '',
      commits: FrameworkCommitModel._parseNullableInt(map['commits']) ?? 0,
    );
  }
}

class GithubFrameworkHistoryModel {
  final String sourceMode;
  final int snapshotCount;
  final String? snapshotDate;
  final String? latestSnapshotDate;
  final String? previousSnapshotDate;
  final int itemCount;
  final bool hasHistoricalComparison;
  final List<GithubFrameworkHistoryItemModel> latestFrameworks;
  final GithubFrameworkHistorySummaryModel summary;
  final List<GithubFrameworkMonthlySeriesModel> series;

  const GithubFrameworkHistoryModel({
    required this.sourceMode,
    required this.snapshotCount,
    required this.snapshotDate,
    required this.latestSnapshotDate,
    required this.previousSnapshotDate,
    required this.itemCount,
    required this.hasHistoricalComparison,
    required this.latestFrameworks,
    required this.summary,
    required this.series,
  });

  factory GithubFrameworkHistoryModel.fromMap(Map<String, dynamic> map) {
    final List<dynamic> rawLatest =
        (map['latest_frameworks'] as List?) ?? const [];
    final List<dynamic> rawSeries = (map['series'] as List?) ?? const [];
    return GithubFrameworkHistoryModel(
      sourceMode: map['source_mode']?.toString() ?? '',
      snapshotCount:
          FrameworkCommitModel._parseNullableInt(map['snapshot_count']) ?? 0,
      snapshotDate: map['snapshot_date']?.toString().trim().isEmpty ?? true
          ? null
          : map['snapshot_date']?.toString(),
      latestSnapshotDate:
          map['latest_snapshot_date']?.toString().trim().isEmpty ?? true
          ? null
          : map['latest_snapshot_date']?.toString(),
      previousSnapshotDate:
          map['previous_snapshot_date']?.toString().trim().isEmpty ?? true
          ? null
          : map['previous_snapshot_date']?.toString(),
      itemCount: FrameworkCommitModel._parseNullableInt(map['item_count']) ?? 0,
      hasHistoricalComparison:
          map['has_historical_comparison']?.toString().toLowerCase() == 'true',
      latestFrameworks: rawLatest
          .whereType<Map>()
          .map(
            (item) => GithubFrameworkHistoryItemModel.fromMap(
              item.cast<String, dynamic>(),
            ),
          )
          .toList(),
      summary: GithubFrameworkHistorySummaryModel.fromMap(
        (map['summary'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
      series: rawSeries
          .whereType<Map>()
          .map(
            (item) => GithubFrameworkMonthlySeriesModel.fromMap(
              item.cast<String, dynamic>(),
            ),
          )
          .toList(),
    );
  }

  bool get hasGrowthSignals {
    return snapshotCount >= 2 &&
        latestFrameworks.any((item) => item.deltaCommits != null);
  }
}
