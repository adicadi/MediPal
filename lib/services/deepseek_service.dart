import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DeepSeekService {
  late final String _apiKey;
  late final String _baseUrl;

  // OPTIMIZED: Reduced timeout for faster failure detection
  static const Duration _timeout = Duration(seconds: 20);
  static const int _maxRetries = 2;
  static const Duration _connectTimeout = Duration(seconds: 3);

  // OPTIMIZED: Quick response cache for common queries
  static const Map<String, String> _quickResponses = {
    'hello':
        'Hello! I\'m PersonalMedAI, your health assistant. How can I help you today? 😊',
    'hi':
        'Hi there! I\'m here to help with any health questions you might have! 🩺',
    'help':
        'I can help you with:\n• Medical questions and symptoms\n• Medication information\n• Health guidance\n• Emergency information\n\nWhat would you like to know?',
    'emergency':
        '🚨 **MEDICAL EMERGENCY?**\n\nCall 911 immediately if experiencing:\n• Difficulty breathing\n• Chest pain\n• Severe bleeding\n• Loss of consciousness',
    'thanks':
        'You\'re welcome! I\'m always here to help with your health questions. Take care! 😊',
    'thank you':
        'You\'re very welcome! Feel free to ask if you have more questions. Stay healthy! 💙',
  };

  DeepSeekService() {
    _apiKey = dotenv.env['DEEPSEEK_API_KEY'] ?? '';
    _baseUrl = dotenv.env['DEEPSEEK_BASE_URL'] ?? 'https://api.deepseek.com/v1';

    print("🔑 API Key Loaded: ${_apiKey.isNotEmpty ? "Yes" : "No"}");
    print("🌍 Base URL: $_baseUrl");

    if (_apiKey.isEmpty) {
      throw Exception('❌ DeepSeek API key not found in environment variables');
    }
  }

  // OPTIMIZED: Check for quick responses first
  String? getQuickResponse(String message) {
    final normalizedMessage = message.toLowerCase().trim();

    // Direct matches
    if (_quickResponses.containsKey(normalizedMessage)) {
      return _quickResponses[normalizedMessage];
    }

    // Partial matches for common patterns
    if (normalizedMessage.contains('headache')) {
      return '🩺 **Headache Relief:**\n• Stay hydrated (drink water)\n• Rest in a quiet, dark room\n• Apply cold/warm compress\n• Consider OTC pain relief\n\n⚠️ See a doctor if severe or persistent.';
    }

    if (normalizedMessage.contains('fever')) {
      return '🌡️ **Fever Management:**\n• Stay hydrated\n• Rest and monitor temperature\n• Light clothing\n• Seek medical attention if >101.5°F (38.6°C)\n\n⚠️ Contact healthcare provider if persistent.';
    }

    if (normalizedMessage.contains('medication') &&
        normalizedMessage.contains('safe')) {
      return '💊 **Medication Safety:**\n• Always follow prescribed dosage\n• Check for drug interactions\n• Store properly\n• Don\'t share medications\n\n⚠️ Consult your pharmacist or doctor with questions.';
    }

    return null; // No quick response available
  }

  // OPTIMIZED: Enhanced streaming with proper error handling
  Stream<String> streamChatResponse(
      List<Map<String, String>> conversationHistory) async* {
    // Check for quick response first
    if (conversationHistory.isNotEmpty) {
      final lastMessage = conversationHistory.last;
      if (lastMessage['isUser'] == 'true') {
        final quickResponse = getQuickResponse(lastMessage['text'] ?? '');
        if (quickResponse != null) {
          // Simulate typing delay for quick responses
          await Future.delayed(const Duration(milliseconds: 300));
          yield quickResponse;
          return;
        }
      }
    }

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_apiKey',
      'Accept': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
    };

    final messages = _buildMessageHistory(conversationHistory);

    final body = jsonEncode({
      'model': 'deepseek-chat',
      'messages': messages,
      'max_tokens': 250, // Reduced for faster responses
      'temperature': 0.4, // Slightly reduced for more focused responses
      'stream': true,
      'top_p': 0.8, // Add for faster generation
    });

    try {
      final request =
          http.Request('POST', Uri.parse('$_baseUrl/chat/completions'))
            ..headers.addAll(headers)
            ..body = body;

      final client = http.Client();
      final streamedResponse = await client.send(request).timeout(_timeout);

      if (streamedResponse.statusCode != 200) {
        throw Exception(
            'API request failed with status: ${streamedResponse.statusCode}');
      }

      String accumulatedText = '';

      await for (final line in streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .where((line) => line.trim().isNotEmpty)) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6).trim();

          if (data == '[DONE]') {
            break;
          }

          try {
            final json = jsonDecode(data);
            final content = json['choices']?[0]?['delta']?['content'];

            if (content != null && content.isNotEmpty) {
              accumulatedText += content;
              yield accumulatedText;
            }
          } catch (e) {
            // Skip malformed chunks
            continue;
          }
        }
      }

      client.close();
    } catch (e) {
      print('Streaming error: $e');
      // Fallback to regular API call
      try {
        final response = await sendChatMessage(conversationHistory);
        yield response;
      } catch (fallbackError) {
        yield 'I apologize, but I\'m experiencing technical difficulties. Please try again in a moment.';
      }
    }
  }

  // OPTIMIZED: Enhanced regular chat with quick response check
  Future<String> sendChatMessage(
      List<Map<String, dynamic>> conversationHistory) async {
    // Check for quick response first
    if (conversationHistory.isNotEmpty) {
      final lastMessage = conversationHistory.last;
      if (lastMessage['isUser'] == 'true') {
        final quickResponse = getQuickResponse(lastMessage['text'] ?? '');
        if (quickResponse != null) {
          // Simulate a small delay to feel natural
          await Future.delayed(const Duration(milliseconds: 500));
          return quickResponse;
        }
      }
    }

    final prompt = _buildChatPrompt(conversationHistory);
    return _safeApiCall(prompt, 'Error in chat conversation', isChat: true);
  }

  // Helper method to build message history for streaming
  List<Map<String, String>> _buildMessageHistory(
      List<Map<String, String>> conversationHistory) {
    final messages = <Map<String, String>>[];

    // Add system message
    messages.add({
      'role': 'system',
      'content':
          '''You are PersonalMedAI, a warm and knowledgeable medical AI assistant.

Key traits:
- Friendly, empathetic, and supportive
- Provide clear, concise medical information
- Keep responses under 200 words
- Use simple medical terminology
- Always include appropriate disclaimers
- Show genuine care for user wellbeing

Guidelines:
- Recommend healthcare professionals for serious concerns
- Provide practical health advice
- Be encouraging and reassuring
- Use emojis sparingly (🩺 💊 ❤️ ⚠️)

Remember: Inform and support, don't replace professional medical consultation.'''
    });

    // Convert conversation history
    for (final message in conversationHistory) {
      messages.add({
        'role': message['isUser'] == 'true' ? 'user' : 'assistant',
        'content': message['text'] ?? '',
      });
    }

    return messages;
  }

  // Keep existing methods but optimize them
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

  // OPTIMIZED: Enhanced fallback responses
  String _getFallbackResponse(String userMessage) {
    final quickResponse = getQuickResponse(userMessage);
    if (quickResponse != null) return quickResponse;

    return '🩺 I\'m here to help with your health questions. Due to high demand, I\'m experiencing some delays. Please try again in a moment, or contact your healthcare provider for urgent concerns.';
  }

  Future<String> _safeApiCall(String prompt, String contextMessage,
      {bool isChat = false}) async {
    try {
      if (isChat) {
        return await _makeChatApiCall(prompt);
      } else {
        return await _makeApiCallWithRetry(prompt);
      }
    } on TimeoutException {
      print('⏳ $contextMessage: Request timed out - using fallback');
      if (isChat) {
        final messages = jsonDecode(prompt) as List<dynamic>;
        final lastUserMessage = messages.lastWhere(
              (m) => m['role'] == 'user',
              orElse: () => {'content': ''},
            )['content'] ??
            '';
        return _getFallbackResponse(lastUserMessage);
      }
      return 'The request took longer than expected. Please try again.';
    } catch (e) {
      print('⚠️ $contextMessage: $e');
      return 'I\'m experiencing technical difficulties. Please try again in a moment.';
    }
  }

  Future<String> _makeChatApiCall(String conversationHistoryJson) async {
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_apiKey',
      'Connection': 'keep-alive',
      'Accept': 'application/json',
    };

    final List<dynamic> messages = jsonDecode(conversationHistoryJson);

    if (messages.isEmpty || messages.first['role'] != 'system') {
      messages.insert(0, {
        'role': 'system',
        'content':
            'You are PersonalMedAI, a helpful medical AI. Keep responses concise (under 200 words) and include medical disclaimers.'
      });
    }

    final body = jsonEncode({
      'model': 'deepseek-chat',
      'messages': messages,
      'max_tokens': 250, // Reduced for speed
      'temperature': 0.4, // Reduced for consistency
      'top_p': 0.8,
    });

    final response = await http
        .post(Uri.parse('$_baseUrl/chat/completions'),
            headers: headers, body: body)
        .timeout(_timeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final choices = data['choices'];
      if (choices != null && choices.isNotEmpty) {
        String content =
            choices[0]['message']['content']?.trim() ?? 'No response received.';
        content = _removeWordCountAnnotations(content);
        return content;
      } else {
        throw Exception('Invalid response format from API');
      }
    } else {
      throw Exception('API request failed with status: ${response.statusCode}');
    }
  }

  String _buildChatPrompt(List<Map<String, dynamic>> conversationHistory) {
    final messages = conversationHistory
        .map((message) => {
              'role': message['isUser'] == 'true' ? 'user' : 'assistant',
              'content': message['text'] ?? '',
            })
        .toList();

    return jsonEncode(messages);
  }

  Future<String> _makeApiCallWithRetry(String prompt) async {
    int attempts = 0;
    const retryDelays = [300, 800]; // Reduced delays

    while (true) {
      try {
        return await _makeApiCall(prompt);
      } catch (e) {
        attempts++;
        if (attempts > _maxRetries) rethrow;

        final delayMs = retryDelays[attempts - 1];
        print(
            '🔄 Retrying API call... (Attempt $attempts/$_maxRetries) - waiting ${delayMs}ms');
        await Future.delayed(Duration(milliseconds: delayMs));
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
              'You are a medical AI assistant. Provide concise, informative responses. Keep under 200 words and include medical disclaimers.'
        },
        {'role': 'user', 'content': prompt}
      ],
      'max_tokens': 250,
      'temperature': 0.4,
    });

    final response = await http
        .post(Uri.parse('$_baseUrl/chat/completions'),
            headers: headers, body: body)
        .timeout(_timeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final choices = data['choices'];
      if (choices != null && choices.isNotEmpty) {
        String content =
            choices[0]['message']['content']?.trim() ?? 'No response received.';
        content = _removeWordCountAnnotations(content);
        return content;
      } else {
        throw Exception('Invalid response format');
      }
    } else {
      throw Exception('API request failed with status: ${response.statusCode}');
    }
  }

  String _removeWordCountAnnotations(String text) {
    return text
        .replaceAll(RegExp(r'\*?\(Word count: \d+\)\*?'), '')
        .replaceAll(RegExp(r'\*Word count: \d+\*'), '')
        .replaceAll(RegExp(r'\(Word count: \d+\)'), '')
        .replaceAll(RegExp(r'Word count: \d+'), '')
        .trim();
  }

  // Existing prompt methods with optimizations
  String _buildSymptomAnalysisPrompt(List<String> symptoms, String severity,
      Map<String, dynamic> additionalInfo) {
    final buffer = StringBuffer()
      ..writeln("Analyze these symptoms concisely:")
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

    buffer.writeln(
        "\nProvide: 1) Possible causes 2) When to see doctor 3) Self-care tips 4) Disclaimer. Keep under 200 words.");
    return buffer.toString();
  }

  String _buildMedicationInteractionPrompt(List<String> medications) {
    return "Analyze interactions between: ${medications.join(', ')}\n\nProvide: 1) Risk level 2) Key effects 3) When to consult doctor 4) Disclaimer. Keep under 150 words.";
  }

