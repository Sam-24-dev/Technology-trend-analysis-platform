// ==========================================
// MODELOS DE DATOS (Data Layer)
// Objetivo: Mapear y sanitizar los datos crudos del ETL (Python/CSV)
// para su uso seguro en la UI de Flutter.
// ==========================================

/// Modelo para el Gráfico 1: Volumen Total de Preguntas.
/// Mapea los datos generados en 'so_volumen_preguntas.csv'.
class VolumenPreguntasModel {
  // Campos 'final' para garantizar la inmutabilidad del dato una vez cargado.
  final String lenguaje;
  final int preguntas;

  VolumenPreguntasModel({required this.lenguaje, required this.preguntas});

  /// Factory constructor para la deserialización segura (JSON/Map -> Objeto).
  factory VolumenPreguntasModel.fromMap(Map<String, dynamic> map) {
    return VolumenPreguntasModel(
      lenguaje:
          map['lenguaje'] ??
          'Desconocido', // Valor por defecto si falta la clave
      // LÓGICA DEFENSIVA DE PARSEO:
      // 1. map[...]?.toString(): Convierte a String seguro (maneja si viene como int o string del backend).
      // 2. ?? '0': Si es nulo, asume "0".
      // 3. int.tryParse: Intenta convertir a entero.
      // 4. ?? 0: Si el formato es inválido, devuelve 0 en lugar de romper la app.
      preguntas:
          int.tryParse(map['preguntas_nuevas_2025']?.toString() ?? '0') ?? 0,
    );
  }
}

/// Modelo para el Gráfico 2: Tasa de Aceptación (Calidad/Madurez).
/// Mapea los datos de 'so_tasa_aceptacion.csv'.
class TasaAceptacionModel {
  final String tecnologia;
  final double tasaPct; // Manejo de decimales para precisión porcentual
  final int totalPreguntas;

  TasaAceptacionModel({
    required this.tecnologia,
    required this.tasaPct,
    required this.totalPreguntas,
  });

  factory TasaAceptacionModel.fromMap(Map<String, dynamic> map) {
    return TasaAceptacionModel(
      tecnologia: map['tecnologia'] ?? '',

      // Conversión robusta para punto flotante (Double).
      // Evita errores si el CSV trae "45.5" (String) o 45.5 (Number).
      tasaPct:
          double.tryParse(map['tasa_aceptacion_pct']?.toString() ?? '0') ?? 0.0,

      totalPreguntas:
          int.tryParse(map['total_preguntas']?.toString() ?? '0') ?? 0,
    );
  }
}

/// Modelo para el Gráfico 3: Tendencias Históricas Mensuales.
/// Mapea la evolución temporal desde 'so_tendencias_mensuales.csv'.
class TendenciaMensualModel {
  final String mes;
  // Métricas por lenguaje para comparación multi-lineal.
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

      // Aplicación consistente del patrón de parseo seguro para cada serie de datos.
      python: int.tryParse(map['python']?.toString() ?? '0') ?? 0,
      javascript: int.tryParse(map['javascript']?.toString() ?? '0') ?? 0,
      typescript: int.tryParse(map['typescript']?.toString() ?? '0') ?? 0,
    );
  }
}
