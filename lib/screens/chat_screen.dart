import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/chat_attachment.dart';
import '../services/deepseek_service.dart';
import '../services/chat_history_service.dart';
import '../services/document_ingest_queue.dart';
import '../utils/app_state.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import '../services/document_ingest_service.dart';

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
  Timer? _autoSaveTimer;
  late final String _currentSessionId;
  bool _isProcessingDocument = false;
  final List<ChatAttachment> _attachedDocuments = [];
  bool _shouldAutoScroll = true;
  bool _isUserScrolling = false;
  AppState? _appState;
  bool _isDisposed = false;
  StreamSubscription<DocumentIngestEvent>? _ingestSubscription;
  final ValueNotifier<String> _streamingNotifier = ValueNotifier<String>('');
  String _pendingStreamChunk = '';
  StreamSubscription<String>? _streamSubscription;
  Completer<void>? _streamDoneCompleter;
  bool _streamCancelled = false;
  bool _isPrivateChat = false;

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
    final now = DateTime.now();
    _currentSessionId = now.millisecondsSinceEpoch.toString();
    _initializeAnimations();
    _initializeChat();
    _loadChatHistory();
    _scrollController.addListener(_handleScroll);
    _ingestSubscription = DocumentIngestQueue.stream.listen(_handleIngestEvent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processPendingDocuments();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appState ??= Provider.of<AppState>(context);
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
      _scheduleAutoSave();
    });
  }

  // NEW: Age-appropriate welcome message
  String _getAgeAppropriateWelcomeMessage(AppState appState) {
    if (appState.isMinor) {
      return '''👋 Hi ${appState.userName.isNotEmpty ? appState.userName : 'there'}! 🌟

I'm MediPal, and I'm here to help you learn about staying healthy! But remember - **always talk to your parents, guardians, or other trusted adults about health questions.**

I can help you learn about:
• 🏃‍♀️ Fun ways to stay active and strong
• 🥕 Healthy foods that taste great  
• 😴 Why sleep is super important
• 🧠 When it's important to tell adults you don't feel well

What would you like to learn about today? And don't forget - if you ever don't feel well, always tell a trusted adult! 💙''';
    } else {
      return '''👋 Hello ${appState.userName.isNotEmpty ? appState.userName : 'there'}! 

I'm MediPal, your personal health assistant. I'm here to help you with health questions, symptom analysis, medication information, and wellness tips.

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

  bool get _hasUserMessages => _messages.any((message) => message.isUser);
  bool get _showPrivateToggle => !_showHistory;
  bool get _showNewChatAction => !_showHistory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: colorScheme.surface,
            surfaceTintColor: colorScheme.surfaceTint,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.surface,
                    colorScheme.primaryContainer.withValues(alpha: 0.25),
                  ],
                ),
              ),
            ),
            title: AnimatedSlide(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              offset: const Offset(0, 0),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                opacity: 1,
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.outlineVariant,
                        ),
                      ),
                      child: Icon(
                        _showHistory ? Icons.history : Icons.psychology,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _showHistory
                                      ? 'Chat History'
                                      : appState.isMinor
                                          ? 'MediPal Companion'
                                          : 'MediPal Chat',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_isPrivateChat && !_showHistory)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: colorScheme.outlineVariant,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.lock,
                                    size: 14,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                          if (!_showHistory)
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: _isStreaming || _isLoading
                                        ? Colors.orange
                                        : Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Text(
                                  _isStreaming
                                      ? 'Responding'
                                      : _isLoading
                                          ? 'Thinking'
                                          : 'Ready',
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              if (_showPrivateToggle && !_hasUserMessages)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: _isPrivateChat,
                    label: const Text('Private'),
                    avatar: Icon(
                      _isPrivateChat ? Icons.lock : Icons.lock_open,
                      size: 16,
                    ),
                    onSelected: (value) {
                      setState(() {
                        _isPrivateChat = value;
                      });
                    },
                  ),
                ),
              if (_showNewChatAction && _hasUserMessages)
                IconButton(
                  icon: const Icon(Icons.add_comment),
                  tooltip: 'New chat',
                  onPressed: _confirmStartNewChat,
                ),
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

        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification) {
                _isUserScrolling = true;
              } else if (notification is UserScrollNotification) {
                if (notification.direction != ScrollDirection.idle) {
                  _isUserScrolling = true;
                }
              } else if (notification is ScrollEndNotification) {
                _isUserScrolling = false;
              }

              if (_scrollController.hasClients) {
                final position = _scrollController.position;
                final distanceFromBottom =
                    position.maxScrollExtent - position.pixels;
                const threshold = 120.0;
                _shouldAutoScroll = distanceFromBottom <= threshold;
              }
              return false;
            },
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
                  return TypingIndicator(
                      showIndicator: true, appState: appState);
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
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardOpen = viewInsets > 0;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SafeArea(
        top: false,
        bottom: !isKeyboardOpen,
        child: RepaintBoundary(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (appState.isMinor)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
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
                if (_attachedDocuments.isNotEmpty) ...[
                  _buildAttachmentChips(colorScheme, appState),
                  const SizedBox(height: 6),
                ],
                if (_isProcessingDocument) ...[
                  const LinearProgressIndicator(minHeight: 2),
                  const SizedBox(height: 6),
                ],
                if (_quickActions.isNotEmpty && !_hasUserMessages)
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _messageController,
                    builder: (context, value, child) {
                      final hasText = value.text.trim().isNotEmpty;
                      if (hasText) return const SizedBox.shrink();
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 36,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _quickActions.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final action = _quickActions[index];
                                return ActionChip(
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  avatar: Icon(_getIconData(action['icon']!),
                                      size: 14),
                                  label: Text(action['label']!),
                                  onPressed: () =>
                                      _sendQuickMessage(action['message']!),
                                  backgroundColor: colorScheme.primaryContainer
                                      .withValues(alpha: 0.3),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                      );
                    },
                  ),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colorScheme.outlineVariant,
                        ),
                        boxShadow: isKeyboardOpen
                            ? const []
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: (_isStreaming ||
                                _isLoading ||
                                _isProcessingDocument)
                            ? null
                            : () => _pickDocument(appState),
                        icon: const Icon(Icons.add, size: 20),
                        tooltip: 'Attach health document',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.98),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: colorScheme.outlineVariant,
                            ),
                            boxShadow: isKeyboardOpen
                                ? const []
                                : [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _messageController,
                                  decoration: InputDecoration(
                                    hintText: _isStreaming || _isLoading
                                        ? 'Please wait...'
                                        : appState.isMinor
                                            ? 'Ask me about staying healthy...'
                                            : 'Type your message...',
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    disabledBorder: InputBorder.none,
                                    isCollapsed: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 8,
                                    ),
                                  ),
                                  maxLines: null,
                                  enabled: !_isStreaming && !_isLoading,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  onSubmitted: (_) => _sendMessage(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _messageController,
                                builder: (context, value, child) {
                                  final hasText = value.text.trim().isNotEmpty;
                                  final isBusy = _isStreaming || _isLoading;
                                  return SizedBox(
                                    width: 36,
                                    height: 36,
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 36,
                                        minHeight: 36,
                                      ),
                                      onPressed: isBusy
                                          ? _stopStreamingResponse
                                          : (hasText ? _sendMessage : null),
                                      icon: Icon(
                                        isBusy
                                            ? Icons.stop_rounded
                                            : Icons.arrow_upward,
                                      ),
                                      style: IconButton.styleFrom(
                                        backgroundColor: isBusy || hasText
                                            ? colorScheme.primary
                                            : colorScheme
                                                .surfaceContainerHighest,
                                        foregroundColor: isBusy || hasText
                                            ? colorScheme.onPrimary
                                            : colorScheme.onSurfaceVariant,
                                        disabledBackgroundColor:
                                            colorScheme.surfaceContainerHighest,
                                        disabledForegroundColor:
                                            colorScheme.onSurfaceVariant,
                                        shape: const CircleBorder(),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
            ValueListenableBuilder<String>(
              valueListenable: _streamingNotifier,
              builder: (context, value, child) {
                if (value.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        color: appState.isMinor
                            ? Colors.orange.shade800
                            : colorScheme.onSurfaceVariant,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
            // Typing indicator
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'MediPal is typing',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                    color: (appState.isMinor
                            ? Colors.orange.shade600
                            : colorScheme.onSurfaceVariant)
                        .withValues(alpha: 0.7),
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
                                .withValues(alpha: opacity),
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

  void _stopStreamingResponse() {
    if (!_isStreaming && !_isLoading) return;
    _streamCancelled = true;
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _streamDoneCompleter?.complete();
    _streamDoneCompleter = null;

    if (_streamingContent.isNotEmpty) {
      setState(() {
        _messages.add(ChatMessage(text: _streamingContent, isUser: false));
      });
      _scheduleAutoSave();
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isStreaming = false;
        _streamingContent = '';
      });
      _streamingNotifier.value = '';
      _scrollToBottom();
    }

    if (mounted && !_isDisposed) {
      _typingAnimationController.stop();
    }
  }

  // ENHANCED: Message sending with age restrictions and AppState
  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isStreaming || _isLoading) return;

    // Get AppState for age-appropriate handling
    final appState = Provider.of<AppState>(context, listen: false);

    // Clear input immediately for better UX
    _messageController.clear();
    _shouldAutoScroll = true;

    // Add user message instantly
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
    });
    _scheduleAutoSave();
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
        _scheduleAutoSave();
        _scrollToBottom();
        return;
      }

      // Use streaming for better UX
      _streamCancelled = false;
      setState(() {
        _isStreaming = true;
        _streamingContent = '';
      });
      _streamingNotifier.value = '';

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
      Object? streamError;
      _streamDoneCompleter = Completer<void>();
      _streamSubscription = deepSeekService
          .streamChatResponse(conversationHistory, appState)
          .listen((chunk) {
        hasStreamedContent = true;
        _pendingStreamChunk = chunk;
        _streamingContent = _pendingStreamChunk;
        _streamingNotifier.value = _streamingContent;
        if (!_isUserScrolling && _shouldAutoScroll) {
          _scrollToBottom();
        }
      }, onError: (error) {
        streamError = error;
        _streamDoneCompleter?.complete();
      }, onDone: () {
        _streamDoneCompleter?.complete();
      });

      await _streamDoneCompleter?.future;
      _streamDoneCompleter = null;
      await _streamSubscription?.cancel();
      _streamSubscription = null;

      if (streamError != null) {
        throw streamError!;
      }

      if (_streamCancelled) {
        return;
      }

      // Add final message to history
      if (hasStreamedContent && _streamingContent.isNotEmpty) {
        setState(() {
          _messages.add(ChatMessage(text: _streamingContent, isUser: false));
        });
        _scheduleAutoSave();
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
        _scheduleAutoSave();
      }
    } catch (e) {
      if (!mounted) return;
      final appState = Provider.of<AppState>(context, listen: false);
      setState(() {
        _messages.add(
          ChatMessage(
            text: appState.getAgeAppropriateErrorMessage(),
            isUser: false,
          ),
        );
      });
      _scheduleAutoSave();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isStreaming = false;
          _streamingContent = '';
        });
        _streamingNotifier.value = '';
        _scrollToBottom();
      }
      if (mounted && !_isDisposed) {
        _typingAnimationController.stop();
      }
    }
  }

  Widget _buildAttachmentChips(ColorScheme colorScheme, AppState appState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Attached health documents',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _attachedDocuments.clear();
                });
                _updateDocumentContext(appState);
                _scheduleAutoSave();
              },
              child: const Text('Clear all'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: _attachedDocuments.map((doc) {
            return InputChip(
              label: Text(doc.name, overflow: TextOverflow.ellipsis),
              avatar: const Icon(Icons.description, size: 18),
              onDeleted: () {
                setState(() {
                  _attachedDocuments.remove(doc);
                });
                _updateDocumentContext(appState);
                _scheduleAutoSave();
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _pickDocument(AppState appState) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'docx', 'png', 'jpg', 'jpeg'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;

      if (file.size > 15 * 1024 * 1024) {
        _showSnackBar('Please choose a file under 15 MB.');
        return;
      }

      setState(() => _isProcessingDocument = true);
      await DocumentIngestQueue.enqueue(file, _currentSessionId);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Unable to process the document.');
    }
  }

  void _handleIngestEvent(DocumentIngestEvent event) {
    if (event.sessionId != _currentSessionId) return;
    if (!mounted) return;

    if (event.error != null) {
      setState(() => _isProcessingDocument = false);
      _showSnackBar('Unable to process the document.');
      return;
    }

    final ingestResult = event.result;
    if (ingestResult == null || ingestResult.extractedText.isEmpty) {
      setState(() => _isProcessingDocument = false);
      _showSnackBar('Unable to read this document.');
      return;
    }

    setState(() => _isProcessingDocument = false);
    _processIngestResult(ingestResult);
  }

  Future<void> _processPendingDocuments() async {
    if (!mounted) return;
    if (_isProcessingDocument) {
      setState(() => _isProcessingDocument = false);
    }
    final pending = DocumentIngestQueue.takePending(_currentSessionId);
    for (final ingestResult in pending) {
      if (!mounted) return;
      await _processIngestResult(ingestResult);
    }
  }

  Future<void> _processIngestResult(DocumentIngestResult ingestResult) async {
    if (ingestResult.relevance == HealthDocRelevance.low) {
      await _showBlockedDocumentDialog();
      return;
    }

    final shouldAdd = await _confirmDocumentAdd(
        ingestResult, Provider.of<AppState>(context, listen: false));
    if (!mounted || !shouldAdd) return;

    setState(() {
      _attachedDocuments.add(DocumentIngestQueue.toAttachment(ingestResult));
    });
    _updateDocumentContext(Provider.of<AppState>(context, listen: false));
    _scheduleAutoSave();
  }

  Future<void> _showBlockedDocumentDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Health documents only'),
        content: const Text(
          'I can only read health-related documents. Please upload medical or wellness documents.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDocumentAdd(
      DocumentIngestResult result, AppState appState) async {
    final isMedium = result.relevance == HealthDocRelevance.medium;
    final preview = result.extractedText.length > 260
        ? '${result.extractedText.substring(0, 260)}...'
        : result.extractedText;

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
                isMedium ? 'Confirm health document' : 'Add health document'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMedium
                        ? 'This document doesn\'t clearly look health-related. Please confirm it is.'
                        : 'We detected health-related content. Add it to your chat context?',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Preview:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(preview),
                  const SizedBox(height: 12),
                  Text(
                    'On-device only • ${result.wordCount} words',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Add'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _updateDocumentContext(AppState appState) {
    final contextText = _buildDocumentContext();
    appState.setChatDocumentContext(contextText);
  }

  String _buildDocumentContext() {
    if (_attachedDocuments.isEmpty) return '';
    const maxTotalChars = 4000;
    final buffer = StringBuffer();
    int used = 0;

    for (final doc in _attachedDocuments) {
      final header = 'Document: ${doc.name}\n';
      if (used + header.length > maxTotalChars) break;
      buffer.write(header);
      used += header.length;

      final remaining = maxTotalChars - used;
      if (remaining <= 0) break;
      final chunk = doc.contextText.length > remaining
          ? doc.contextText.substring(0, remaining)
          : doc.contextText;
      buffer.write(chunk);
      buffer.write('\n\n');
      used += chunk.length + 2;
      if (used >= maxTotalChars) break;
    }

    return buffer.toString().trim();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
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

  void _scheduleAutoSave() {
    if (_isPrivateChat) return;
    if (_messages.length <= 1) return;
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 600), () async {
      final sessionName = ChatHistoryService.generateSessionName(_messages);
      await ChatHistoryService.saveChatSession(
        _messages,
        sessionName,
        sessionId: _currentSessionId,
        replaceIfExists: true,
        attachments: _attachedDocuments,
      );
      if (mounted) {
        await Provider.of<AppState>(context, listen: false)
            .refreshChatSessionsCount();
      }
    });
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
        final attachments = ChatHistoryService.loadChatAttachments(session);
        setState(() {
          _messages.clear();
          _messages.addAll(messages);
          _attachedDocuments
            ..clear()
            ..addAll(attachments);
          _showHistory = false;
        });
        if (mounted) {
          _updateDocumentContext(Provider.of<AppState>(context, listen: false));
        }
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
        final id = session['id'];
        if (id != null) {
          await ChatHistoryService.deleteChatSessionById(id);
        }
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
    buffer.writeln('MediPal Chat - $sessionName');
    buffer.writeln('Exported: ${DateTime.now()}');
    buffer.writeln('=' * 30);
    buffer.writeln();

    for (final message in messages) {
      final sender = message.isUser ? 'You' : 'MediPal';
      buffer.writeln('$sender: ${message.text}');
      buffer.writeln();
    }

    await Share.share(buffer.toString(),
        subject: 'MediPal Chat - $sessionName');
  }

  void _clearCurrentChat() {
    setState(() {
      _messages.clear();
    });
    _initializeChat(); // Reinitialize with age-appropriate welcome message
  }

  Future<void> _confirmStartNewChat() async {
    final shouldStart = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Start a new chat?'),
            content: const Text(
              'This will clear the current conversation. You can still find it in chat history unless you are in Private chat.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Start new'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldStart) return;
    setState(() {
      _messages.clear();
      _attachedDocuments.clear();
    });
    _updateDocumentContext(Provider.of<AppState>(context, listen: false));
    _initializeChat();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients &&
          _shouldAutoScroll &&
          !_isUserScrolling) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final distanceFromBottom = position.maxScrollExtent - position.pixels;
    const threshold = 120.0;
    _shouldAutoScroll = distanceFromBottom <= threshold;
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
    _isDisposed = true;
    _autoSaveTimer?.cancel();
    _appState?.clearChatDocumentContext(notify: false);
    _scrollController.removeListener(_handleScroll);
    _ingestSubscription?.cancel();
    _streamSubscription?.cancel();
    _streamDoneCompleter?.complete();
    _streamingNotifier.dispose();
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
                            .withValues(alpha: 0.6),
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
                              .withValues(alpha: 0.6),
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
              'MediPal is typing',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 13,
                color: (widget.appState.isMinor
                        ? Colors.orange.shade600
                        : colorScheme.onSurfaceVariant)
                    .withValues(alpha: 0.7),
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
                            .withValues(alpha: opacity),
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
