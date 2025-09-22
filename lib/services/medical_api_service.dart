import 'dart:convert';
import 'package:http/http.dart' as http;

class MedicalApiService {
  // Using FDA API and NLM APIs (free public APIs)
  static const String _fdaBaseUrl = 'https://api.fda.gov';
  static const String _nlmBaseUrl = 'https://clinicaltables.nlm.nih.gov/api';

  // Get drug information from FDA
  static Future<Map<String, dynamic>?> getDrugInfo(String drugName) async {
    try {
      final url =
          '$_fdaBaseUrl/drug/label.json?search=openfda.brand_name:"$drugName"&limit=1';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['results']?.first;
      }
    } catch (e) {
      print('Error fetching drug info: $e');
    }
    return null;
  }

  // Get disease information from NLM
  static Future<List<String>> getDiseaseSymptoms(String disease) async {
    try {
      final url =
          '$_nlmBaseUrl/conditions/v3/search?terms=$disease&ef=primary_name,symptoms';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<String>.from(data[1] ?? []);
      }
    } catch (e) {
      print('Error fetching disease symptoms: $e');
    }
    return [];
  }

  // Search for medical conditions
  static Future<List<Map<String, dynamic>>> searchConditions(
      String query) async {
    try {
      final url = '$_nlmBaseUrl/conditions/v3/search?terms=$query&maxList=10';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = <Map<String, dynamic>>[];

        for (int i = 0; i < (data[1]?.length ?? 0); i++) {
          results.add({
            'name': data[1][i],
            'id': data[0][i],
          });
        }
        return results;
      }
    } catch (e) {
      print('Error searching conditions: $e');
    }
    return [];
  }
}
