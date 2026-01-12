class SentimientoModel {
  final String framework;
  final double porcentajePositivo;
  final double porcentajeNegativo;

  SentimientoModel({
    required this.framework,
    required this.porcentajePositivo,
    required this.porcentajeNegativo,
  });

  factory SentimientoModel.fromMap(Map<String, dynamic> map) {
    return SentimientoModel(
      framework: map['framework'] ?? '',
      porcentajePositivo:
          double.tryParse(map['% positivo']?.toString() ?? '0') ?? 0,
      porcentajeNegativo:
          double.tryParse(map['% negativo']?.toString() ?? '0') ?? 0,
    );
  }
}

class TemasEmergentesModel {
  final String tema;
  final int menciones;

  TemasEmergentesModel({required this.tema, required this.menciones});

  factory TemasEmergentesModel.fromMap(Map<String, dynamic> map) {
    return TemasEmergentesModel(
      tema: map['tema'] ?? '',
      menciones:
          int.tryParse(map['menciones']?.toString() ?? '0') ?? 0,
    );
  }
}

class InterseccionModel {
  final String tecnologia;
  final int? rankingGitHub;
  final int? rankingReddit;

  InterseccionModel({
    required this.tecnologia,
    required this.rankingGitHub,
    required this.rankingReddit,
  });

  factory InterseccionModel.fromMap(Map<String, dynamic> map) {
    final githubStr = map['ranking_github']?.toString() ?? '';
    final redditStr = map['ranking_reddit']?.toString() ?? '';

    return InterseccionModel(
      tecnologia: map['tecnologia'] ?? '',
      rankingGitHub: (githubStr.isEmpty || githubStr == 'No encontrado')
          ? null
          : int.tryParse(githubStr),
      rankingReddit: (redditStr.isEmpty || redditStr == 'No encontrado')
          ? null
          : int.tryParse(redditStr),
    );
  }
}
