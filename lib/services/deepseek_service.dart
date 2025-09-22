import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DeepSeekService {
  late final String _apiKey;
  late final String _baseUrl;

  // OPTIMIZED: Reduced timeout from 30s to 15s for faster failure detection
  static const Duration _timeout = Duration(seconds: 15);

  // OPTIMIZED: Increased retries from 2 to 3 for better success rate
  static const int _maxRetries = 3;

  // OPTIMIZED: Exponential backoff delays
  static const List<int> _retryDelays = [1000, 2000, 4000]; // ms

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

  // Add this new method for chat conversations
  Future<String> sendChatMessage(
      List<Map<String, String>> conversationHistory) async {
    final prompt = _buildChatPrompt(conversationHistory);
    return _safeApiCall(prompt, 'Error in chat conversation', isChat: true);
  }

// Update the _safeApiCall method to handle chat context
  Future<String> _safeApiCall(String prompt, String contextMessage,
      {bool isChat = false}) async {
    try {
      if (isChat) {
        return await _makeChatApiCall(prompt);
      } else {
        return await _makeApiCallWithRetry(prompt);
      }
    } on TimeoutException {
      print('⏳ $contextMessage: Request timed out.');
      return 'The request took too long. Please try again later.';
    } catch (e) {
      print('⚠️ $contextMessage: $e');
      return 'Unable to complete this request right now. Please try again later.';
    }
  }

// Add new method for chat API calls with conversation history
  // Update your _makeChatApiCall method with enhanced system message
  Future<String> _makeChatApiCall(String conversationHistoryJson) async {
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_apiKey',
    };

    // Parse the conversation history from JSON
    final List<dynamic> messages = jsonDecode(conversationHistoryJson);

    // Add enhanced system message at the beginning if not present
    if (messages.isEmpty || messages.first['role'] != 'system') {
      messages.insert(0, {
        'role': 'system',
        'content':
            '''You are PersonalMedAI, a warm, empathetic, and knowledgeable medical AI assistant. You have a caring personality and always strive to provide helpful, accurate health information.

Your key characteristics:
- Friendly and approachable tone
- Empathetic and supportive responses  
- Professional medical knowledge
- Always prioritize user safety
- Encourage consulting healthcare professionals when needed

Guidelines for responses:
- Greet users warmly by name when possible
- Provide clear, concise medical information
- Use reassuring language while being honest about limitations
- Include appropriate disclaimers about seeking professional medical care
- Ask follow-up questions when helpful
- Show genuine care for the user's wellbeing
- Keep responses focused and under 300 words
- Use emojis sparingly but appropriately (like 🩺 💊 ❤️)

Remember: You are here to inform and support, not to replace professional medical consultation. Always recommend seeing a healthcare provider for serious concerns, diagnosis, or treatment decisions.'''
      });
    }

    final body = jsonEncode({
      'model': 'deepseek-chat',
      'messages': messages,
      'max_tokens': 400,
      'temperature': 0.5,
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
        String content = choices[0]['message']['content']?.trim() ??
            'No response received from AI service.';
        content = _removeWordCountAnnotations(content);
        return content;
      } else {
        throw Exception('Invalid response format from API');
      }
    } else {
      throw Exception('API request failed with status: ${response.statusCode}');
    }
  }

// Add helper method to build chat prompt from conversation history
  String _buildChatPrompt(List<Map<String, String>> conversationHistory) {
    // Convert conversation history to the format expected by the API
    final messages = conversationHistory
        .map((message) => {
              'role': message['isUser'] == 'true' ? 'user' : 'assistant',
              'content': message['text'] ?? '',
            })
        .toList();

    return jsonEncode(messages);
  }

