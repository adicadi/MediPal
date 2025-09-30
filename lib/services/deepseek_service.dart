import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/app_state.dart';

class DeepSeekService {
  late final String _apiKey;
  late final String _baseUrl;

  // OPTIMIZED: Reduced timeout for faster failure detection
  static const Duration _timeout = Duration(seconds: 20);
  static const int _maxRetries = 2;
  static const Duration _connectTimeout = Duration(seconds: 3);

  // ENHANCED: Age-appropriate quick responses
  static const Map<String, Map<String, String>> _quickResponses = {
    'hello': {
      'minor':
          'Hi there! 🌟 I\'m here to help you learn about staying healthy! Remember to always ask a trusted adult if you have health questions!',
      'adult':
          'Hello! I\'m PersonalMedAI, your health assistant. How can I help you today? 😊',
    },
    'hi': {
      'minor':
          'Hi! 👋 I can teach you fun ways to stay healthy! Always talk to your parents or guardians about health stuff too!',
      'adult':
          'Hi there! I\'m here to help with any health questions you might have! 🩺',
    },
    'help': {
      'minor':
          'I can teach you about:\n• Healthy foods and exercise 🥕\n• Why sleep is important 😴\n• When to tell adults you don\'t feel well\n• Fun ways to stay strong! 💪\n\nBut always ask trusted adults about health questions!',
      'adult':
          'I can help you with:\n• Medical questions and symptoms\n• Medication information\n• Health guidance\n• Emergency information\n\nWhat would you like to know?',
    },
    'emergency': {
      'minor':
          '🚨 **If there\'s an emergency:**\n\n1. Find a trusted adult RIGHT AWAY\n2. Call 911 if no adult is around\n3. Stay calm and ask for help\n\nAlways tell adults when you don\'t feel well!',
      'adult':
          '🚨 **MEDICAL EMERGENCY?**\n\nCall 911 immediately if experiencing:\n• Difficulty breathing\n• Chest pain\n• Severe bleeding\n• Loss of consciousness',
    },
    'thanks': {
      'minor':
          'You\'re welcome! 🌟 Keep learning about staying healthy, and remember to always talk to trusted adults about health questions!',
      'adult':
          'You\'re welcome! I\'m always here to help with your health questions. Take care! 😊',
    },
    'thank you': {
      'minor':
          'You\'re so welcome! 🌟 Keep asking great questions and always talk to trusted adults about your health!',
      'adult':
          'You\'re very welcome! Feel free to ask if you have more questions. Stay healthy! 💙',
    },
  };

  // NEW: Adult content keywords for filtering
  static const List<String> _adultContentKeywords = [
    'sex',
    'sexual',
    'pregnancy',
    'contraception',
    'std',
    'sti',
    'reproductive',
    'genital',
    'abortion',
    'breast',
    'period',
    'menstruation',
    'testosterone',
    'viagra',
    'drug abuse',
    'alcohol',
    'addiction',
    'overdose',
    'suicide',
    'self-harm',
    'depression',
    'anxiety disorder'
  ];

  DeepSeekService() {
    _apiKey = dotenv.env['DEEPSEEK_API_KEY'] ?? '';
    _baseUrl = dotenv.env['DEEPSEEK_BASE_URL'] ?? 'https://api.deepseek.com/v1';

    print("🔑 API Key Loaded: ${_apiKey.isNotEmpty ? "Yes" : "No"}");
    print("🌍 Base URL: $_baseUrl");

    if (_apiKey.isEmpty) {
      throw Exception('❌ DeepSeek API key not found in environment variables');
    }
  }

  // ENHANCED: Age-appropriate quick responses with AppState
  String? getQuickResponse(String message, AppState appState) {
    final normalizedMessage = message.toLowerCase().trim();

    // Check for adult content if user is a minor
    if (appState.isMinor && _containsAdultContent(normalizedMessage)) {
      return _getMinorRedirectResponse(appState.userName);
    }

    // Direct matches with age-appropriate responses
    if (_quickResponses.containsKey(normalizedMessage)) {
      final responses = _quickResponses[normalizedMessage]!;
      return appState.isMinor ? responses['minor'] : responses['adult'];
    }

    // Age-appropriate pattern matches
    return _getPatternBasedResponse(normalizedMessage, appState);
  }

