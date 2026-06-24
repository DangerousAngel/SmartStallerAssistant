import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';
import 'package:student_assistance_app/services/database_service.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

String geminiApiKey = "ADD_YOUR_KEY_FROM_GOOGLE";

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime? timestamp;

  ChatMessage({required this.text, required this.isUser, this.timestamp});
}

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  late final GenerativeModel _model;
  late String _currentSessionId;
  List<Map<String, dynamic>> _chatSessions = [];

  @override
  void initState() {
    super.initState();
    _model =
        GenerativeModel(model: 'gemini-2.5-flash-lite', apiKey: geminiApiKey);
    _loadSessions();
    _startNewChat();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    final sessions = await _dbService.getChatSessions();
    if (mounted) setState(() => _chatSessions = sessions);
  }

  void _startNewChat() {
    setState(() {
      _currentSessionId = const Uuid().v4();
      _messages.clear();
      _dbService.createChatSession({
        'id': _currentSessionId,
        'title': 'Chat - ${DateFormat.yMd().add_jm().format(DateTime.now())}',
        'createdAt': DateTime.now().toIso8601String(),
      });
      _loadSessions();
    });
  }

  Future<void> _loadChatHistory(String sessionId) async {
    final messagesFromDb = await _dbService.getChatMessages(sessionId);
    final loadedMessages = messagesFromDb
        .map((msg) => ChatMessage(
              text: msg['text'],
              isUser: msg['role'] == 'user',
              timestamp: DateTime.parse(msg['createdAt']),
            ))
        .toList();
    setState(() {
      _currentSessionId = sessionId;
      _messages.clear();
      _messages.addAll(loadedMessages);
    });
    Navigator.pop(context);
  }

  Future<void> _deleteSession(String sessionId) async {
    await _dbService.deleteChatSession(sessionId);
    _loadSessions();
    if (_currentSessionId == sessionId) {
      _startNewChat();
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || geminiApiKey.isEmpty) {
      return;
    }
    _textController.clear();

    final userMessage =
        ChatMessage(text: text, isUser: true, timestamp: DateTime.now());
    _dbService.insertChatMessage({
      'sessionId': _currentSessionId,
      'role': 'user',
      'text': text,
      'createdAt': DateTime.now().toIso8601String(),
    });

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      final chatHistory = _messages
          .map((msg) => Content(
                msg.isUser ? 'user' : 'model',
                [TextPart(msg.text)],
              ))
          .toList();

      final content = chatHistory.length > 1
          ? chatHistory.sublist(0, chatHistory.length - 1)
          : <Content>[];
      final chat = _model.startChat(history: content);

      final response = await chat.sendMessage(Content.text(text));
      final responseText = response.text;

      if (responseText != null) {
        final aiMessage = ChatMessage(
            text: responseText, isUser: false, timestamp: DateTime.now());
        _dbService.insertChatMessage({
          'sessionId': _currentSessionId,
          'role': 'model',
          'text': responseText,
          'createdAt': DateTime.now().toIso8601String(),
        });
        if (mounted) setState(() => _messages.add(aiMessage));
      }
    } catch (e) {
      String errorMessage;

      // Handle specific exception types
      if (e is SocketException) {
        errorMessage =
            'No internet connection. Please check your network and try again.';
      } else if (e is HttpException) {
        errorMessage = 'You have Internet, but there\'s unexpected error.';
      } else {
        errorMessage = 'An error occurred: ${e.toString()}';
      }

      final errorChatMessage = ChatMessage(
          text: errorMessage, isUser: false, timestamp: DateTime.now());

      // Show a snackbar for more prominent error notification
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
      _scrollToBottom();
    }
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
          title: Text(l10n.aiAssistant),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          actions: [
            Image.asset(
              'assets/ic_launcher_foreground.png',
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            const SizedBox(width: 8),
          ]),
      drawer: _buildHistoryDrawer(),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8.0),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return _ChatMessageBubble(
                    message: ChatMessage(text: '...', isUser: false),
                    isLoading: true,
                  );
                }
                final message = _messages[index];
                return _ChatMessageBubble(message: message);
              },
            ),
          ),
          const Divider(height: 1.0),
          _buildTextComposer(),
        ],
      ),
    );
  }

  Widget _buildHistoryDrawer() {
    final l10n = AppLocalizations.of(context)!;
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            child: Image.asset(
              'assets/ic_launcher_round.png',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: Text(l10n.newChat),
            onTap: () {
              _startNewChat();
              Navigator.pop(context);
            },
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: _chatSessions.length,
              itemBuilder: (context, index) {
                final session = _chatSessions[index];
                return ListTile(
                  leading: const Icon(Icons.chat_bubble_outline),
                  title: Text(session['title'],
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => _loadChatHistory(session['id']),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Color.fromARGB(255, 160, 39, 39)),
                    onPressed: () => _deleteSession(session['id']),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextComposer() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      color: Theme.of(context).cardColor,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              textDirection: l10n.localeName == 'ar'
                  ? ui.TextDirection.rtl
                  : ui.TextDirection.ltr,
              onSubmitted: (value) => _sendMessage(),
              decoration:
                  InputDecoration.collapsed(hintText: l10n.askMeAnything),
            ),
          ),
          IconButton(
            icon:
                Icon(Icons.send, color: Theme.of(context).colorScheme.primary),
            onPressed: _isLoading ? null : _sendMessage,
          ),
        ],
      ),
    );
  }
}

class _ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isLoading;

  const _ChatMessageBubble({
    super.key,
    required this.message,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final bubbleColor = isLoading
        ? (isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200)
        : message.isUser
            ? theme.colorScheme.primary.withOpacity(0.8)
            : (isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300);

    final textColor = isLoading
        ? Colors.grey
        : message.isUser
            ? Colors.white
            : theme.textTheme.bodyLarge?.color;

    return GestureDetector(
      onLongPress: !isLoading
          ? () {
              Clipboard.setData(ClipboardData(text: message.text));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.messageCopiedToClipboard)),
              );
            }
          : null,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(
          mainAxisAlignment:
              message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                message.text,
                style: TextStyle(color: textColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
