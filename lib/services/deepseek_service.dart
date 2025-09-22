import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DeepSeekService {
  late final String _apiKey;
  late final String _baseUrl;

  static const Duration _timeout = Duration(seconds: 30);
  static const int _maxRetries = 2;

  DeepSeekService() {
    _apiKey = dotenv.env['DEEPSEEK_API_KEY'] ?? '';
    _baseUrl = dotenv.env['DEEPSEEK_BASE_URL'] ?? 'https://api.deepseek.com/v1';
    print("🔑 API Key Loaded: ${_apiKey.isNotEmpty ? "Yes" : "No"}");
    print("🌍 Base URL: $_baseUrl");

    if (_apiKey.isEmpty) {
      throw Exception('❌ DeepSeek API key not found in environment variables');
    }
  }

  Future<String> analyzeSymptoms(List<String> symptoms, String severity,
      Map<String, dynamic> additionalInfo) async {
    final prompt =
        _buildSymptomAnalysisPrompt(symptoms, severity, additionalInfo);
    return _safeApiCall(prompt, 'Error analyzing symptoms');
  }

  Future<String> checkMedicationInteractions(List<String> medications) async {
    final prompt = _buildMedicationInteractionPrompt(medications);
    return _safeApiCall(prompt, 'Error checking medication interactions');
  }

  Future<String> getHealthInsights(Map<String, dynamic> healthData) async {
    final prompt = _buildHealthInsightsPrompt(healthData);
    return _safeApiCall(prompt, 'Error getting health insights');
  }

  Future<String> _safeApiCall(String prompt, String contextMessage) async {
    try {
      return await _makeApiCallWithRetry(prompt);
    } on TimeoutException {
      print('⏳ $contextMessage: Request timed out.');
      return 'The request took too long. Please try again later.';
    } catch (e) {
      print('⚠️ $contextMessage: $e');
      return 'Unable to complete this request right now. Please try again later.';
    }
  }

  Future<String> _makeApiCallWithRetry(String prompt) async {
    int attempts = 0;
    while (true) {
      try {
        return await _makeApiCall(prompt);
      } catch (e) {
        attempts++;
        if (attempts > _maxRetries) rethrow;
        print('🔄 Retrying API call... (Attempt $attempts/$_maxRetries)');
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  Future<String> _makeApiCall(String prompt) async {
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_apiKey',
    };

    final body = jsonEncode({
      'model': 'deepseek-chat',
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a helpful medical AI assistant. Provide informative responses about health topics, but always recommend consulting healthcare professionals for serious concerns. Keep responses concise and user-friendly. Always include appropriate medical disclaimers.'
        },
        {'role': 'user', 'content': prompt}
      ],
      'max_tokens': 800,
      'temperature': 0.7,
      'stream': false,
    });

    final response = await http
        .post(Uri.parse('$_baseUrl/chat/completions'),
            headers: headers, body: body)
        .timeout(_timeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final choices = data['choices'];
      if (choices != null && choices.isNotEmpty) {
        return choices[0]['message']['content']?.trim() ??
            'No response received from AI service.';
      } else {
        throw Exception('Invalid response format from API');
      }
    } else {
      throw Exception('API request failed with status: ${response.statusCode}');
    }
  }

  String _buildSymptomAnalysisPrompt(List<String> symptoms, String severity,
      Map<String, dynamic> additionalInfo) {
    final buffer = StringBuffer()
      ..writeln(
          "Please analyze these symptoms and provide helpful medical information:\n")
      ..writeln("**Symptoms:** ${symptoms.join(', ')}")
      ..writeln("**Severity:** $severity\n");

    if (additionalInfo.isNotEmpty) {
      buffer.writeln("**Additional Information:**");
      additionalInfo.forEach((key, value) {
        if (value.toString().isNotEmpty) {
          buffer.writeln("- ${key.replaceAll('_', ' ').toUpperCase()}: $value");
        }
      });
      buffer.writeln();
    }

    buffer.writeln("""
Please provide a comprehensive analysis including:

1. **Possible Common Causes:** List potential common conditions
2. **When to Seek Medical Attention:** Clear guidelines for urgent care
3. **Self-Care Recommendations:** Safe, general suggestions
4. **Important Considerations:** Any red flags
5. **Medical Disclaimer:** Remind that this is informational only
""");

    return buffer.toString();
  }

  String _buildMedicationInteractionPrompt(List<String> medications) {
    return """
Please analyze potential interactions between these medications:

**Current Medications:** ${medications.join(', ')}

Include:
1. Interaction assessment (Minor/Moderate/Major)
2. Clinical significance & potential effects
3. Monitoring recommendations
4. When to consult healthcare providers
5. Overall safety summary

Always remind users this is not a substitute for professional medical advice.
""";
  }

  String _buildHealthInsightsPrompt(Map<String, dynamic> healthData) {
    final buffer = StringBuffer()..writeln("**Current Health Metrics:**");
    healthData.forEach((key, value) {
      buffer.writeln("- ${key.replaceAll('_', ' ').toUpperCase()}: $value");
    });

    buffer.writeln("""
Provide insights including:
1. Positive observations
2. Health trends
3. Improvement opportunities
4. General lifestyle tips
5. Motivational encouragement
""");

    return buffer.toString();
  }

  bool get isConfigured => _apiKey.isNotEmpty;

  String get configurationStatus =>
      'API Key: ${_apiKey.isNotEmpty ? "✓ Configured" : "✗ Missing"}\nBase URL: $_baseUrl';
}