  // NEW: Check for adult content
  bool _containsAdultContent(String message) {
    final lowerMessage = message.toLowerCase();
    return _adultContentKeywords
        .any((keyword) => lowerMessage.contains(keyword));
  }

  // NEW: Minor redirect response
  String _getMinorRedirectResponse(String userName) {
    return '''
Hi ${userName.isNotEmpty ? userName : 'there'}! 🌟

I notice you're asking about something that might be better discussed with a trusted adult like a parent, guardian, or doctor.

**What you can do:**
- Talk to a parent or guardian about your question  
- Ask a school nurse or counselor
- Visit a doctor with a trusted adult

Remember: I'm here to help with general health information, but for anything serious or personal, it's always best to talk to a real person who can help you properly! 😊

Is there something else I can help you with today?
    ''';
  }

  // ENHANCED: Pattern-based responses with age consideration
  String? _getPatternBasedResponse(String message, AppState appState) {
    if (message.contains('headache')) {
      return appState.isMinor
          ? '🤕 **If your head hurts:**\n• Tell a trusted adult right away\n• Rest in a quiet place\n• Drink some water\n• Ask an adult about what to do\n\n⚠️ Always let adults help you when you don\'t feel well!'
          : '🩺 **Headache Relief:**\n• Stay hydrated (drink water)\n• Rest in a quiet, dark room\n• Apply cold/warm compress\n• Consider OTC pain relief\n\n⚠️ See a doctor if severe or persistent.';
    }

    if (message.contains('fever')) {
      return appState.isMinor
          ? '🌡️ **If you feel hot and sick:**\n• Tell an adult immediately\n• Rest and drink water\n• Let adults check your temperature\n• Ask for help from grown-ups\n\n⚠️ Adults know what to do when you have a fever!'
          : '🌡️ **Fever Management:**\n• Stay hydrated\n• Rest and monitor temperature\n• Light clothing\n• Seek medical attention if >101.5°F (38.6°C)\n\n⚠️ Contact healthcare provider if persistent.';
    }

    if (message.contains('medication') && message.contains('safe')) {
      return appState.isMinor
          ? '💊 **About Medicines:**\n• Only adults should give you medicine\n• Never take medicine by yourself\n• Always ask trusted adults first\n• Tell adults about any medicine questions\n\n⚠️ Medicine safety is super important - let adults handle it!'
          : '💊 **Medication Safety:**\n• Always follow prescribed dosage\n• Check for drug interactions\n• Store properly\n• Don\'t share medications\n\n⚠️ Consult your pharmacist or doctor with questions.';
    }

    return null; // No quick response available
  }

  // ENHANCED: Age-appropriate system prompts
  String _getAgeAppropriateSystemPrompt(AppState appState) {
    final basePrompt = '''
You are PersonalMedAI, a helpful medical information assistant.
User Profile: ${appState.userName}, Age: ${appState.userAge}, Gender: ${appState.userGender}
''';

    if (appState.isMinor) {
      return '''
$basePrompt

CRITICAL AGE RESTRICTIONS FOR MINOR (Under 18):
- Use simple, age-appropriate language (elementary/middle school level)
- Always emphasize talking to parents/guardians/trusted adults
- Avoid detailed medical terminology - use simple words
- Focus on general wellness, safety, and healthy habits
- Never suggest self-medication or self-treatment
- Always recommend adult supervision for any health concerns
- Use encouraging, non-scary language
- Include fun, engaging explanations when appropriate
- Redirect sensitive topics to trusted adults
- Keep responses short and easy to understand

FORBIDDEN TOPICS: reproductive health, mental health disorders, adult medications, self-diagnosis

RESPONSE STYLE: Friendly, educational, and always directing to trusted adults for real medical decisions.
ALWAYS end responses with reminders to talk to trusted adults.
      ''';
    } else if (appState.isYoungAdult) {
      return '''
$basePrompt

AGE-APPROPRIATE GUIDANCE FOR YOUNG ADULT (18-24):
- Use clear, educational language
- Focus on preventive care and healthy lifestyle
- Emphasize the importance of establishing healthcare relationships
- Provide comprehensive information while stressing professional consultation
- Address common concerns for this age group (mental health, lifestyle, etc.)
- Encourage taking responsibility for health decisions
- Provide practical advice for independent living

RESPONSE LENGTH: Up to 400 words
TONE: Supportive and empowering while maintaining medical disclaimers
      ''';
    } else {
      return '''
$basePrompt

COMPREHENSIVE MEDICAL INFORMATION FOR ADULT (25+):
- Provide detailed, medical-grade information
- Use appropriate medical terminology with explanations
- Discuss complex health topics as appropriate
- Address age-specific health concerns
- Provide thorough analysis while maintaining professional disclaimers
- Include detailed self-care instructions where appropriate

RESPONSE LENGTH: Up to 600 words
TONE: Professional and comprehensive while remaining accessible
      ''';
    }
  }

