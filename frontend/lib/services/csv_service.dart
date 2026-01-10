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
    try {
      final rawData = await rootBundle.loadString(assetPath);
      List<List<dynamic>> csvData = const CsvToListConverter().convert(rawData);
      
      if (csvData.isEmpty) return [];
      
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
      print('Error cargando CSV: $e');
      return [];
    }
  }
}
