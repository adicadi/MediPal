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

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  // OPTIMIZED: Enhanced state management for streaming
  bool _isLoading = false;
  bool _isStreaming = false;
  bool _showHistory = false;
  String _streamingContent = '';
  List<Map<String, dynamic>> _chatSessions = [];

  // OPTIMIZED: Animation controllers for better UX
  late AnimationController _typingAnimationController;
  late Animation<double> _typingAnimation;

  // ENHANCED: Age-appropriate quick actions
  List<Map<String, String>> get _quickActions {
    final appState = Provider.of<AppState>(context, listen: false);

    if (appState.isMinor) {
      return [
        {'icon': 'help_outline', 'label': 'Help', 'message': 'help'},
        {
          'icon': 'school',
          'label': 'Health Tips',
          'message': 'Tell me about staying healthy'
        },
        {
          'icon': 'family_restroom',
          'label': 'Tell Adults',
          'message': 'When should I tell adults about health questions?'
        },
        {'icon': 'emergency', 'label': 'Emergency', 'message': 'emergency'},
      ];
    } else {
      return [
        {'icon': 'help_outline', 'label': 'Help', 'message': 'help'},
        {'icon': 'emergency', 'label': 'Emergency', 'message': 'emergency'},
        {
          'icon': 'medication',
          'label': 'Medications',
          'message': 'Tell me about medication safety'
        },
        {
          'icon': 'health_and_safety',
          'label': 'Symptoms',
          'message': 'I have some symptoms I\'d like to discuss'
        },
      ];
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeChat();
    _loadChatHistory();
  }

  void _initializeAnimations() {
    _typingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _typingAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _typingAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  // ENHANCED: Age-appropriate welcome message
  void _initializeChat() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = Provider.of<AppState>(context, listen: false);

      setState(() {
        _messages.add(
          ChatMessage(
            text: _getAgeAppropriateWelcomeMessage(appState),
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
    });
  }

  // NEW: Age-appropriate welcome message
  String _getAgeAppropriateWelcomeMessage(AppState appState) {
    if (appState.isMinor) {
      return '''👋 Hi ${appState.userName.isNotEmpty ? appState.userName : 'there'}! 🌟

I'm PersonalMedAI, and I'm here to help you learn about staying healthy! But remember - **always talk to your parents, guardians, or other trusted adults about health questions.**

I can help you learn about:
• 🏃‍♀️ Fun ways to stay active and strong
• 🥕 Healthy foods that taste great  
• 😴 Why sleep is super important
• 🧠 When it's important to tell adults you don't feel well

What would you like to learn about today? And don't forget - if you ever don't feel well, always tell a trusted adult! 💙''';
    } else {
      return '''👋 Hello ${appState.userName.isNotEmpty ? appState.userName : 'there'}! 

I'm PersonalMedAI, your personal health assistant. I'm here to help you with health questions, symptom analysis, medication information, and wellness tips.

**I can assist with:**
• Medical questions and symptom guidance
• Medication interactions and safety
• Health insights and recommendations  
• Wellness tips and lifestyle advice
• Emergency information

How can I help you today? Remember, I provide information to support your health decisions, but always consult healthcare professionals for medical advice.''';
    }
  }

  void _loadChatHistory() async {
    final sessions = await ChatHistoryService.getChatSessions();
    setState(() {
      _chatSessions = sessions.reversed.toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_showHistory
                    ? 'Chat History'
                    : appState.isMinor
                        ? 'PersonalMedAI - Young User'
                        : 'PersonalMedAI Chat'),
                if (!_showHistory) ...[
                  Row(
                    children: [
                      Text(
                        _isStreaming
                            ? '✨ Responding...'
                            : _isLoading
                                ? '🤔 Thinking...'
                                : '💬 Ready to help',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _isStreaming || _isLoading
                              ? Colors.orange
                              : Colors.green,
                        ),
                      ),
                      if (appState.isMinor) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Safe Mode',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
            backgroundColor: appState.isMinor
                ? Colors.orange.shade50
                : colorScheme.primaryContainer,
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
                        child: Row(children: [
                          Icon(Icons.download),
                          SizedBox(width: 8),
                          Text('Export Chat')
                        ])),
                    const PopupMenuItem(
                        value: 'share',
                        child: Row(children: [
                          Icon(Icons.share),
                          SizedBox(width: 8),
                          Text('Share Chat')
                        ])),
                    const PopupMenuItem(
                        value: 'clear',
                        child: Row(children: [
                          Icon(Icons.clear_all),
                          SizedBox(width: 8),
                          Text('Clear Chat')
                        ])),
                  ],
                ),
              ],
            ],
          ),
          body: _showHistory ? _buildHistoryView() : _buildChatView(appState),
        );
      },
    );
  }

  Widget _buildChatView(AppState appState) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Age-appropriate safety notice for minors
        if (appState.isMinor && _messages.length == 1)
          _buildMinorSafetyNotice(),

        // OPTIMIZED: Quick actions bar for instant responses
        if (!_isStreaming && !_isLoading) _buildQuickActionsBar(),

        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length +
                (_isStreaming ? 1 : 0) +
                (_isLoading && !_isStreaming ? 1 : 0),
            itemBuilder: (context, index) {
              // Show streaming message
              if (_isStreaming && index == _messages.length) {
                return _buildStreamingBubble(appState);
              }

              // Show loading indicator
              if (_isLoading && !_isStreaming && index == _messages.length) {
                return TypingIndicator(showIndicator: true, appState: appState);
              }

              final message = _messages[index];
              return ChatBubble(
                message: message,
                appState: appState,
                onCopy: () => _copyMessage(message.text),
              );
            },
          ),
        ),

        _buildInputArea(appState, colorScheme),
      ],
    );
  }

  // NEW: Minor safety notice
  Widget _buildMinorSafetyNotice() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.family_restroom, color: Colors.orange.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '🌟 Remember: Always talk to your parents, guardians, or other trusted adults about health questions!',
              style: TextStyle(
                color: Colors.orange.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ENHANCED: Age-appropriate input area
  Widget _buildInputArea(AppState appState, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
        ),
      ),
      child: Column(
        children: [
          // Minor reminder
          if (appState.isMinor) ...[
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '💡 Ask me about healthy habits, but always talk to trusted adults about health concerns!',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: _isStreaming || _isLoading
                        ? 'Please wait...'
                        : appState.isMinor
                            ? 'Ask me about staying healthy...'
                            : 'Type your message...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  maxLines: null,
                  enabled: !_isStreaming && !_isLoading,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              FloatingActionButton(
                onPressed: (_isStreaming || _isLoading) ? null : _sendMessage,
                mini: true,
                backgroundColor: appState.isMinor ? Colors.orange : null,
                child: _isStreaming || _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.send),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ENHANCED: Age-appropriate quick actions
  Widget _buildQuickActionsBar() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _quickActions.length,
        itemBuilder: (context, index) {
          final action = _quickActions[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              avatar: Icon(_getIconData(action['icon']!), size: 16),
              label: Text(action['label']!),
              onPressed: () => _sendQuickMessage(action['message']!),
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withOpacity(0.3),
            ),
          );
        },
      ),
    );
  }

  // ENHANCED: Streaming response bubble with age-appropriate styling
  Widget _buildStreamingBubble(AppState appState) {
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, right: 80),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: appState.isMinor
              ? Colors.orange.shade50
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18).copyWith(
            bottomLeft: const Radius.circular(4),
          ),
          border: appState.isMinor
              ? Border.all(color: Colors.orange.shade200)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_streamingContent.isNotEmpty) ...[
              SelectionArea(
                child: TexMarkdown(
                  _streamingContent,
                  style: TextStyle(
                    color: appState.isMinor
                        ? Colors.orange.shade800
                        : colorScheme.onSurfaceVariant,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Typing indicator
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'PersonalMedAI is typing',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                    color: (appState.isMinor
                            ? Colors.orange.shade600
                            : colorScheme.onSurfaceVariant)
                        .withOpacity(0.7),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedBuilder(
                  animation: _typingAnimation,
                  builder: (context, child) {
                    return Row(
                      children: List.generate(3, (index) {
                        final delay = index * 0.3;
                        final value = (_typingAnimation.value + delay) % 1.0;
                        final opacity =
                            (Curves.easeInOut.transform(value) * 0.8 + 0.2)
                                .clamp(0.0, 1.0);

                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: (appState.isMinor
                                    ? Colors.orange.shade600
                                    : colorScheme.onSurfaceVariant)
                                .withOpacity(opacity),
                            shape: BoxShape.circle,
                          ),
                        );
                      }),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
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
            Text('No chat history yet',
                style: TextStyle(fontSize: 18, color: Colors.grey)),
            SizedBox(height: 8),
            Text('Start a conversation to see your chat history here',
                style: TextStyle(color: Colors.grey)),
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
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(_formatDate(sessionTime),
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
            leading: const CircleAvatar(child: Icon(Icons.chat)),
            trailing: PopupMenuButton<String>(
              onSelected: (value) =>
                  _handleHistoryAction(value, index, session),
              itemBuilder: (context) => [
                const PopupMenuItem(
                    value: 'load',
                    child: Row(children: [
                      Icon(Icons.restore),
                      SizedBox(width: 8),
                      Text('Load Chat')
                    ])),
                const PopupMenuItem(
                    value: 'export',
                    child: Row(children: [
                      Icon(Icons.download),
                      SizedBox(width: 8),
                      Text('Export')
                    ])),
                const PopupMenuItem(
                    value: 'share',
                    child: Row(children: [
                      Icon(Icons.share),
                      SizedBox(width: 8),
                      Text('Share')
                    ])),
                const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red))
                    ])),
              ],
            ),
            onTap: () => _handleHistoryAction('load', index, session),
          ),
        );
      },
    );
  }

  // OPTIMIZED: Send quick message with instant response
  void _sendQuickMessage(String message) {
    _messageController.text = message;
    _sendMessage();
  }

  // ENHANCED: Message sending with age restrictions and AppState
  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isStreaming || _isLoading) return;

    // Get AppState for age-appropriate handling
    final appState = Provider.of<AppState>(context, listen: false);

    // Clear input immediately for better UX
    _messageController.clear();

    // Add user message instantly
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
    });
    _scrollToBottom();

    try {
      final deepSeekService =
          Provider.of<DeepSeekService>(context, listen: false);

      // Check if quick response is available (now with AppState)
      final quickResponse = deepSeekService.getQuickResponse(text, appState);

      if (quickResponse != null) {
        // Show brief loading for natural feel
        setState(() {
          _isLoading = true;
        });
        await Future.delayed(const Duration(milliseconds: 600));

        setState(() {
          _messages.add(ChatMessage(text: quickResponse, isUser: false));
          _isLoading = false;
        });
        _scrollToBottom();
        return;
      }

      // Use streaming for better UX
      setState(() {
        _isStreaming = true;
        _streamingContent = '';
      });

      _typingAnimationController.repeat();
      _scrollToBottom();

      final conversationHistory = _messages
          .map((message) => {
                'isUser': message.isUser.toString(),
                'text': message.text,
              })
          .toList();

      // Try streaming first (now with AppState)
      bool hasStreamedContent = false;
      await for (final chunk in deepSeekService.streamChatResponse(
          conversationHistory, appState)) {
        setState(() {
          _streamingContent = chunk;
          hasStreamedContent = true;
        });
        _scrollToBottom();
      }

      // Add final message to history
      if (hasStreamedContent && _streamingContent.isNotEmpty) {
        setState(() {
          _messages.add(ChatMessage(text: _streamingContent, isUser: false));
        });
      } else {
        // Fallback to regular API if streaming failed
        setState(() {
          _isLoading = true;
        });
        final response = await deepSeekService.sendChatMessage(
            conversationHistory, appState);
        setState(() {
          _messages.add(ChatMessage(text: response, isUser: false));
        });
      }
    } catch (e) {
      final appState = Provider.of<AppState>(context, listen: false);
      setState(() {
        _messages.add(
          ChatMessage(
            text: appState.getAgeAppropriateErrorMessage(),
            isUser: false,
          ),
        );
      });
    } finally {
      setState(() {
        _isLoading = false;
        _isStreaming = false;
        _streamingContent = '';
      });
      _typingAnimationController.stop();
      _scrollToBottom();
    }
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'help_outline':
        return Icons.help_outline;
      case 'emergency':
        return Icons.emergency;
      case 'medication':
        return Icons.medication;
      case 'health_and_safety':
        return Icons.health_and_safety;
      case 'school':
        return Icons.school;
      case 'family_restroom':
        return Icons.family_restroom;
      default:
        return Icons.help_outline;
    }
  }

  void _copyMessage(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.copy, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Message copied to clipboard',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
      String action, int index, Map<String, dynamic> session) async {
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
            messages, session['name']);
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
    const sessionName = 'Current_Chat';
    final filePath =
        await ChatHistoryService.exportChatToFile(_messages, sessionName);
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
      List<ChatMessage> messages, String sessionName) async {
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

    await Share.share(buffer.toString(),
        subject: 'PersonalMedAI Chat - $sessionName');
  }

  void _clearCurrentChat() {
    setState(() {
      _messages.clear();
    });
    _initializeChat(); // Reinitialize with age-appropriate welcome message
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
    _typingAnimationController.dispose();
    super.dispose();
  }
}