  // ENHANCED: Streaming with age restrictions and AppState
  Stream<String> streamChatResponse(
      List<Map<String, String>> conversationHistory, AppState appState) async* {
    // Check for quick response first
    if (conversationHistory.isNotEmpty) {
      final lastMessage = conversationHistory.last;
      if (lastMessage['isUser'] == 'true') {
        final quickResponse =
            getQuickResponse(lastMessage['text'] ?? '', appState);
        if (quickResponse != null) {
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

    final messages = _buildMessageHistory(conversationHistory, appState);

    final body = jsonEncode({
      'model': 'deepseek-chat',
      'messages': messages,
      'max_tokens': appState.maxAIResponseLength,
      'temperature': appState.isMinor ? 0.3 : 0.4, // More consistent for minors
      'stream': true,
      'top_p': 0.8,
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

              // Filter content for minors
              if (appState.isMinor && _containsAdultContent(accumulatedText)) {
                yield _getMinorRedirectResponse(appState.userName);
                break;
              }

              yield accumulatedText;
            }
          } catch (e) {
            continue;
          }
        }
      }

      client.close();

      // Add age-appropriate disclaimer
      if (accumulatedText.isNotEmpty &&
          !accumulatedText.contains(appState.ageAppropriateDisclaimer)) {
        final finalResponse =
            accumulatedText + '\n\n${appState.ageAppropriateDisclaimer}';
        yield finalResponse;
      }
    } catch (e) {
      print('Streaming error: $e');
      try {
        final response = await sendChatMessage(conversationHistory, appState);
        yield response;
      } catch (fallbackError) {
        yield appState.getAgeAppropriateErrorMessage();
      }
    }
  }

  // ENHANCED: Chat with age restrictions and AppState
  Future<String> sendChatMessage(
      List<Map<String, dynamic>> conversationHistory, AppState appState) async {
    // Check for quick response first
    if (conversationHistory.isNotEmpty) {
      final lastMessage = conversationHistory.last;
      if (lastMessage['isUser'] == 'true') {
        final quickResponse =
            getQuickResponse(lastMessage['text'] ?? '', appState);
        if (quickResponse != null) {
          await Future.delayed(const Duration(milliseconds: 500));
          return quickResponse;
        }
      }
    }

    final prompt = _buildChatPrompt(conversationHistory, appState);
    final result = await _safeApiCall(prompt, 'Error in chat conversation',
        isChat: true, appState: appState);

    // Add age-appropriate disclaimer if not already present
    if (!result.contains(appState.ageAppropriateDisclaimer)) {
      return result + '\n\n${appState.ageAppropriateDisclaimer}';
    }
    return result;
  }

