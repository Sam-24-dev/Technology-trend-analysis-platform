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

class FrameworkCommitModel {
  final String framework;
  final String repo;
  final int commits2025;
  final int ranking;

  FrameworkCommitModel({
    required this.framework,
    required this.repo,
    required this.commits2025,
    required this.ranking,
  });

  factory FrameworkCommitModel.fromMap(Map<String, dynamic> map) {
    return FrameworkCommitModel(
      framework: map['framework']?.toString() ?? '',
      repo: map['repo']?.toString() ?? '',
      commits2025: int.tryParse(map['commits_2025']?.toString() ?? '0') ?? 0,
      ranking: int.tryParse(map['ranking']?.toString() ?? '0') ?? 0,
    );
  }
}

class CorrelacionModel {
  final String repoName;
  final int stars;
  final int contributors;
  final String language;

  CorrelacionModel({
    required this.repoName,
    required this.stars,
    required this.contributors,
    required this.language,
  });

  factory CorrelacionModel.fromMap(Map<String, dynamic> map) {
    return CorrelacionModel(
      repoName: map['repo_name']?.toString() ?? '',
      stars: int.tryParse(map['stars']?.toString() ?? '0') ?? 0,
      contributors: int.tryParse(map['contributors']?.toString() ?? '0') ?? 0,
      language: map['language']?.toString() ?? '',
    );
  }
}