// Update the getHealthInsights method to handle both single queries and chat format
  Future<String> getHealthInsights(dynamic healthData) async {
    // If healthData is a string, treat it as a single chat message
    if (healthData is String) {
      final conversationHistory = [
        {'isUser': 'true', 'text': healthData}
      ];
      return sendChatMessage(conversationHistory);
    }

    // Otherwise, use the existing health insights logic
    if (healthData is Map<String, dynamic>) {
      final prompt = _buildHealthInsightsPrompt(healthData);
      return _safeApiCall(prompt, 'Error getting health insights');
    }

    throw ArgumentError('Invalid healthData format');
  }

  Future<String> _makeApiCallWithRetry(String prompt) async {
    int attempts = 0;

    while (true) {
      try {
        return await _makeApiCall(prompt);
      } catch (e) {
        attempts++;
        if (attempts > _maxRetries) rethrow;

        // OPTIMIZED: Exponential backoff with jitter
        final delayMs = _retryDelays[attempts - 1];
        final jitter =
            (delayMs * 0.1 * (DateTime.now().millisecond % 100) / 100).round();
        final finalDelay = delayMs + jitter;

        print(
            '🔄 Retrying API call... (Attempt $attempts/$_maxRetries) - waiting ${finalDelay}ms');
        await Future.delayed(Duration(milliseconds: finalDelay));
      }
    }
  }

  Future<String> _makeApiCall(String prompt) async {
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_apiKey',
    };

    // OPTIMIZED: Reduced max_tokens from 800 to 400 for faster responses
    // OPTIMIZED: Reduced temperature from 0.7 to 0.5 for more focused responses
    // OPTIMIZED: Added stream: true for faster perceived response times
    final body = jsonEncode({
      'model': 'deepseek-chat',
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a helpful medical AI assistant. Provide concise, informative responses about health topics. Always recommend consulting healthcare professionals for serious concerns. Keep responses brief and focused. Include appropriate medical disclaimers.'
        },
        {'role': 'user', 'content': prompt}
      ],
      'max_tokens': 400, // REDUCED from 800
      'temperature': 0.5, // REDUCED from 0.7
      'stream': false, // Keep false for now, but consider streaming for UI
    });

    // OPTIMIZED: Separate connect and read timeouts
    final response = await http
        .post(Uri.parse('$_baseUrl/chat/completions'),
            headers: headers, body: body)
        .timeout(_timeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final choices = data['choices'];
      if (choices != null && choices.isNotEmpty) {
        String content = choices[0]['message']['content']?.trim() ??
            'No response received from AI service.';
        content = _removeWordCountAnnotations(content);
        return content;
      } else {
        throw Exception('Invalid response format from API');
      }
    } else {
      throw Exception('API request failed with status: ${response.statusCode}');
    }
  }

  String _removeWordCountAnnotations(String text) {
    // Remove patterns like "(Word count: 98)" or "*Word count: 98*"
    return text
        .replaceAll(RegExp(r'\*?\(Word count: \d+\)\*?'), '')
        .replaceAll(RegExp(r'\*Word count: \d+\*'), '')
        .replaceAll(RegExp(r'\(Word count: \d+\)'), '')
        .replaceAll(RegExp(r'Word count: \d+'), '')
        .trim();
  }

  // OPTIMIZED: Shortened and more focused prompts to reduce processing time
  String _buildSymptomAnalysisPrompt(List<String> symptoms, String severity,
      Map<String, dynamic> additionalInfo) {
    final buffer = StringBuffer()
      ..writeln("Analyze these symptoms briefly:")
      ..writeln("Symptoms: ${symptoms.join(', ')}")
      ..writeln("Severity: $severity");

    if (additionalInfo.isNotEmpty) {
      buffer.writeln("Additional info:");
      additionalInfo.forEach((key, value) {
        if (value.toString().isNotEmpty) {
          buffer.writeln("- ${key.replaceAll('_', ' ')}: $value");
        }
      });
    }

    buffer.writeln("""
Provide concise analysis:
1. Possible causes (2-3 main ones)
2. When to seek medical attention
3. Basic self-care suggestions
4. Medical disclaimer

Keep response under 300 words.
""");
    return buffer.toString();
  }

  String _buildMedicationInteractionPrompt(List<String> medications) {
    return """
Analyze interactions between: ${medications.join(', ')}

Provide brief summary:
1. Interaction level (Minor/Moderate/Major)
2. Key effects to watch for
3. When to consult healthcare provider
4. Medical disclaimer

Keep response under 250 words.
""";
  }

  String _buildHealthInsightsPrompt(Map<String, dynamic> healthData) {
    final buffer = StringBuffer()..writeln("Health metrics:");

    healthData.forEach((key, value) {
      buffer.writeln("- ${key.replaceAll('_', ' ')}: $value");
    });

    buffer.writeln("""
Provide brief insights:
1. Key observations
2. Improvement suggestions
3. General lifestyle tips
4. Encouragement

Keep response under 200 words.
""");
    return buffer.toString();
  }

  bool get isConfigured => _apiKey.isNotEmpty;
  String get configurationStatus =>
      'API Key: ${_apiKey.isNotEmpty ? "✓ Configured" : "✗ Missing"}\nBase URL: $_baseUrl';
}