// ENHANCED: Chat bubble with age-appropriate styling
class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final AppState appState;
  final VoidCallback? onCopy;

  const ChatBubble(
      {super.key, required this.message, required this.appState, this.onCopy});

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
              maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            color: message.isUser
                ? (appState.isMinor
                    ? Colors.orange.shade400
                    : colorScheme.primary)
                : (appState.isMinor
                    ? Colors.orange.shade50
                    : colorScheme.surfaceContainerHighest),
            borderRadius: BorderRadius.circular(18).copyWith(
              bottomRight: message.isUser ? const Radius.circular(4) : null,
              bottomLeft: message.isUser ? null : const Radius.circular(4),
            ),
            border: appState.isMinor && !message.isUser
                ? Border.all(color: Colors.orange.shade200)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              message.isUser
                  ? Text(
                      message.text,
                      style: TextStyle(
                        color: appState.isMinor
                            ? Colors.white
                            : colorScheme.onPrimary,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    )
                  : SelectionArea(
                      child: TexMarkdown(
                        message.text,
                        style: TextStyle(
                          color: appState.isMinor
                              ? Colors.orange.shade800
                              : colorScheme.onSurfaceVariant,
                          fontSize: 14,
                          height: 1.4,
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
                        color: (appState.isMinor
                                ? Colors.orange.shade600
                                : colorScheme.onSurfaceVariant)
                            .withOpacity(0.6),
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
                          color: (appState.isMinor
                                  ? Colors.orange.shade600
                                  : colorScheme.onSurfaceVariant)
                              .withOpacity(0.6),
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

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({required this.text, required this.isUser, DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();
}

// ENHANCED: Typing indicator with age-appropriate styling
class TypingIndicator extends StatefulWidget {
  final bool showIndicator;
  final AppState appState;

  const TypingIndicator(
      {super.key, this.showIndicator = false, required this.appState});

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

    if (!widget.showIndicator) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, right: 80),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: widget.appState.isMinor
              ? Colors.orange.shade50
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18)
              .copyWith(bottomLeft: const Radius.circular(4)),
          border: widget.appState.isMinor
              ? Border.all(color: Colors.orange.shade200)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'PersonalMedAI is typing',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 13,
                color: (widget.appState.isMinor
                        ? Colors.orange.shade600
                        : colorScheme.onSurfaceVariant)
                    .withOpacity(0.7),
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
                        (Curves.easeInOut.transform(value) * 0.8 + 0.2)
                            .clamp(0.0, 1.0);

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: (widget.appState.isMinor
                                ? Colors.orange.shade600
                                : colorScheme.onSurfaceVariant)
                            .withOpacity(opacity),
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
