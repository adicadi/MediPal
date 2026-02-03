import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../screens/chat_screen.dart';

class ChatHistoryService {
  static const String _chatSessionsKey = 'chat_sessions';
  static const int _maxTitleLength = 40;
  static const int _maxTitleWords = 6;

  static String generateSessionName(List<ChatMessage> messages) {
    final userMessage = messages.firstWhere(
      (message) => message.isUser && message.text.trim().isNotEmpty,
      orElse: () => ChatMessage(text: '', isUser: true),
    );

    final raw = userMessage.text
        .replaceAll(RegExp(r'\\s+'), ' ')
        .replaceAll('\n', ' ')
        .trim();

    if (raw.isEmpty) {
      return 'Chat ${DateTime.now().month}/${DateTime.now().day}';
    }

    final words = raw.split(' ');
    final truncatedWords =
        words.take(_maxTitleWords).where((word) => word.isNotEmpty).toList();
    var title = truncatedWords.join(' ');
    if (title.length > _maxTitleLength) {
      title = title.substring(0, _maxTitleLength).trimRight();
    }
    return title;
  }

  // Save or update a chat session
  static Future<void> saveChatSession(
    List<ChatMessage> messages,
    String sessionName, {
    String? sessionId,
    bool replaceIfExists = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Convert messages to JSON
    final messagesJson = messages
        .map((message) => {
              'text': message.text,
              'isUser': message.isUser,
              'timestamp': message.timestamp.toIso8601String(),
            })
        .toList();

    final sessionData = {
      'id': sessionId,
      'name': sessionName,
      'messages': messagesJson,
      'timestamp': DateTime.now().toIso8601String(),
    };

    // Get existing sessions
    final existingSessions = await getChatSessions();
    if (replaceIfExists && sessionId != null) {
      final index = existingSessions
          .indexWhere((session) => session['id'] == sessionId);
      if (index >= 0) {
        existingSessions[index] = sessionData;
      } else {
        existingSessions.add(sessionData);
      }
    } else {
      existingSessions.add(sessionData);
    }

    // Keep only last 20 sessions
    if (existingSessions.length > 20) {
      existingSessions.removeRange(0, existingSessions.length - 20);
    }

    await prefs.setString(_chatSessionsKey, jsonEncode(existingSessions));
  }

  // Get all chat sessions
  static Future<List<Map<String, dynamic>>> getChatSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionsJson = prefs.getString(_chatSessionsKey);

    if (sessionsJson != null) {
      final sessionsList = jsonDecode(sessionsJson) as List;
      return sessionsList.cast<Map<String, dynamic>>();
    }

    return [];
  }

  // Load a specific chat session
  static Future<List<ChatMessage>> loadChatSession(
      Map<String, dynamic> session) async {
    final messagesData = session['messages'] as List;

    return messagesData
        .map((messageData) => ChatMessage(
              text: messageData['text'],
              isUser: messageData['isUser'],
              timestamp: DateTime.parse(messageData['timestamp']),
            ))
        .toList();
  }

  // Delete a chat session
  static Future<void> deleteChatSession(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await getChatSessions();

    if (index >= 0 && index < sessions.length) {
      sessions.removeAt(index);
      await prefs.setString(_chatSessionsKey, jsonEncode(sessions));
    }
  }

  // Export chat to text file
  static Future<String> exportChatToFile(
      List<ChatMessage> messages, String sessionName) async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName =
        'MediPal_Chat_${sessionName}_${DateTime.now().millisecondsSinceEpoch}.txt';
    final file = File('${directory.path}/$fileName');

    final buffer = StringBuffer();
    buffer.writeln('MediPal Chat Export');
    buffer.writeln('Session: $sessionName');
    buffer.writeln('Exported: ${DateTime.now()}');
    buffer.writeln('=' * 50);
    buffer.writeln();

    for (final message in messages) {
      final sender = message.isUser ? 'You' : 'MediPal';
      final time = _formatTime(message.timestamp);
      buffer.writeln('[$time] $sender:');
      buffer.writeln(message.text);
      buffer.writeln();
    }

    await file.writeAsString(buffer.toString());
    return file.path;
  }

  static String _formatTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // Clear all chat history
  static Future<void> clearAllHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chatSessionsKey);
  }
}