// Add this method to your DeepSeekService class
  Future<String> getHealthInsights(Map<String, dynamic> healthData) async {
    // If healthData is a string, treat it as a single chat message
    if (healthData is String) {
      final conversationHistory = [
        {'isUser': 'true', 'text': healthData}
      ];
      return sendChatMessage(conversationHistory);
    }

    // Check for quick insights first
    if (healthData.isEmpty) {
      return '''🌟 **Personalized Health Insights**

**General Wellness Tips:**
• Stay hydrated - aim for 8 glasses of water daily
• Get 7-9 hours of quality sleep
• Take regular breaks from screen time
• Practice deep breathing exercises

**Healthy Habits:**
• Walk for 30 minutes daily
• Eat colorful fruits and vegetables
• Maintain regular meal times
• Stay connected with loved ones

💡 **Tip:** Add your health data to get more personalized insights!

⚠️ *These are general wellness suggestions. Consult healthcare providers for personalized medical advice.*''';
    }

    // Generate insights from health data
    final prompt = _buildHealthInsightsPrompt(healthData);
    return _safeApiCall(prompt, 'Error getting health insights');
  }

// Also add this helper method if it's missing
  String _buildHealthInsightsPrompt(Map<String, dynamic> healthData) {
    final buffer = StringBuffer()..writeln("Analyze this health data:");

    healthData.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty) {
        buffer.writeln("- ${key.replaceAll('_', ' ')}: $value");
      }
    });

    buffer.writeln("""
Provide personalized health insights:
1. Key observations from the data
2. Improvement suggestions
3. Lifestyle recommendations
4. Encouragement and motivation

Keep response under 200 words and include medical disclaimer.
""");
    return buffer.toString();
  }

  bool get isConfigured => _apiKey.isNotEmpty;
  String get configurationStatus =>
      'API Key: ${_apiKey.isNotEmpty ? "✓ Configured" : "✗ Missing"}\nBase URL: $_baseUrl';
}
