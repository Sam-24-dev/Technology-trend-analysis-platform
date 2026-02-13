import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';

class CsvService {
  static Future<List<List<dynamic>>> loadCsv(String assetPath) async {
    try {
      final rawData = await rootBundle.loadString(assetPath);
      List<List<dynamic>> csvData = const CsvToListConverter().convert(rawData);
      
      // Ignorar la primera fila (headers)
      if (csvData.isNotEmpty) {
        csvData = csvData.sublist(1);
      }
      
      return csvData;
    } catch (e) {
      print('Error cargando CSV: $e');
      return [];
    }
  }
  
  static Future<List<Map<String, dynamic>>> loadCsvAsMap(String assetPath) async {
    // Intentar con la ruta original y con prefijos comunes para GitHub Pages
    final pathsToTry = [
      assetPath,
      'assets/$assetPath',
      'Technology-trend-analysis-platform/$assetPath',
      '/Technology-trend-analysis-platform/$assetPath',
    ];

    for (final path in pathsToTry) {
      try {
        final rawData = await rootBundle.loadString(path);
        List<List<dynamic>> csvData = const CsvToListConverter().convert(rawData);
        
        if (csvData.isEmpty) continue;
        
        // Primera fila son los headers
        final headers = csvData[0].map((e) => e.toString()).toList();
        final dataRows = csvData.sublist(1);
        
        return dataRows.map((row) {
          Map<String, dynamic> map = {};
          for (int i = 0; i < headers.length && i < row.length; i++) {
            map[headers[i]] = row[i];
          }
          return map;
        }).toList();
      } catch (e) {
        // Continuar con el siguiente path si falla
        print('Fallo al cargar $path: $e');
        continue;
      }
    }
    
    // Si llegamos aquí, ninguno funcionó
    throw Exception('No se pudo cargar el CSV en ninguna de las rutas probadas: $pathsToTry');
  }
}