  // Helper method to build message history for streaming with age restrictions
  List<Map<String, String>> _buildMessageHistory(
      List<Map<String, String>> conversationHistory, AppState appState) {
    final messages = <Map<String, String>>[];

    // Add age-appropriate system message
    messages.add({
      'role': 'system',
      'content': _getAgeAppropriateSystemPrompt(appState),
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

  // ENHANCED: Symptom analysis with age restrictions
  Future<String> analyzeSymptoms(List<String> symptoms, String severity,
      Map<String, dynamic> additionalInfo, AppState appState) async {
    // Check for adult content in symptoms for minors
    if (appState.isMinor) {
      final symptomsText = symptoms.join(' ').toLowerCase();
      if (_containsAdultContent(symptomsText)) {
        return _getMinorRedirectResponse(appState.userName);
      }
    }

    final prompt = _buildSymptomAnalysisPrompt(
        symptoms, severity, additionalInfo, appState);
    final result = await _safeApiCall(prompt, 'Error analyzing symptoms',
        appState: appState);

    // Add age-appropriate disclaimer
    if (!result.contains(appState.ageAppropriateDisclaimer)) {
      return result + '\n\n${appState.ageAppropriateDisclaimer}';
    }
    return result;
  }

  // ENHANCED: Medication interactions with age restrictions
  Future<String> checkMedicationInteractions(
      List<String> medications, AppState appState) async {
    if (appState.isMinor) {
      return '''
Hi ${appState.userName}! 🌟

Medicine questions are really important! Here's what you should do:

**For Medicine Safety:**
- Always ask a trusted adult before taking any medicine
- Never take medicine by yourself
- Tell adults about all medicines you take
- Ask parents or guardians about medicine questions

**Important:** Only doctors, parents, or guardians should decide about your medicines!

Remember: Adults are there to keep you safe and healthy! 💙

${appState.ageAppropriateDisclaimer}
      ''';
    }

    final prompt = _buildMedicationInteractionPrompt(medications, appState);
    final result = await _safeApiCall(
        prompt, 'Error checking medication interactions',
        appState: appState);

    // Add age-appropriate disclaimer
    if (!result.contains(appState.ageAppropriateDisclaimer)) {
      return result + '\n\n${appState.ageAppropriateDisclaimer}';
    }
    return result;
  }

  // ENHANCED: Health insights with comprehensive data analysis
  Future<String> getHealthInsights(
      Map<String, dynamic> healthData, AppState appState) async {
    // If healthData is a string, treat it as a single chat message
    if (healthData is String) {
      final conversationHistory = [
        {'isUser': 'true', 'text': healthData}
      ];
      return sendChatMessage(conversationHistory, appState);
    }

    // Check for quick insights first
    if (healthData.isEmpty) {
      return _getDefaultHealthInsights(appState);
    }

    final prompt = _buildHealthInsightsPrompt(healthData, appState);
    final result = await _safeApiCall(prompt, 'Error getting health insights',
        appState: appState);

    // Add age-appropriate disclaimer
    if (!result.contains(appState.ageAppropriateDisclaimer)) {
      return result + '\n\n${appState.ageAppropriateDisclaimer}';
    }
    return result;
  }

  // NEW: Default health insights based on age
  String _getDefaultHealthInsights(AppState appState) {
    if (appState.isMinor) {
      return '''
🌟 **Health Tips Just for You, ${appState.userName}!**

**Stay Strong and Healthy:**
🏃‍♀️ Play and be active every day - it's fun and makes you strong!
😴 Get lots of sleep (9-11 hours) to help your body grow
🥕 Eat colorful foods like fruits and vegetables
💧 Drink water to keep your body happy
🧠 Always tell trusted adults when you don't feel well

**Remember:**
- Your parents and guardians are there to help you stay healthy
- Ask questions! Adults love to help you learn
- You're doing great by learning about health! 

${appState.ageAppropriateDisclaimer}
      ''';
    } else {
      return '''
🌟 **Personalized Health Insights for ${appState.userName}**

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

${appState.ageAppropriateDisclaimer}
      ''';
    }
  }

  // ENHANCED: Fallback response with age consideration
  String _getFallbackResponse(String userMessage, AppState appState) {
    final quickResponse = getQuickResponse(userMessage, appState);
    if (quickResponse != null) return quickResponse;

    return appState.getAgeAppropriateErrorMessage();
  }

  Future<String> _safeApiCall(String prompt, String contextMessage,
      {bool isChat = false, AppState? appState}) async {
    try {
      if (isChat) {
        return await _makeChatApiCall(prompt, appState);
      } else {
        return await _makeApiCallWithRetry(prompt, appState);
      }
    } on TimeoutException {
      print('⏳ $contextMessage: Request timed out - using fallback');
      if (isChat && appState != null) {
        final messages = jsonDecode(prompt) as List<dynamic>;
        final lastUserMessage = messages.lastWhere(
              (m) => m['role'] == 'user',
              orElse: () => {'content': ''},
            )['content'] ??
            '';
        return _getFallbackResponse(lastUserMessage, appState);
      }
      return appState?.getAgeAppropriateErrorMessage() ??
          'The request took longer than expected. Please try again.';
    } catch (e) {
      print('⚠️ $contextMessage: $e');
      return appState?.getAgeAppropriateErrorMessage() ??
          'I\'m experiencing technical difficulties. Please try again in a moment.';
    }
  }

  Future<String> _makeChatApiCall(
      String conversationHistoryJson, AppState? appState) async {
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
        'content': appState != null
            ? _getAgeAppropriateSystemPrompt(appState)
            : 'You are PersonalMedAI, a helpful medical AI. Keep responses concise and include medical disclaimers.'
      });
    }

    final body = jsonEncode({
      'model': 'deepseek-chat',
      'messages': messages,
      'max_tokens': appState?.maxAIResponseLength ?? 250,
      'temperature': appState?.isMinor == true ? 0.3 : 0.4,
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

        // Filter content for minors
        if (appState?.isMinor == true && _containsAdultContent(content)) {
          return _getMinorRedirectResponse(appState!.userName);
        }

        return content;
      } else {
        throw Exception('Invalid response format from API');
      }
    } else {
      throw Exception('API request failed with status: ${response.statusCode}');
    }
  }

