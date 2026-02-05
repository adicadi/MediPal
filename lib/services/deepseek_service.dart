import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/app_state.dart';

class DeepSeekService {
  late final String _apiKey;
  late final String _baseUrl;

  // RESTORED: Working timeout values from old version
  static const Duration _timeout = Duration(seconds: 30); // INCREASED from 20
  static const int _maxRetries = 2;
// INCREASED from 3

  // RESTORED: Working retry delays with exponential backoff
  static const List<int> _retryDelays = [500, 1500]; // INCREASED from 300, 800

  // ENHANCED: Age-appropriate quick responses
  static const Map<String, Map<String, String>> _quickResponses = {
    'hello': {
      'minor':
          'Hi there! 🌟 I\'m here to help you learn about staying healthy! Remember to always ask a trusted adult if you have health questions!',
      'adult':
          'Hello! I\'m MediPal, your health assistant. How can I help you today? 😊',
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

    if (kDebugMode) {
      print("🔑 API Key Loaded: ${_apiKey.isNotEmpty ? "Yes" : "No"}");
    }
    if (kDebugMode) {
      print("🌍 Base URL: $_baseUrl");
    }

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

  // OPTIMIZED: Dramatically simplified system prompts
  String _getAgeAppropriateSystemPrompt(AppState appState) {
    final basePrompt = '''
You are MediPal for ${appState.userName}, Age: ${appState.userAge}, Gender: ${appState.userGender}
''';
    final wearablePrompt = appState.wearableSummaryPrompt;
    final wearableLine = wearablePrompt.isNotEmpty ? '\n$wearablePrompt\n' : '';
    final documentLine = appState.chatDocumentContext.isNotEmpty
        ? '\nHealth document context (on-device, user-provided):\n${appState.chatDocumentContext}\nUse only if relevant, and do not request non-health documents.\n'
        : '';

    if (appState.isMinor) {
      return '''
$basePrompt
MINOR (Under 18): Use simple language. Always direct to trusted adults. Focus on wellness and safety. 
Avoid: self-medication, detailed medical terms, sensitive topics. Keep under 250 words. End with reminder to talk to adults.
Only answer health-related questions. If asked about non-health topics (e.g., programming, tech, homework), politely refuse and redirect to health.
$wearableLine$documentLine
      ''';
    } else if (appState.isYoungAdult) {
      return '''
$basePrompt
YOUNG ADULT (18-24): Clear educational language. Emphasize preventive care and professional consultation.
Keep under 350 words with disclaimers.
Only answer health-related questions. If asked about non-health topics (e.g., programming, tech, homework), politely refuse and redirect to health.
$wearableLine$documentLine
      ''';
    } else {
      return '''
$basePrompt
ADULT (25+): Detailed medical-grade information with appropriate terminology. 
Thorough analysis with disclaimers. Keep under 500 words.
Only answer health-related questions. If asked about non-health topics (e.g., programming, tech, homework), politely refuse and redirect to health.
$wearableLine$documentLine
      ''';
    }
  }

  bool _isHealthRelated(String message) {
    final text = message.toLowerCase();
    const healthKeywords = [
      'health',
      'symptom',
      'symptoms',
      'pain',
      'ache',
      'fever',
      'cough',
      'cold',
      'flu',
      'allergy',
      'asthma',
      'blood',
      'pressure',
      'heart',
      'pulse',
      'sleep',
      'insomnia',
      'stress',
      'anxiety',
      'depression',
      'mental',
      'wellness',
      'diet',
      'nutrition',
      'calorie',
      'exercise',
      'workout',
      'steps',
      'medicine',
      'medication',
      'drug',
      'dosage',
      'side effect',
      'doctor',
      'hospital',
      'clinic',
      'injury',
      'wound',
      'infection',
      'virus',
      'bacteria',
      'headache',
      'migraine',
      'nausea',
      'vomit',
      'diarrhea',
      'constipation',
      'period',
      'pregnancy',
      'sex',
      'sexual',
      'skin',
      'rash',
      'itch',
      'temperature',
      'vaccin',
      'immun',
      'therapy',
      'diagnos',
      'treatment',
      'surgery',
      'cholesterol',
      'glucose',
      'diabetes',
      'otc',
      'relief',
    ];

    for (final keyword in healthKeywords) {
      if (text.contains(keyword)) {
        return true;
      }
    }
    return false;
  }

  bool _isHealthFollowUp(List<Map<String, String>> history, String lastText) {
    if (history.length < 2) return false;
    final prev = history[history.length - 2];
    if (prev['isUser'] == 'true') return false;
    final prevText = (prev['text'] ?? '').toLowerCase();
    if (prevText.isEmpty) return false;
    if (_isHealthRelated(prevText)) return true;
    final wordCount = lastText.trim().split(RegExp(r'\\s+')).length;
    return wordCount <= 4;
  }

  // ENHANCED: Streaming with age restrictions and AppState
  Stream<String> streamChatResponse(
      List<Map<String, String>> conversationHistory, AppState appState) async* {
    // Check for quick response first
    if (conversationHistory.isNotEmpty) {
      final lastMessage = conversationHistory.last;
      if (lastMessage['isUser'] == 'true') {
        final lastText = lastMessage['text'] ?? '';
        if (lastText.trim().isNotEmpty &&
            !_isHealthRelated(lastText) &&
            !_isHealthFollowUp(conversationHistory, lastText)) {
          yield appState.isMinor
              ? 'I can only help with health questions. Please ask about your health, symptoms, medicines, or wellness, and I’ll do my best to help.'
              : 'I’m a health-only assistant, so I can’t help with that topic. Ask me about symptoms, medications, wellness, or other health questions.';
          return;
        }
        final quickResponse =
            getQuickResponse(lastText, appState);
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
      'max_tokens': appState.isMinor ? 200 : 400, // OPTIMIZED
      'temperature': 0.4, // SIMPLIFIED: Single value
      'stream': true,
      'top_p': 0.8,
    });

    http.Client? client;
    try {
      final request =
          http.Request('POST', Uri.parse('$_baseUrl/chat/completions'))
            ..headers.addAll(headers)
            ..body = body;

      client = http.Client();
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

      // Add age-appropriate disclaimer
      if (accumulatedText.isNotEmpty &&
          !accumulatedText.contains(appState.ageAppropriateDisclaimer)) {
        final finalResponse =
            '$accumulatedText\n\n${appState.ageAppropriateDisclaimer}';
        yield finalResponse;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Streaming error: $e');
      }
      try {
        final response = await sendChatMessage(conversationHistory, appState);
        yield response;
      } catch (fallbackError) {
        yield appState.getAgeAppropriateErrorMessage();
      }
    } finally {
      client?.close();
    }
  }

  // ENHANCED: Chat with age restrictions and AppState
  Future<String> sendChatMessage(
      List<Map<String, dynamic>> conversationHistory, AppState appState) async {
    // Check for quick response first
    if (conversationHistory.isNotEmpty) {
      final lastMessage = conversationHistory.last;
      if (lastMessage['isUser'] == 'true') {
        final lastText = lastMessage['text'] ?? '';
        if (lastText.trim().isNotEmpty &&
            !_isHealthRelated(lastText) &&
            !_isHealthFollowUp(
                conversationHistory.cast<Map<String, String>>(), lastText)) {
          return appState.isMinor
              ? 'I can only help with health questions. Please ask about your health, symptoms, medicines, or wellness, and I’ll do my best to help.'
              : 'I’m a health-only assistant, so I can’t help with that topic. Ask me about symptoms, medications, wellness, or other health questions.';
        }
        final quickResponse =
            getQuickResponse(lastText, appState);
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
      return '$result\n\n${appState.ageAppropriateDisclaimer}';
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
      return '$result\n\n${appState.ageAppropriateDisclaimer}';
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
      return '$result\n\n${appState.ageAppropriateDisclaimer}';
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
      return '$result\n\n${appState.ageAppropriateDisclaimer}';
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
      if (kDebugMode) {
        print(
            '⏳ $contextMessage: Request timed out after ${_timeout.inSeconds}s');
      }
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
    } on SocketException catch (e) {
      if (kDebugMode) {
        print('🌐 Network error: ${e.message}');
      }
      return appState?.getAgeAppropriateErrorMessage() ??
          'Network connection issue. Please check your internet and try again.';
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ $contextMessage: $e');
      }
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
            : 'You are MediPal, a helpful medical AI. Keep responses concise and include medical disclaimers.'
      });
    }

    final body = jsonEncode({
      'model': 'deepseek-chat',
      'messages': messages,
      'max_tokens': appState?.isMinor == true ? 200 : 400, // OPTIMIZED
      'temperature': 0.4, // SIMPLIFIED
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
    } else if (response.statusCode == 429) {
      throw Exception('Rate limit exceeded - DeepSeek API is under heavy load');
    } else if (response.statusCode >= 500) {
      throw Exception('DeepSeek API server error: ${response.statusCode}');
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

  // RESTORED: Working retry logic with exponential backoff
  Future<String> _makeApiCallWithRetry(
      String prompt, AppState? appState) async {
    int attempts = 0;

    while (true) {
      try {
        if (kDebugMode) {
          print('🔄 API attempt ${attempts + 1}/${_maxRetries + 1}');
        }
        return await _makeApiCall(prompt, appState);
      } on TimeoutException {
        attempts++;
        if (attempts > _maxRetries) {
          if (kDebugMode) {
            print('⏳ Max retries reached after $attempts attempts');
          }
          rethrow;
        }

        // Use working retry delays with jitter
        final delayMs = _retryDelays[attempts - 1];
        final jitter =
            (delayMs * 0.1 * (DateTime.now().millisecond % 100) / 100).round();
        final finalDelay = delayMs + jitter;

        if (kDebugMode) {
          print(
              '🔄 Retrying API call... (Attempt $attempts/$_maxRetries) - waiting ${finalDelay}ms');
        }
        await Future.delayed(Duration(milliseconds: finalDelay));
      } on SocketException catch (e) {
        attempts++;
        if (attempts > _maxRetries) {
          if (kDebugMode) {
            print('🌐 Network error after $attempts attempts: ${e.message}');
          }
          rethrow;
        }

        final delayMs = _retryDelays[attempts - 1];
        if (kDebugMode) {
          print('🌐 Network issue, retrying in ${delayMs}ms...');
        }
        await Future.delayed(Duration(milliseconds: delayMs));
      } catch (e) {
        if (kDebugMode) {
          print('❌ Non-retryable error: $e');
        }
        rethrow;
      }
    }
  }

  Future<String> _makeApiCall(String prompt, AppState? appState) async {
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_apiKey',
      'Connection': 'keep-alive', // Important for long requests
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
      'max_tokens': appState?.isMinor == true ? 200 : 400, // OPTIMIZED
      'temperature': 0.4, // SIMPLIFIED
    });

    final response = await http
        .post(Uri.parse('$_baseUrl/chat/completions'),
            headers: headers, body: body)
        .timeout(
      _timeout,
      onTimeout: () {
        throw TimeoutException(
          'Request to DeepSeek API exceeded ${_timeout.inSeconds}s timeout',
          _timeout,
        );
      },
    );

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
        throw Exception('Invalid response format from DeepSeek API');
      }
    } else if (response.statusCode == 429) {
      throw Exception('Rate limit exceeded - DeepSeek API is under heavy load');
    } else if (response.statusCode >= 500) {
      throw Exception('DeepSeek API server error: ${response.statusCode}');
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

  // OPTIMIZED: Dramatically simplified symptom analysis prompt
  String _buildSymptomAnalysisPrompt(List<String> symptoms, String severity,
      Map<String, dynamic> additionalInfo, AppState appState) {
    final buffer = StringBuffer();

    if (appState.isMinor) {
      buffer.writeln("Help young person (age ${appState.userAge}):");
      buffer.writeln("Symptoms: ${symptoms.join(', ')}, Severity: $severity");
      buffer.writeln(
          "Provide: Simple explanation, when to tell adults. Keep brief under 200 words.");
    } else {
      buffer
          .writeln("Analyze for ${appState.userAge}yo ${appState.userGender}:");
      buffer.writeln("Symptoms: ${symptoms.join(', ')}, Severity: $severity");

      // Only include top 3 additional info items to keep prompt short
      if (additionalInfo.isNotEmpty) {
        int count = 0;
        buffer.writeln("Info:");
        for (var entry in additionalInfo.entries) {
          if (entry.value.toString().isNotEmpty && count < 3) {
            buffer.writeln("- ${entry.key}: ${entry.value}");
            count++;
          }
        }
      }

      buffer.writeln(
          "\nProvide: Causes, when to see doctor, self-care, disclaimer. Under 300 words.");
    }

    return buffer.toString();
  }

  // OPTIMIZED: Simplified medication interaction prompt
  String _buildMedicationInteractionPrompt(
      List<String> medications, AppState appState) {
    if (appState.isMinor) {
      return "Minor asking about medicines. Redirect to trusted adults briefly.";
    }

    return """
Analyze interactions: ${medications.join(', ')}
For ${appState.userAge}yo ${appState.userGender}. 
Provide: 1) Risk level 2) Key effects 3) When to consult doctor 4) Disclaimer
Keep under 250 words.
""";
  }

  // OPTIMIZED: Dramatically simplified health insights prompt
  String _buildHealthInsightsPrompt(
      Map<String, dynamic> healthData, AppState appState) {
    if (appState.isMinor) {
      return """
Create health tips for ${appState.userName} (${appState.userAge}yo):
Focus on: healthy habits, exercise, sleep, nutrition.
Use simple, encouraging language. Mention trusted adults. Keep under 200 words.
""";
    }

    // Extract only top 5 most relevant health data items
    final relevantData = <String, dynamic>{};
    final priorityKeys = [
      'medications_count',
      'health_score',
      'sleep_hours',
      'recent_symptoms',
      'activity_level'
    ];

    for (final key in priorityKeys) {
      if (healthData.containsKey(key) &&
          healthData[key] != null &&
          healthData[key].toString().isNotEmpty) {
        relevantData[key] = healthData[key];
      }
      if (relevantData.length >= 5) break;
    }

    final buffer = StringBuffer();
    buffer.writeln(
        "Health insights for ${appState.userName} (${appState.userAge}yo, ${appState.userGender}):");

    if (relevantData.isNotEmpty) {
      relevantData.forEach((key, value) {
        buffer.writeln("- $key: $value");
      });
    }

    buffer.writeln(
        "\nProvide: Assessment, lifestyle tips, improvements, encouragement. Under 350 words with disclaimer.");
    return buffer.toString();
  }

  bool get isConfigured => _apiKey.isNotEmpty;
  String get configurationStatus =>
      'API Key: ${_apiKey.isNotEmpty ? "✓ Configured" : "✗ Missing"}\nBase URL: $_baseUrl\nTimeout: ${_timeout.inSeconds}s';
}
