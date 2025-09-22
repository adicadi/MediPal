import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/deepseek_service.dart';
import '../services/chat_history_service.dart';
import '../utils/app_state.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _showHistory = false;
  List<Map<String, dynamic>> _chatSessions = [];

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _loadChatHistory();
  }

  void _initializeChat() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = Provider.of<AppState>(context, listen: false);
      final userName =
          appState.userName.isNotEmpty ? appState.userName : 'there';

      setState(() {
        _messages.add(
          ChatMessage(
            text:
                '👋 Hello $userName! I\'m PersonalMedAI, your personal health assistant. I\'m here to help you with health questions, symptom analysis, medication information, and wellness tips.\n\nHow can I assist you today?',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
    });
  }

  void _loadChatHistory() async {
    final sessions = await ChatHistoryService.getChatSessions();
    setState(() {
      _chatSessions = sessions.reversed.toList(); // Show newest first
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_showHistory ? 'Chat History' : 'AI Chat'),
        backgroundColor: colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: Icon(_showHistory ? Icons.chat : Icons.history),
            onPressed: () {
              setState(() {
                _showHistory = !_showHistory;
              });
              if (_showHistory) _loadChatHistory();
            },
            tooltip: _showHistory ? 'Current Chat' : 'Chat History',
          ),
          if (!_showHistory && _messages.length > 1) ...[
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveChatSession,
              tooltip: 'Save Chat',
            ),
            PopupMenuButton<String>(
              onSelected: _handleMenuAction,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'export',
                  child: Row(
                    children: [
                      Icon(Icons.download),
                      SizedBox(width: 8),
                      Text('Export Chat'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(Icons.share),
                      SizedBox(width: 8),
                      Text('Share Chat'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.clear_all),
                      SizedBox(width: 8),
                      Text('Clear Chat'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: _showHistory ? _buildHistoryView() : _buildChatView(),
    );
  }

  Widget _buildChatView() {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length + (_isLoading ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _messages.length && _isLoading) {
                return const TypingIndicator(showIndicator: true);
              }

              final message = _messages[index];
              return ChatBubble(
                message: message,
                onCopy: () => _copyMessage(message.text),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(
              top: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Type your message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              FloatingActionButton(
                onPressed: _sendMessage,
                mini: true,
                child: const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryView() {
    if (_chatSessions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No chat history yet',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Start a conversation to see your chat history here',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _chatSessions.length,
      itemBuilder: (context, index) {
        final session = _chatSessions[index];
        final sessionTime = DateTime.parse(session['timestamp']);
        final messages = session['messages'] as List;
        final preview = messages.isNotEmpty && messages.length > 1
            ? messages[1]['text'] ?? 'No preview'
            : 'No messages';

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(session['name'] ?? 'Unnamed Session'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preview.length > 50
                      ? '${preview.substring(0, 50)}...'
                      : preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(sessionTime),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            leading: const CircleAvatar(child: Icon(Icons.chat)),
            trailing: PopupMenuButton<String>(
              onSelected: (value) =>
                  _handleHistoryAction(value, index, session),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'load',
                  child: Row(
                    children: [
                      Icon(Icons.restore),
                      SizedBox(width: 8),
                      Text('Load Chat'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'export',
                  child: Row(
                    children: [
                      Icon(Icons.download),
                      SizedBox(width: 8),
                      Text('Export'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(Icons.share),
                      SizedBox(width: 8),
                      Text('Share'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
            onTap: () => _handleHistoryAction('load', index, session),
          ),
        );
      },
    );
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    await Future.delayed(const Duration(milliseconds: 300));

    try {
      final deepSeekService = Provider.of<DeepSeekService>(
        context,
        listen: false,
      );

      final conversationHistory = _messages
          .map(
            (message) => {
              'isUser': message.isUser.toString(),
              'text': message.text,
            },
          )
          .toList();

      final response = await deepSeekService.sendChatMessage(
        conversationHistory,
      );

      setState(() {
        _messages.add(ChatMessage(text: response, isUser: false));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(
          ChatMessage(
            text:
                'I\'m experiencing high demand. Please try again in a moment.',
            isUser: false,
          ),
        );
        _isLoading = false;
      });
    }

    _scrollToBottom();
  }

  void _copyMessage(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _saveChatSession() async {
    if (_messages.length <= 1) return;

    final sessionName =
        'Chat ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}';

    await ChatHistoryService.saveChatSession(_messages, sessionName);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chat session saved'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _handleMenuAction(String action) async {
    switch (action) {
      case 'export':
        await _exportCurrentChat();
        break;
      case 'share':
        await _shareCurrentChat();
        break;
      case 'clear':
        _clearCurrentChat();
        break;
    }
  }

  void _handleHistoryAction(
    String action,
    int index,
    Map<String, dynamic> session,
  ) async {
    switch (action) {
      case 'load':
        final messages = await ChatHistoryService.loadChatSession(session);
        setState(() {
          _messages.clear();
          _messages.addAll(messages);
          _showHistory = false;
        });
        break;
      case 'export':
        final messages = await ChatHistoryService.loadChatSession(session);
        final filePath = await ChatHistoryService.exportChatToFile(
          messages,
          session['name'],
        );
        _showExportSuccess(filePath);
        break;
      case 'share':
        final messages = await ChatHistoryService.loadChatSession(session);
        await _shareChat(messages, session['name']);
        break;
      case 'delete':
        await ChatHistoryService.deleteChatSession(index);
        _loadChatHistory();
        break;
    }
  }

  Future<void> _exportCurrentChat() async {
    if (_messages.length <= 1) return;

    final sessionName = 'Current_Chat';
    final filePath = await ChatHistoryService.exportChatToFile(
      _messages,
      sessionName,
    );
    _showExportSuccess(filePath);
  }

  void _showExportSuccess(String filePath) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Chat exported to: $filePath'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Share',
          onPressed: () => Share.shareXFiles([XFile(filePath)]),
        ),
      ),
    );
  }

  Future<void> _shareCurrentChat() async {
    await _shareChat(_messages, 'Current Chat');
  }

  Future<void> _shareChat(
    List<ChatMessage> messages,
    String sessionName,
  ) async {
    if (messages.length <= 1) return;

    final buffer = StringBuffer();
    buffer.writeln('PersonalMedAI Chat - $sessionName');
    buffer.writeln('Exported: ${DateTime.now()}');
    buffer.writeln('=' * 30);
    buffer.writeln();

    for (final message in messages) {
      final sender = message.isUser ? 'You' : 'PersonalMedAI';
      buffer.writeln('$sender: ${message.text}');
      buffer.writeln();
    }

    await Share.share(
      buffer.toString(),
      subject: 'PersonalMedAI Chat - $sessionName',
    );
  }

  void _clearCurrentChat() {
    setState(() {
      _messages.clear();
      _initializeChat();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return 'Today ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onCopy;

  const ChatBubble({super.key, required this.message, this.onCopy});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onCopy,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            color: message.isUser
                ? colorScheme.primary
                : colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(18).copyWith(
              bottomRight: message.isUser ? const Radius.circular(4) : null,
              bottomLeft: message.isUser ? null : const Radius.circular(4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Use GptMarkdown for AI responses, regular Text for user messages
              message.isUser
                  ? Text(
                      message.text,
                      style: TextStyle(
                        color: colorScheme.onPrimary,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    )
                  : SelectionArea(
                      child: TexMarkdown(
                        message.text,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 14,
                          height: 1.4, // Add line height for better readability
                        ),
                      ),
                    ),

              if (!message.isUser) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(message.timestamp),
                      style: TextStyle(
                        fontSize: 10,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: onCopy,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.copy,
                          size: 14,
                          color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

// Keep your existing ChatMessage and TypingIndicator classes
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({required this.text, required this.isUser, DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();
}

class TypingIndicator extends StatefulWidget {
  final bool showIndicator;

  const TypingIndicator({super.key, this.showIndicator = false});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (!widget.showIndicator) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, right: 80),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(
            18,
          ).copyWith(bottomLeft: const Radius.circular(4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'PersonalMedAI is typing',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 13,
                color: colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Row(
                  children: List.generate(3, (index) {
                    final delay = index * 0.3;
                    final value = (_animationController.value + delay) % 1.0;
                    final opacity =
                        (Curves.easeInOut.transform(value) * 0.8 + 0.2).clamp(
                      0.0,
                      1.0,
                    );

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: colorScheme.onSurfaceVariant.withOpacity(
                          opacity,
                        ),
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