  String _buildChatPrompt(
      List<Map<String, dynamic>> conversationHistory, AppState appState) {
    final messages = conversationHistory
        .map((message) => {
              'role': message['isUser'] == 'true' ? 'user' : 'assistant',
              'content': message['text'] ?? '',
            })
        .toList();

    return jsonEncode(messages);
  }

  Future<String> _makeApiCallWithRetry(
      String prompt, AppState? appState) async {
    int attempts = 0;
    const retryDelays = [300, 800];

    while (true) {
      try {
        return await _makeApiCall(prompt, appState);
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

  Future<String> _makeApiCall(String prompt, AppState? appState) async {
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_apiKey',
    };

    final body = jsonEncode({
      'model': 'deepseek-chat',
      'messages': [
        {
          'role': 'system',
          'content': appState != null
              ? _getAgeAppropriateSystemPrompt(appState)
              : 'You are a medical AI assistant. Provide concise, informative responses. Include medical disclaimers.'
        },
        {'role': 'user', 'content': prompt}
      ],
      'max_tokens': appState?.maxAIResponseLength ?? 250,
      'temperature': appState?.isMinor == true ? 0.3 : 0.4,
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

        // Filter content for minors
        if (appState?.isMinor == true && _containsAdultContent(content)) {
          return _getMinorRedirectResponse(appState!.userName);
        }

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

  // ENHANCED: Age-appropriate symptom analysis prompt
  String _buildSymptomAnalysisPrompt(List<String> symptoms, String severity,
      Map<String, dynamic> additionalInfo, AppState appState) {
    final buffer = StringBuffer();

    if (appState.isMinor) {
      buffer.writeln(
          "Help a young person (age ${appState.userAge}) understand these symptoms:");
      buffer.writeln("Symptoms: ${symptoms.join(', ')}");
      buffer.writeln("How bad it feels: $severity");
      buffer.writeln(
          "\nProvide: 1) Simple explanation 2) When to tell adults 3) What adults can do to help");
      buffer.writeln(
          "Use simple words and always direct to trusted adults for help.");
    } else {
      buffer.writeln(
          "Analyze these symptoms for ${appState.userAge}-year-old ${appState.userGender.toLowerCase()}:");
      buffer.writeln("Symptoms: ${symptoms.join(', ')}");
      buffer.writeln("Severity: $severity");

      if (additionalInfo.isNotEmpty) {
        buffer.writeln("Additional info:");
        additionalInfo.forEach((key, value) {
          if (value.toString().isNotEmpty) {
            buffer.writeln("- ${key.replaceAll('_', ' ')}: $value");
          }
        });
      }

      buffer.writeln(
          "\nProvide: 1) Possible causes 2) When to see doctor 3) Self-care tips 4) Disclaimer. Keep under ${appState.maxAIResponseLength} words.");
    }

    return buffer.toString();
  }

  // ENHANCED: Age-appropriate medication interaction prompt
  String _buildMedicationInteractionPrompt(
      List<String> medications, AppState appState) {
    if (appState.isMinor) {
      return "A young person is asking about medicine safety. Redirect them to trusted adults and explain why medicine safety is important for young people.";
    }

    return "Analyze interactions between: ${medications.join(', ')}\n\nFor ${appState.userAge}-year-old ${appState.userGender.toLowerCase()}. Provide: 1) Risk level 2) Key effects 3) When to consult doctor 4) Disclaimer. Keep under ${appState.maxAIResponseLength} words.";
  }

  // ENHANCED: Age-appropriate health insights prompt with comprehensive data analysis
  String _buildHealthInsightsPrompt(
      Map<String, dynamic> healthData, AppState appState) {
    final buffer = StringBuffer();

    if (appState.isMinor) {
      buffer.writeln(
          "Create fun, educational health tips for a ${appState.userAge}-year-old named ${appState.userName}:");
      buffer.writeln(
          "Focus on: healthy habits, exercise, sleep, eating well, when to tell adults about health");
      buffer.writeln(
          "Use simple, encouraging language and always mention talking to trusted adults.");
    } else {
      buffer.writeln(
          "Analyze this comprehensive health data for ${appState.userName} (age ${appState.userAge}, ${appState.userGender}):");

      // Process the health data systematically
      final processedData = <String, dynamic>{};
      healthData.forEach((key, value) {
        if (value != null &&
            value.toString().isNotEmpty &&
            value.toString() != 'null') {
          processedData[key] = value;
        }
      });

      // Group data by categories for better analysis
      final categories = {
        'Demographics': ['user_name', 'user_age', 'user_gender', 'age_group'],
        'Medications': [
          'medications_count',
          'medications',
          'medication_details'
        ],
        'Health Metrics': [
          'health_score',
          'sleep_hours',
          'recommended_steps',
          'activity_level'
        ],
        'Symptoms & History': [
          'last_symptom_check',
          'recent_symptoms',
          'symptom_severity'
        ],
        'Engagement': ['chat_activity', 'app_usage_days', 'most_asked_topics'],
      };

      categories.forEach((category, keys) {
        final categoryData = <String, dynamic>{};
        for (final key in keys) {
          if (processedData.containsKey(key)) {
            categoryData[key] = processedData[key];
          }
        }

        if (categoryData.isNotEmpty) {
          buffer.writeln("\n**${category}:**");
          categoryData.forEach((key, value) {
            buffer.writeln("- ${key.replaceAll('_', ' ')}: $value");
          });
        }
      });

      buffer.writeln("""

Provide comprehensive personalized health insights:
1. Profile-based health assessment
2. Medication analysis (if applicable)
3. Lifestyle recommendations based on age/gender
4. Specific improvement suggestions
5. Motivational encouragement
6. Risk factors to monitor

Keep response under ${appState.maxAIResponseLength} words and include medical disclaimer.
""");
    }

    return buffer.toString();
  }

  bool get isConfigured => _apiKey.isNotEmpty;
  String get configurationStatus =>
      'API Key: ${_apiKey.isNotEmpty ? "✓ Configured" : "✗ Missing"}\nBase URL: $_baseUrl';
}
