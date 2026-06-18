import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/item_provider.dart';
import '../services/ai_service.dart';

// ════════════════════════════════════════════
// Message model
// ════════════════════════════════════════════
class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;

  _ChatMessage({
    required this.text,
    required this.isUser,
  }) : time = DateTime.now();
}

// ════════════════════════════════════════════
// Quick-action chip definition
// ════════════════════════════════════════════
class _QuickAction {
  final String label;
  final IconData icon;
  final String Function(List<String> items) promptBuilder;

  const _QuickAction({
    required this.label,
    required this.icon,
    required this.promptBuilder,
  });
}

// ════════════════════════════════════════════
// AIChatScreen
// ════════════════════════════════════════════
class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _aiReady = false;

  late final AIService _aiService;

  // ── Quick actions shown above the text field ──
  final List<_QuickAction> _quickActions = [
    _QuickAction(
      label: 'Summarise Cabinet',
      icon: Icons.inventory_2_outlined,
      promptBuilder: (items) =>
          'Summarise my cabinet contents and categorise them: ${items.join(", ")}',
    ),
    _QuickAction(
      label: 'Organise Tips',
      icon: Icons.tips_and_updates_outlined,
      promptBuilder: (items) =>
          'Give me organisation tips for these items: ${items.join(", ")}',
    ),
    _QuickAction(
      label: 'Expiry Advice',
      icon: Icons.calendar_today_outlined,
      promptBuilder: (items) =>
          'Which of these items are most likely to expire soon and what should I do? Items: ${items.join(", ")}',
    ),
    _QuickAction(
      label: 'Storage Advice',
      icon: Icons.lightbulb_outline,
      promptBuilder: (items) =>
          'What is the best way to store these items? ${items.join(", ")}',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initAI();
  }

  void _initAI() {
    _aiService = AIService();
    try {
      _aiService.initialize();
      setState(() => _aiReady = true);
      _addBotMessage(
        '👋 Hi! I\'m your Smart Cabinet AI Assistant.\n\n'
        'You can ask me anything about your stored items — '
        'like storage tips, expiry predictions, or how to organise your cabinet.\n\n'
        'Or tap one of the quick actions below to get started!',
      );
    } catch (e) {
      _addBotMessage('⚠️ AI failed to initialise: $e');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Add messages ─────────────────────────────
  void _addBotMessage(String text) {
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: false));
    });
    _scrollToBottom();
  }

  void _addUserMessage(String text) {
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Send a plain text message ─────────────────
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isLoading || !_aiReady) return;

    _messageController.clear();
    _addUserMessage(text);
    await _getAIResponse(text);
  }

  // ── Run a quick action ─────────────────────────
  Future<void> _runQuickAction(_QuickAction action) async {
    if (_isLoading || !_aiReady) return;

    final itemProvider = context.read<ItemProvider>();
    final itemNames =
        itemProvider.items.map((i) => i.name).toList();

    if (itemNames.isEmpty) {
      _addBotMessage(
          '📦 Your cabinet appears to be empty. Add some items first!');
      return;
    }

    final prompt = action.promptBuilder(itemNames);
    _addUserMessage(action.label);
    await _getAIResponse(prompt);
  }

  // ── Core AI call ─────────────────────────────
  Future<void> _getAIResponse(String prompt) async {
    setState(() => _isLoading = true);

    try {
      final response = await _aiService.chat(prompt);
      _addBotMessage(response);
    } catch (e) {
      _addBotMessage('⚠️ Something went wrong: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ════════════════════════════════════════════
  // Build
  // ════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2FFFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2FFFF),
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF4ECDC4).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome,
                  size: 20, color: Color(0xFF4ECDC4)),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Assistant',
                  style: TextStyle(
                    color: Color(0xFF2D3436),
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Powered by Gemini AI',
                  style: TextStyle(
                    color: Color(0xFF636E72),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2D3436)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Color(0xFF636E72)),
            tooltip: 'Clear chat',
            onPressed: () => setState(() {
              _messages.clear();
              _addBotMessage(
                  '🧹 Chat cleared. How can I help you today?');
            }),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Message list ───────────────────────
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return _TypingIndicator();
                      }
                      return _MessageBubble(message: _messages[index]);
                    },
                  ),
          ),

          // ── Quick action chips ─────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _quickActions.map((action) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      avatar: Icon(action.icon,
                          size: 16, color: const Color(0xFF4ECDC4)),
                      label: Text(
                        action.label,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF2D3436)),
                      ),
                      backgroundColor: const Color(0xFF4ECDC4)
                          .withValues(alpha: 0.1),
                      side: BorderSide(
                          color: const Color(0xFF4ECDC4)
                              .withValues(alpha: 0.4)),
                      onPressed: () => _runQuickAction(action),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // ── Input field ────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2FFFF),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: const Color(0xFF4ECDC4)
                              .withValues(alpha: 0.4)),
                    ),
                    child: TextField(
                      controller: _messageController,
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: const InputDecoration(
                        hintText: 'Ask me anything...',
                        hintStyle:
                            TextStyle(color: Color(0xFFB2BEC3)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _isLoading ? null : _sendMessage,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: _isLoading
                          ? Colors.grey.shade300
                          : const Color(0xFF4ECDC4),
                      borderRadius: BorderRadius.circular(23),
                    ),
                    child: _isLoading
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: const Color(0xFF4ECDC4).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(45),
            ),
            child: const Icon(Icons.auto_awesome,
                size: 48, color: Color(0xFF4ECDC4)),
          ),
          const SizedBox(height: 20),
          const Text(
            'AI Assistant Ready',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2D3436),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask about your items or tap a quick action',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════
// Message bubble widget
// ════════════════════════════════════════════
class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF4ECDC4).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.auto_awesome,
                  size: 16, color: Color(0xFF4ECDC4)),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF4ECDC4)
                    : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft:
                      Radius.circular(isUser ? 16 : 4),
                  bottomRight:
                      Radius.circular(isUser ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: isUser
                      ? Colors.white
                      : const Color(0xFF2D3436),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════
// Typing indicator (three bouncing dots)
// ════════════════════════════════════════════
class _TypingIndicator extends StatefulWidget {
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF4ECDC4).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.auto_awesome,
                size: 16, color: Color(0xFF4ECDC4)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) {
                return Row(
                  children: List.generate(3, (i) {
                    final offset =
                        ((_ctrl.value * 3 - i).clamp(0.0, 1.0));
                    final bounce =
                        offset < 0.5 ? offset * 2 : (1 - offset) * 2;
                    return Transform.translate(
                      offset: Offset(0, -4 * bounce),
                      child: Padding(
                        padding:
                            EdgeInsets.only(right: i < 2 ? 4 : 0),
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4ECDC4),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}