class VolumenPreguntasModel {
  final String lenguaje;
  final int preguntas;

  VolumenPreguntasModel({required this.lenguaje, required this.preguntas});

  factory VolumenPreguntasModel.fromMap(Map<String, dynamic> map) {
    return VolumenPreguntasModel(
      lenguaje: map['lenguaje'] ?? '',
      // Tu script guarda la columna como 'preguntas_nuevas_2025'
      preguntas:
          int.tryParse(map['preguntas_nuevas_2025']?.toString() ?? '0') ?? 0,
    );
  }
}

class TasaAceptacionModel {
  final String tecnologia;
  final double tasaPct;
  final int totalPreguntas;

  TasaAceptacionModel({
    required this.tecnologia,
    required this.tasaPct,
    required this.totalPreguntas,
  });

  factory TasaAceptacionModel.fromMap(Map<String, dynamic> map) {
    return TasaAceptacionModel(
      tecnologia: map['tecnologia'] ?? '',
      tasaPct:
          double.tryParse(map['tasa_aceptacion_pct']?.toString() ?? '0') ?? 0.0,
      totalPreguntas:
          int.tryParse(map['total_preguntas']?.toString() ?? '0') ?? 0,
    );
  }
}

class TendenciaMensualModel {
  final String mes;
  final int python;
  final int javascript;
  final int typescript;

  TendenciaMensualModel({
    required this.mes,
    required this.python,
    required this.javascript,
    required this.typescript,
  });

  factory TendenciaMensualModel.fromMap(Map<String, dynamic> map) {
    return TendenciaMensualModel(
      mes: map['mes'] ?? '',
      python: int.tryParse(map['python']?.toString() ?? '0') ?? 0,
      javascript: int.tryParse(map['javascript']?.toString() ?? '0') ?? 0,
      typescript: int.tryParse(map['typescript']?.toString() ?? '0') ?? 0,
    );
  }
}
