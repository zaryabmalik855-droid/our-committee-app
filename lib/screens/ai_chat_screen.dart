import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/state_service.dart';
import '../services/ai_service.dart';
import '../theme/app_theme.dart';

/// Full-screen AI Chat Assistant — Bilingual (Urdu/English)
/// Accessible via FAB from both Member and Manager dashboards.
class AiChatScreen extends StatefulWidget {
  final String agentType; // 'member' | 'manager'
  const AiChatScreen({super.key, this.agentType = 'member'});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatBubble> _messages = [];
  bool _isLoading = false;
  bool _backendOnline = false;
  late AnimationController _typingAnim;
  Timer? _healthCheckTimer;

  @override
  void initState() {
    super.initState();
    _typingAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _checkBackend();
    _startHealthCheckTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showGreeting());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _typingAnim.dispose();
    _healthCheckTimer?.cancel();
    super.dispose();
  }

  void _startHealthCheckTimer() {
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      final online = await AiService.checkHealth();
      if (mounted && online != _backendOnline) {
        setState(() => _backendOnline = online);
      }
    });
  }

  Future<void> _checkBackend() async {
    final online = await AiService.checkHealth();
    if (mounted) setState(() => _backendOnline = online);
  }

  void _showGreeting() {
    final state = context.read<AppStateService>();
    final lang = state.currentLanguage;
    final name = state.currentUser?.name ?? 'User';
    final isUrdu = lang == 'ur';
    final isManager = widget.agentType == 'manager';

    final greeting = isUrdu
        ? (isManager
            ? 'السلام علیکم، $name صاحب! 👔\nمیں آپ کا AI اسسٹنٹ ہوں۔ کمیٹیوں، قرضوں، یا اراکین کے بارے میں پوچھیں۔'
            : 'السلام علیکم، $name! 🌙\nمیں آپ کا AI اسسٹنٹ ہوں۔ ادائیگیوں، کمیٹیوں، یا قرض کے بارے میں پوچھیں۔')
        : (isManager
            ? 'Hello, $name! 👔\nI\'m your AI Manager Assistant.\nAsk me about committees, loans, member payments, or draw results.'
            : 'Hello, $name! 👋\nI\'m your AI assistant for Our Committee.\nAsk me anything about your payments, committees, or loans!');

    setState(() {
      _messages.add(_ChatBubble(
        text: greeting,
        isAi: true,
        timestamp: DateTime.now(),
        isMarkdown: false,
      ));
    });
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty || _isLoading) return;
    _controller.clear();
    final state = context.read<AppStateService>();
    final user = state.currentUser;
    if (user == null) return;

    setState(() {
      _messages.add(_ChatBubble(text: text.trim(), isAi: false, timestamp: DateTime.now()));
      _isLoading = true;
    });
    _scrollToBottom();

    // Build history for context
    final history = _messages
        .where((m) => !m.isTypingIndicator)
        .map((m) => {'role': m.isAi ? 'assistant' : 'user', 'content': m.text})
        .toList();

    final result = await AiService.chat(
      message: text.trim(),
      history: history.length > 1 ? history.sublist(0, history.length - 1) : [],
      user: user,
      committees: state.committees,
      loans: state.loans,
      receipts: state.receipts,
      notifications: state.notifications,
      language: state.currentLanguage,
      emergencyPoolBalance: state.emergencyPoolBalance,
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _backendOnline = result.isFromBackend;
      _messages.add(_ChatBubble(
        text: result.reply,
        isAi: true,
        timestamp: DateTime.now(),
        isMarkdown: true,
        actionsTaken: result.actionsTaken,
      ));
    });
    _scrollToBottom();
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

  void _quickTap(String msg) => _send(msg);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateService>();
    final lang = state.currentLanguage;
    final isUrdu = lang == 'ur';
    final isManager = widget.agentType == 'manager';

    return Scaffold(
      backgroundColor: AppTheme.primaryLight,
      appBar: _buildAppBar(state, isUrdu, isManager),
      body: Column(
        children: [
          // Backend status strip
          if (!_backendOnline)
            Container(
              width: double.infinity,
              color: AppTheme.accentOrange.withOpacity(0.12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.wifi_off_rounded, size: 14, color: AppTheme.accentOrange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isUrdu
                          ? 'Backend آف لائن — سمارٹ موک جوابات دیے جا رہے ہیں'
                          : 'Backend offline — using smart mock responses',
                      style: TextStyle(fontSize: 11, color: AppTheme.accentOrange),
                    ),
                  ),
                ],
              ),
            ),
          // AI Disclosure banner
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.accentOrange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.accentOrange.withOpacity(0.25),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppTheme.accentOrange,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isUrdu
                        ? 'وارننگ: یہ سروس مصنوعی ذہانت (AI) پر مبنی ہے۔ مالیاتی فیصلوں اور معلومات کی دستی توثیق لازمی کریں۔'
                        : 'Disclaimer: Powered by AI. Financial summaries, notifications, and risk checks are AI-generated. Please verify details manually.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (ctx, i) {
                if (_isLoading && i == _messages.length) {
                  return _TypingIndicator(animation: _typingAnim);
                }
                return _buildBubble(_messages[i], isUrdu);
              },
            ),
          ),
          // Quick chips (RAG services) shown right at the top of the text box
          _buildQuickChips(isUrdu, isManager),
          // Input bar
          _buildInputBar(isUrdu),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AppStateService state, bool isUrdu, bool isManager) {
    return AppBar(
      backgroundColor: AppTheme.secondaryLight,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.accentTeal, AppTheme.accentGreen],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isManager ? Icons.manage_accounts_rounded : Icons.smart_toy_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isUrdu
                    ? (isManager ? 'منیجر AI اسسٹنٹ' : 'AI اسسٹنٹ')
                    : (isManager ? 'Manager AI' : 'AI Assistant'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: _backendOnline ? AppTheme.accentGreen : AppTheme.accentOrange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Text(
                    _backendOnline
                        ? (isUrdu ? 'آن لائن' : 'Online')
                        : (isUrdu ? 'آف لائن' : 'Offline'),
                    style: TextStyle(
                      fontSize: 10,
                      color: _backendOnline ? AppTheme.accentGreen : AppTheme.accentOrange,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        // Language toggle
        GestureDetector(
          onTap: () => context.read<AppStateService>().toggleLanguage(),
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.accentTeal, AppTheme.accentGreen],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              state.currentLanguage == 'en' ? 'اُردو' : 'EN',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickChips(bool isUrdu, bool isManager) {
    final chips = isManager
        ? (isUrdu
            ? ['📋 زیر التواء قرضے', '🏦 کمیٹی خلاصہ', '👥 ممبر ادائیگیاں', '🎯 لکی ڈرا']
            : ['📋 Pending Loans', '🏦 Committee Summary', '👥 Member Payments', '🎯 Lucky Draw'])
        : (isUrdu
            ? ['💳 میری ادائیگیاں', '🏦 میری کمیٹیاں', '💰 قرض کی حیثیت', '💵 بیلنس']
            : ['💳 My Payments', '🏦 My Committees', '💰 Loan Status', '💵 My Balance']);

    final messages = isManager
        ? (isUrdu
            ? ['زیر التواء قرض درخواستیں دکھائیں', 'کمیٹیوں کا خلاصہ دیں', 'ممبران کی ادائیگیوں کا جائزہ', 'لکی ڈرا کے اہل ممبران']
            : ['Show pending loan requests', 'Give me a committee performance summary', 'Review member payment history', 'Who is eligible for the lucky draw?'])
        : (isUrdu
            ? ['میری آخری 3 ادائیگیاں دکھائیں', 'میری کمیٹیوں کی فہرست دیں', 'میرے قرض کی صورتحال بتائیں', 'میرا والیٹ بیلنس کتنا ہے؟']
            : ['Show my last 3 payments', 'List my committees with progress', 'What is my loan status?', 'What is my wallet balance?']);

    return Container(
      height: 48,
      color: AppTheme.secondaryLight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) => GestureDetector(
          onTap: () => _quickTap(messages[i]),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.accentTeal.withOpacity(0.1),
                  AppTheme.accentGreen.withOpacity(0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.accentTeal.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Text(
              chips[i],
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.accentTeal,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBubble(_ChatBubble bubble, bool isUrdu) {
    if (bubble.isAi) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12, right: 40),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // AI avatar
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.accentTeal, AppTheme.accentGreen],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 18),
            ),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Actions taken badges
                  if (bubble.actionsTaken.isNotEmpty)
                    Wrap(
                      spacing: 4,
                      children: bubble.actionsTaken.map((a) => Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.accentTeal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '⚡ $a',
                          style: TextStyle(
                            fontSize: 9,
                            color: AppTheme.accentTeal,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )).toList(),
                    ),
                  // Bubble
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryLight,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(18),
                        bottomLeft: Radius.circular(18),
                        bottomRight: Radius.circular(18),
                      ),
                      border: Border.all(color: AppTheme.borderLight, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: bubble.isMarkdown
                        ? MarkdownBody(
                            data: bubble.text,
                            styleSheet: MarkdownStyleSheet(
                              p: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.textPrimary,
                                height: 1.6,
                              ),
                              strong: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                              code: const TextStyle(
                                fontFamily: 'monospace',
                                backgroundColor: Color(0xFFF1F5F9),
                                fontSize: 12,
                              ),
                              blockquote: TextStyle(
                                color: AppTheme.textSecondary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          )
                        : Text(
                            bubble.text,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textPrimary,
                              height: 1.6,
                            ),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Text(
                      _formatTime(bubble.timestamp),
                      style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // User bubble
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.accentTeal, AppTheme.accentGreen],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(4),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentTeal.withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    bubble.text,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      height: 1.5,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, right: 4),
                  child: Text(
                    _formatTime(bubble.timestamp),
                    style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(bool isUrdu) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: BoxDecoration(
        color: AppTheme.secondaryLight,
        border: const Border(top: BorderSide(color: AppTheme.borderLight, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                onSubmitted: _send,
                textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.send,
                decoration: InputDecoration(
                  hintText: isUrdu
                      ? 'اپنا سوال یہاں لکھیں...'
                      : 'Ask anything about your committee...',
                  hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  filled: true,
                  fillColor: AppTheme.primaryLight,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: AppTheme.borderLight),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: AppTheme.borderLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: AppTheme.accentTeal, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: Material(
                color: _isLoading
                    ? AppTheme.borderLight
                    : AppTheme.accentTeal,
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: _isLoading ? null : () => _send(_controller.text),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentTeal),
                            ),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ── Data model for chat bubbles ───────────────────────────────────

class _ChatBubble {
  final String text;
  final bool isAi;
  final DateTime timestamp;
  final bool isMarkdown;
  final List<String> actionsTaken;
  final bool isTypingIndicator;

  const _ChatBubble({
    required this.text,
    required this.isAi,
    required this.timestamp,
    this.isMarkdown = false,
    this.actionsTaken = const [],
    this.isTypingIndicator = false,
  });
}

// ── Typing indicator widget ───────────────────────────────────────

class _TypingIndicator extends StatelessWidget {
  final AnimationController animation;
  const _TypingIndicator({required this.animation});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 40),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.accentTeal, AppTheme.accentGreen],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 18),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.secondaryLight,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (ctx, _) {
                    final offset = (i * 0.3);
                    final value = ((animation.value + offset) % 1.0);
                    final opacity = value < 0.5 ? value * 2 : (1 - value) * 2;
                    return Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.accentTeal.withOpacity(0.3 + opacity * 0.7),
                        shape: BoxShape.circle,
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
