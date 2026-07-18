import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/state_service.dart';
import '../models/user.dart';
import '../models/committee.dart';
import '../widgets/custom_widgets.dart';
import '../widgets/lucky_draw_wheel.dart';
import '../theme/app_theme.dart';
import 'auth_screen.dart';
import 'ai_chat_screen.dart';
import '../services/ai_service.dart';

class ManagerDashboard extends StatefulWidget {
  const ManagerDashboard({super.key});

  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard> {
  int _currentIndex = 0;
  String _cycleFrequency = 'monthly';
  bool _isRefreshingWallet = false;
  String? _selectedChatCommitteeId;
  // AI assistant state
  bool _isLoadingAiAnalytics = false;
  String _aiAnalyticsSummary = '';
  bool _isAiAnalyticsExpanded = false;
  String? _selectedRadioCommitteeId;

  // Create Committee Form Controllers
  final _commNameController = TextEditingController();
  final _commDescController = TextEditingController();
  final _commTotalController = TextEditingController();
  final _commContribController = TextEditingController();
  final _commLimitController = TextEditingController();
  final _commFormKey = GlobalKey<FormState>();

  // Chat Controller
  final _chatController = TextEditingController();
  final _chatScrollController = ScrollController();

  // Payment Controllers
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _commContribController.addListener(_updateTotalPayout);
    _commLimitController.addListener(_updateTotalPayout);
  }

  void _updateTotalPayout() {
    final double? contrib = double.tryParse(_commContribController.text);
    final int? limit = int.tryParse(_commLimitController.text);
    if (contrib != null && limit != null) {
      final double total = contrib * limit;
      _commTotalController.text = total.toStringAsFixed(0);
    } else {
      _commTotalController.text = '';
    }
  }

  @override
  void dispose() {
    _commContribController.removeListener(_updateTotalPayout);
    _commLimitController.removeListener(_updateTotalPayout);
    _commNameController.dispose();
    _commDescController.dispose();
    _commTotalController.dispose();
    _commContribController.dispose();
    _commLimitController.dispose();
    _chatController.dispose();
    _chatScrollController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateService>();
    final user = state.currentUser;

    if (user == null) {
      return const AuthScreen();
    }

    final List<Widget> tabs = [
      _buildHomeTab(state),
      _buildCreateCommitteeTab(state),
      _buildChatsTab(state),
      _buildSettingsTab(state),
    ];

    return Scaffold(
      // ── AI Assistant FAB ─────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AiChatScreen(agentType: 'manager'),
            ),
          );
        },
        backgroundColor: AppTheme.accentTeal,
        foregroundColor: AppTheme.primaryDark,
        icon: const Icon(Icons.smart_toy_rounded),
        label: Text(
          state.currentLanguage == 'ur' ? 'AI منیجر' : 'AI Manager',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 4,
      ),
      appBar: AppBar(
        title: Text(state.translate('app_title')),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: InkWell(
              onTap: () => _showProfileDialog(context, state),
              borderRadius: BorderRadius.circular(18),
              child: CircleAvatar(
                backgroundColor: AppTheme.accentTeal,
                radius: 18,
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : "M",
                  style: const TextStyle(
                    color: AppTheme.primaryDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppTheme.secondaryDark,
        selectedItemColor: AppTheme.accentTeal,
        unselectedItemColor: AppTheme.textSecondary,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.dashboard_rounded),
            label: state.translate('home'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.add_circle_outline_rounded),
            label: state.translate('create_committee'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            label: state.translate('chats'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings_outlined),
            label: state.translate('settings'),
          ),
        ],
      ),
    );
  }

  // ==================== HOME TAB ====================
  Widget _buildHomeTab(AppStateService state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Greeting & Premium Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ScaledText(
                    "Assalam-o-Alaikum,",
                    style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                  ),
                  ScaledText(
                    state.currentUser?.name ?? "Manager",
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accentGold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.accentGold, width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.workspace_premium, color: AppTheme.accentGold, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      state.currentUser?.subscriptionPlan.toUpperCase() ?? "PREMIUM",
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accentGold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),

          // Wallet Balance Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D9488), Color(0xFF10B981)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 28),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Wallet Account Balance",
                          style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "PKR ${state.currentUser?.balance.toStringAsFixed(2) ?? '0.00'}",
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => _showReceiptsSheet(context, state),
                  icon: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 16),
                  label: const Text(
                    "Receipts",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white24,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),

          // Manager Quick Action Panels: Committee list vs Loan List toggle sheets
          Row(
            children: [
              Expanded(
                child: _buildQuickButton(
                  title: "Committees",
                  count: "${state.committees.length} Active",
                  icon: Icons.pie_chart_outline_rounded,
                  color: AppTheme.accentTeal,
                  onTap: () => _showCommitteesListSheet(state),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildQuickButton(
                  title: "Loan Requests",
                  count: "${state.loans.where((l) => l.status == 'pending').length} Pending",
                  icon: Icons.payments_outlined,
                  color: AppTheme.accentGreen,
                  onTap: () => _showLoansListSheet(state),
                ),
              ),

            ],
          ),
          const SizedBox(height: 30),

          // Emergency Support Pool Card
          PremiumCard(
            gradientColors: const [Color(0xFF0F172A), Color(0xFF1E293B)],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.health_and_safety_rounded, color: AppTheme.accentOrange, size: 24),
                        SizedBox(width: 8),
                        Text(
                          "Emergency Support Pool",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accentOrange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        "Community Aid Pool",
                        style: TextStyle(fontSize: 9, color: AppTheme.accentOrange, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Available Balance", style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        const SizedBox(height: 2),
                        Text(
                          "PKR ${state.emergencyPoolBalance.toStringAsFixed(2)}",
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.accentGreen),
                        ),
                      ],
                    ),

                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          // Central CTA - Custom Lucky Draw spinner trigger card
          PremiumCard(
            gradientColors: const [Color(0xFF1E1B4B), Color(0xFF0F172A)],
            child: Builder(builder: (context) {
              final hasCommittees = state.committees.isNotEmpty;
              final canDraw = hasCommittees && state.committees.any((c) => state.canPerformDraw(c.id) && c.status != 'completed' && c.drawWinners.length < c.joinedMembers.length);
              
              DateTime? earliestNextDraw;
              for (var c in state.committees) {
                if (c.status != 'completed' && c.drawWinners.length < c.joinedMembers.length) {
                  final nextDate = state.nextDrawAllowedAt(c.id);
                  if (nextDate != null) {
                    if (earliestNextDraw == null || nextDate.isBefore(earliestNextDraw)) {
                      earliestNextDraw = nextDate;
                    }
                  }
                }
              }
              final nextDrawStr = earliestNextDraw != null
                  ? "${earliestNextDraw.day}/${earliestNextDraw.month}/${earliestNextDraw.year}"
                  : "Next cycle";

              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Time for Lucky Draw?",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          canDraw
                              ? "Launch the spinning wheel to pick this cycle's rotating payout winner fairly."
                              : "Next draw allowed on: $nextDrawStr",
                          style: TextStyle(
                            fontSize: 11,
                            color: canDraw ? AppTheme.textSecondary : AppTheme.accentOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canDraw ? AppTheme.accentGold : AppTheme.borderDark,
                      foregroundColor: AppTheme.primaryDark,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                    child: Text(canDraw ? "Launch Draw" : "Locked"),
                    onPressed: canDraw ? () => _navigateToWheelScreen(state) : null,
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 30),

          // ── AI Analytics Card ──────────────────────────────────────
          _buildAiAnalyticsCard(state),
          const SizedBox(height: 30),

          // Notification Alert Panel
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ScaledText(
                state.translate('recent_notifications'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const Icon(Icons.notifications_active_outlined, color: AppTheme.accentTeal, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          
          if (state.notifications.isEmpty) ...[
            const Center(child: Text("No alerts active.")),
          ] else ...[
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.notifications.take(3).length,
              itemBuilder: (context, idx) {
                final notif = state.notifications[idx];
                IconData leadingIcon = Icons.notifications_none_rounded;
                Color notifColor = AppTheme.accentTeal;
                
                if (notif.type == 'payment') {
                  leadingIcon = Icons.currency_rupee_rounded;
                  notifColor = AppTheme.accentGreen;
                } else if (notif.type == 'draw') {
                  leadingIcon = Icons.stars_rounded;
                  notifColor = AppTheme.accentGold;
                } else if (notif.type == 'loan') {
                  leadingIcon = Icons.monetization_on_outlined;
                  notifColor = AppTheme.accentOrange;
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  color: AppTheme.secondaryDark.withOpacity(0.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppTheme.borderDark, width: 0.5),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: notifColor.withOpacity(0.1),
                      child: Icon(leadingIcon, color: notifColor, size: 20),
                    ),
                    title: Text(
                      notif.title,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    subtitle: Text(
                      notif.body,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  // ==================== AI ANALYTICS CARD ====================
  Widget _buildAiAnalyticsCard(AppStateService state) {
    final isUrdu = state.currentLanguage == 'ur';
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.accentTeal, AppTheme.accentGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentTeal.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.analytics_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    isUrdu ? 'AI کارکردگی کا جائزہ' : 'AI Performance Analytics',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isUrdu ? 'GEMINI' : 'GEMINI',
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: 0,
              maxHeight: _isAiAnalyticsExpanded ? 350.0 : 120.0,
            ),
            child: Scrollbar(
              thumbVisibility: _aiAnalyticsSummary.isNotEmpty && _aiAnalyticsSummary.length > 120,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                    _isLoadingAiAnalytics
                        ? (isUrdu ? 'کمیٹیوں کا جائزہ لیا جا رہا ہے...' : 'Analyzing committee performance...')
                        : (_aiAnalyticsSummary.isNotEmpty
                            ? _aiAnalyticsSummary
                            : (isUrdu
                                ? 'تمام کمیٹیوں، قرضوں اور ادائیگیوں کی صورتحال جاننے کے لیے AI سے تجزیہ لیں۔'
                                : 'Get an AI-generated summary of all your committees, pending loans, and total pool health.')),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                    softWrap: true,
                  ),
                ),
              ),
            ),
          ),
          if (_aiAnalyticsSummary.isNotEmpty && _aiAnalyticsSummary.length > 120) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _isAiAnalyticsExpanded = !_isAiAnalyticsExpanded),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _isAiAnalyticsExpanded
                        ? (isUrdu ? 'کم دکھائیں' : 'Show Less')
                        : (isUrdu ? 'مزید پڑھیں' : 'Read More'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  Icon(
                    _isAiAnalyticsExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AiChatScreen(agentType: 'manager'),
                    ),
                  ),
                  icon: const Icon(Icons.manage_accounts_rounded, size: 16),
                  label: Text(isUrdu ? 'منیجر AI کھولیں' : 'Open Manager AI'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.accentTeal,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _isLoadingAiAnalytics
                    ? null
                    : () => _fetchAiAnalytics(state),
                icon: _isLoadingAiAnalytics
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.insights_rounded, size: 16),
                label: Text(isUrdu ? 'تجزیہ' : 'Analyze'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white24,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _fetchAiAnalytics(AppStateService state) async {
    if (_isLoadingAiAnalytics) return;
    setState(() => _isLoadingAiAnalytics = true);
    final user = state.currentUser;
    if (user == null) {
      setState(() => _isLoadingAiAnalytics = false);
      return;
    }
    final lang = state.currentLanguage;
    final result = await AiService.chat(
      message: lang == 'ur'
          ? 'منیجر کی حیثیت سے میری تمام کمیٹیوں، زیر التواء قرضوں اور کل رقم کا ایک مختصر جائزہ دیں'
          : 'As a manager, give me a brief summary of all my committees, pending loans, and total pool value in 2 sentences',
      history: [],
      user: user,
      committees: state.committees,
      loans: state.loans,
      receipts: state.receipts,
      notifications: state.notifications,
      language: lang,
      emergencyPoolBalance: state.emergencyPoolBalance,
    );
    if (mounted) {
      setState(() {
        _aiAnalyticsSummary = result.reply;
        _isLoadingAiAnalytics = false;
      });
    }
  }

  Widget _buildQuickButton({
    required String title,
    required String count,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.secondaryDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.borderDark, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              count,
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== TABS SHEET DISPLAYS ====================
  void _showCommitteesListSheet(AppStateService state) {
    final Map<String, String> selectedMemberForCommittee = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final state = Provider.of<AppStateService>(context);

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: AppTheme.primaryDark,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                border: Border(top: BorderSide(color: AppTheme.borderDark, width: 1.5)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Managed Committees", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: state.committees.length,
                      itemBuilder: (context, idx) {
                        final comm = state.committees[idx];
                        
                        // Filter registered users who are NOT in the committee yet
                        final eligibleUsers = state.users
                            .where((u) => !comm.joinedMembers.any((mName) => mName.toLowerCase() == u.name.toLowerCase()))
                            .toList();

                        String? selectedUser = selectedMemberForCommittee[comm.id];
                        if (selectedUser == null && eligibleUsers.isNotEmpty) {
                          selectedUser = eligibleUsers.first.name;
                          selectedMemberForCommittee[comm.id] = selectedUser;
                        }

                        // Calculate manager's personal contribution status if enrolled
                        final managerEmail = state.currentUser?.email ?? "";
                        final isManagerJoined = comm.joinedMembers.contains(state.currentUser?.name);
                        final personalInstallments = state.receipts
                            .where((r) => r.userEmail == managerEmail && r.referenceId == comm.id && r.type == 'Committee Installment')
                            .length;

                        return PremiumCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(comm.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppTheme.accentTeal.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(comm.status.toUpperCase(), style: const TextStyle(fontSize: 9, color: AppTheme.accentTeal, fontWeight: FontWeight.bold)),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: _getLuckyDrawStatusColor(state.getLuckyDrawStatus(comm.id)).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: _getLuckyDrawStatusColor(state.getLuckyDrawStatus(comm.id)), width: 0.8),
                                        ),
                                        child: Text(
                                          state.getLuckyDrawStatus(comm.id).toUpperCase(),
                                          style: TextStyle(fontSize: 9, color: _getLuckyDrawStatusColor(state.getLuckyDrawStatus(comm.id)), fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(comm.description, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("Monthly Payout: PKR ${comm.totalAmount.toStringAsFixed(0)}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  Text("Contribution: PKR ${comm.monthlyContribution.toStringAsFixed(0)}", style: const TextStyle(fontSize: 11, color: AppTheme.accentTeal)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text("Members: ${comm.joinedMembers.length} / ${comm.membersLimit}", style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                              const SizedBox(height: 10),
                              const Text(
                                "Joined Members:",
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: comm.joinedMembers.map((m) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentTeal.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.accentTeal.withOpacity(0.25), width: 0.8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.person_outline, size: 10, color: AppTheme.accentTeal),
                                      const SizedBox(width: 4),
                                      Text(
                                        m,
                                        style: const TextStyle(fontSize: 10, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(width: 6),
                                      GestureDetector(
                                        onTap: () {
                                          final success = state.removeMemberFromCommittee(comm.id, m);
                                          if (success) {
                                            setSheetState(() {});
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text("Removed $m from committee"),
                                                backgroundColor: AppTheme.accentGreen,
                                              ),
                                            );
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text("Failed to remove member"),
                                                backgroundColor: Colors.redAccent,
                                              ),
                                            );
                                          }
                                        },
                                        child: const Icon(
                                          Icons.close_rounded,
                                          size: 12,
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                )).toList(),
                              ),

                              // Dropdown & add member button
                              if (eligibleUsers.isNotEmpty && comm.joinedMembers.length < comm.membersLimit) ...[
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        value: selectedUser,
                                        dropdownColor: AppTheme.secondaryDark,
                                        isExpanded: true,
                                        decoration: const InputDecoration(
                                          labelText: "Enroll Register Member",
                                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                        items: eligibleUsers.map((u) {
                                          return DropdownMenuItem<String>(
                                            value: u.name,
                                            child: Text(
                                              "${u.name} (${u.role == UserRole.manager ? 'Manager' : 'Member'})",
                                              style: const TextStyle(fontSize: 11),
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setSheetState(() {
                                              selectedMemberForCommittee[comm.id] = val;
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.accentTeal,
                                        foregroundColor: AppTheme.primaryDark,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      ),
                                      onPressed: () {
                                        final nameToAdd = selectedMemberForCommittee[comm.id];
                                        if (nameToAdd != null) {
                                          final success = state.addMemberToCommittee(comm.id, nameToAdd);
                                          if (success) {
                                            selectedMemberForCommittee.remove(comm.id);
                                            setSheetState(() {});
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text("Added $nameToAdd to committee"),
                                                backgroundColor: AppTheme.accentGreen,
                                              ),
                                            );
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text("Failed to add member"),
                                                backgroundColor: Colors.redAccent,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      child: const Text("ADD", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ] else if (comm.joinedMembers.length >= comm.membersLimit) ...[
                                const SizedBox(height: 12),
                                const Text(
                                  "Capacity Limit Reached",
                                  style: TextStyle(fontSize: 10, color: AppTheme.accentGold, fontStyle: FontStyle.italic),
                                ),
                              ],

                              // Manager payment option
                              if (isManagerJoined) ...[
                                const SizedBox(height: 12),
                                const Divider(color: AppTheme.borderDark),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "Manager Contribution Status:",
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                                    ),
                                    Text(
                                      "$personalInstallments / ${comm.totalInstallments} Paid",
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.accentGreen),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (personalInstallments < comm.totalInstallments)
                                  Builder(builder: (context) {
                                    final bool isAllowedToPay = state.canPayInstallment(comm.id);
                                    final nextAllowedDate = state.nextInstallmentAllowedAt(comm.id);
                                    final String nextAllowedStr = nextAllowedDate != null 
                                        ? "${nextAllowedDate.day}/${nextAllowedDate.month}/${nextAllowedDate.year}" 
                                        : "";

                                    return SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        icon: Icon(isAllowedToPay ? Icons.payment_rounded : Icons.check_circle_outline, size: 14),
                                        label: Text(isAllowedToPay
                                          ? "PAY MY INSTALLMENT (PKR ${comm.monthlyContribution.toStringAsFixed(0)})"
                                          : "PAID FOR THIS CYCLE (Next: $nextAllowedStr)",
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isAllowedToPay ? AppTheme.accentGreen : AppTheme.borderDark,
                                          foregroundColor: isAllowedToPay ? AppTheme.primaryDark : AppTheme.textSecondary,
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                        ),
                                        onPressed: () {
                                          if (!isAllowedToPay) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text("You have already paid your installment for this cycle. Next payment is allowed on or after $nextAllowedStr."),
                                                backgroundColor: AppTheme.accentOrange,
                                                behavior: SnackBarBehavior.floating,
                                              ),
                                            );
                                            return;
                                          }
                                          if (state.currentUser!.balance < comm.monthlyContribution) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text("Insufficient wallet balance. Please add funds."),
                                                backgroundColor: Colors.redAccent,
                                                behavior: SnackBarBehavior.floating,
                                              ),
                                            );
                                            return;
                                          }
                                          _triggerCommitteePaymentDialog(context, state, comm);
                                        },
                                      ),
                                    );
                                  })
                                else
                                  const Center(
                                    child: Text(
                                      "My Contributions Completed!",
                                      style: TextStyle(fontSize: 12, color: AppTheme.accentGreen, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ]
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showLoansListSheet(AppStateService state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final double scale = Provider.of<AppStateService>(context).fontMultiplier;
            
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: AppTheme.primaryDark,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                border: Border(top: BorderSide(color: AppTheme.borderDark, width: 1.5)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Loan Applications Received", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: state.loans.length,
                      itemBuilder: (context, idx) {
                        final loan = state.loans[idx];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          color: AppTheme.secondaryDark,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: AppTheme.borderDark),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      loan.applicantName,
                                      style: TextStyle(fontSize: 15.0 * scale, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                    ),
                                    Text(
                                      "PKR ${loan.amount.toStringAsFixed(0)}",
                                      style: TextStyle(fontSize: 15.0 * scale, fontWeight: FontWeight.bold, color: AppTheme.accentGreen),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text("Reason: ${loan.reason}", style: TextStyle(fontSize: 11.0 * scale, color: AppTheme.textSecondary)),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("Repayment Option: PKR ${loan.monthlyRepayment.toStringAsFixed(0)} / mo", style: TextStyle(fontSize: 11.0 * scale, color: AppTheme.accentTeal)),
                                    Text("Duration: ${loan.durationMonths} months", style: TextStyle(fontSize: 11.0 * scale, color: AppTheme.textSecondary)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("Status: ${loan.status.toUpperCase()}", style: TextStyle(fontSize: 11.0 * scale, fontWeight: FontWeight.bold, color: _getLoanStatusColor(loan.status))),
                                    if (loan.status == 'pending') ...[
                                      Row(
                                        children: [
                                          TextButton(
                                            onPressed: () {
                                              state.updateLoanStatus(loan.id, 'rejected');
                                              setSheetState(() {});
                                            },
                                            child: const Text("REJECT", style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppTheme.accentGreen,
                                              foregroundColor: AppTheme.primaryDark,
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            ),
                                            onPressed: () {
                                              showDialog(
                                                context: context,
                                                builder: (dialogCtx) => AlertDialog(
                                                  backgroundColor: AppTheme.secondaryDark,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                  title: const Row(
                                                    children: [
                                                      Icon(Icons.health_and_safety_rounded, color: AppTheme.accentGreen),
                                                      SizedBox(width: 8),
                                                      Text("Confirm Disbursal", style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
                                                    ],
                                                  ),
                                                  content: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text("Are you sure you want to approve this loan and disburse PKR ${loan.amount.toStringAsFixed(0)} directly from the Emergency Pool?", style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                                      const SizedBox(height: 16),
                                                      const Text("Applicant Details:", style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                                                      const SizedBox(height: 8),
                                                      Text("Name: ${loan.applicantName}", style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                                      Text("Amount Requested: PKR ${loan.amount.toStringAsFixed(0)}", style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                                      Text("Reason: ${loan.reason}", style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                                      Text("Repayment Option: PKR ${loan.monthlyRepayment.toStringAsFixed(0)} / mo", style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                                      Text("Duration: ${loan.durationMonths} months", style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                                    ],
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(dialogCtx),
                                                      child: const Text("CANCEL", style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                                                    ),
                                                    ElevatedButton(
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: AppTheme.accentGreen,
                                                        foregroundColor: AppTheme.primaryDark,
                                                      ),
                                                      onPressed: () {
                                                        Navigator.pop(dialogCtx);
                                                        if (state.emergencyPoolBalance < loan.amount) {
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            const SnackBar(
                                                              content: Text("Warning: Pool balance is low, but proceeding with approval.", style: TextStyle(color: Colors.white)),
                                                              backgroundColor: AppTheme.accentOrange,
                                                            )
                                                          );
                                                        }
                                                        state.updateLoanStatus(loan.id, 'approved');
                                                        setSheetState(() {});
                                                      },
                                                      child: const Text("CONFIRM & DISBURSE", style: TextStyle(fontWeight: FontWeight.bold)),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                            child: const Text("APPROVE", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }



  Color _getLoanStatusColor(String status) {
    if (status == 'approved') return AppTheme.accentGreen;
    if (status == 'rejected') return Colors.redAccent;
    return AppTheme.accentGold;
  }

  // ==================== CREATE COMMITTEE TAB ====================
  Widget _buildCreateCommitteeTab(AppStateService state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _commFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.add_home_work_outlined, size: 50, color: AppTheme.accentTeal),
            const SizedBox(height: 10),
            ScaledText(
              state.translate('create_committee'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            ScaledText(
              "Set target payouts, contribution rates, and capacities to enroll members.",
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 25),

            CustomTextField(
              labelText: "Committee Name",
              hintText: "e.g. Roshan Savings Pool",
              prefixIcon: Icons.drive_file_rename_outline_rounded,
              controller: _commNameController,
              validator: (v) => (v == null || v.isEmpty) ? "Name required" : null,
            ),
            const SizedBox(height: 16),

            CustomTextField(
              labelText: "Description",
              hintText: "What are the rules/saving goals of this bisi?",
              prefixIcon: Icons.description_outlined,
              controller: _commDescController,
              validator: (v) => (v == null || v.isEmpty) ? "Description required" : null,
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _cycleFrequency,
              dropdownColor: AppTheme.secondaryDark,
              decoration: const InputDecoration(
                labelText: "Savings Cycle Frequency",
                prefixIcon: Icon(Icons.calendar_today_rounded, color: AppTheme.accentTeal),
              ),
              items: const [
                DropdownMenuItem(value: 'daily', child: Text("Daily Cycle")),
                DropdownMenuItem(value: 'weekly', child: Text("Weekly Cycle")),
                DropdownMenuItem(value: 'monthly', child: Text("Monthly Cycle")),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _cycleFrequency = val;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            CustomTextField(
              labelText: "${_cycleFrequency[0].toUpperCase()}${_cycleFrequency.substring(1)} Contribution per Member (PKR)",
              hintText: "e.g. 10000",
              prefixIcon: Icons.monetization_on_outlined,
              controller: _commContribController,
              keyboardType: TextInputType.number,
              validator: (v) => (v == null || double.tryParse(v) == null) ? "Enter valid contribution PKR" : null,
            ),
            const SizedBox(height: 16),

            CustomTextField(
              labelText: "Members Capacity Limit",
              hintText: "e.g. 10",
              prefixIcon: Icons.people_outline_rounded,
              controller: _commLimitController,
              keyboardType: TextInputType.number,
              validator: (v) => (v == null || int.tryParse(v) == null) ? "Enter valid member count" : null,
            ),
            const SizedBox(height: 16),

            CustomTextField(
              labelText: "Total Target Payout (PKR) [Auto-Calculated]",
              hintText: "Calculated automatically",
              prefixIcon: Icons.account_balance_wallet_outlined,
              controller: _commTotalController,
              keyboardType: TextInputType.number,
              readOnly: true,
              validator: (v) => (v == null || double.tryParse(v) == null) ? "Enter valid target PKR" : null,
            ),
            const SizedBox(height: 30),

            GradientButton(
              text: state.translate('create_committee'),
              onPressed: () {
                if (!_commFormKey.currentState!.validate()) return;
                
                final total = double.parse(_commTotalController.text);
                final contrib = double.parse(_commContribController.text);
                final limit = int.parse(_commLimitController.text);
                
                state.createCommittee(
                  _commNameController.text,
                  _commDescController.text,
                  total,
                  contrib,
                  limit,
                  _cycleFrequency,
                );
                
                _commNameController.clear();
                _commDescController.clear();
                _commTotalController.clear();
                _commContribController.clear();
                _commLimitController.clear();
                
                setState(() {
                  _cycleFrequency = 'monthly';
                  _currentIndex = 0; // Return to Home dashboard
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Committee Launched Successfully!"),
                    backgroundColor: AppTheme.accentGreen,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==================== CHAT TAB ====================
  Widget _buildChatsTab(AppStateService state) {
    if (_selectedChatCommitteeId == null) {
      return _buildChatCommitteeSelectionView(state);
    }

    final selectedComm = state.committees.firstWhere((c) => c.id == _selectedChatCommitteeId, orElse: () => state.committees.first);
    final filteredChats = state.chatHistory.where((c) => c.committeeId == _selectedChatCommitteeId).toList();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.jumpTo(_chatScrollController.position.maxScrollExtent);
      }
    });

    return Column(
      children: [
        // Topic Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: AppTheme.secondaryDark.withOpacity(0.5),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.accentTeal),
                onPressed: () {
                  setState(() {
                    _selectedChatCommitteeId = null;
                  });
                },
              ),
              const CircleAvatar(
                backgroundColor: AppTheme.accentTeal,
                child: Icon(Icons.forum_rounded, color: AppTheme.primaryDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(selectedComm.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text("${selectedComm.joinedMembers.length} Members active in chat", style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedChatCommitteeId = null;
                  });
                },
                icon: const Icon(Icons.swap_horiz_rounded, size: 16, color: AppTheme.accentTeal),
                label: const Text("Switch", style: TextStyle(fontSize: 11, color: AppTheme.accentTeal, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),

        // Chat Bubble Logs List
        Expanded(
          child: filteredChats.isEmpty
              ? const Center(
                  child: Text(
                    "No messages in this committee room yet.\nBe the first to post!",
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  controller: _chatScrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredChats.length,
                  itemBuilder: (context, idx) {
                    final chat = filteredChats[idx];
                    final bool isMe = chat.senderName == state.currentUser?.name;
                    
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isMe ? AppTheme.accentTeal : AppTheme.secondaryDark,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(0),
                            bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
                          ),
                          border: Border.all(color: AppTheme.borderDark, width: 0.5),
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isMe)
                              Text(
                                "${chat.senderName} (${chat.senderRole.toUpperCase()})",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: chat.senderRole == 'manager' ? AppTheme.accentGold : AppTheme.accentTeal,
                                ),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              chat.message,
                              style: TextStyle(
                                color: isMe ? AppTheme.primaryDark : AppTheme.textPrimary,
                                fontSize: 13,
                                fontWeight: isMe ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Input bottom bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: AppTheme.secondaryDark,
            border: Border(top: BorderSide(color: AppTheme.borderDark, width: 1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  style: const TextStyle(color: Colors.black, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "Write message to members...",
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  onSubmitted: (_) {
                    if (_chatController.text.trim().isNotEmpty) {
                      state.postChatMessage(_chatController.text, _selectedChatCommitteeId!);
                      _chatController.clear();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: AppTheme.accentTeal,
                child: IconButton(
                  icon: const Icon(Icons.send_rounded, color: AppTheme.primaryDark, size: 20),
                  onPressed: () {
                    if (_chatController.text.trim().isNotEmpty) {
                      state.postChatMessage(_chatController.text, _selectedChatCommitteeId!);
                      _chatController.clear();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== SETTINGS TAB ====================
  Widget _buildSettingsTab(AppStateService state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Profile quick view card
          PremiumCard(
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.accentTeal,
                  radius: 30,
                  child: Text(
                    state.currentUser?.name[0].toUpperCase() ?? "U",
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(state.currentUser?.name ?? "User", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text("CNIC: ${state.currentUser?.cnic ?? 'Not Provided'}", style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      Text("Phone: ${state.currentUser?.phone ?? 'Not Provided'}", style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const Text("Connected Wallet Accounts", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          if (state.currentUser?.linkedProvider == null) ...[
            _buildSettingsOptionCard(
              title: "Connect JazzCash",
              subtitle: "Sync with your JazzCash mobile wallet",
              icon: Icons.account_balance_wallet_outlined,
              action: const Icon(Icons.link_rounded, color: AppTheme.accentTeal),
              onTap: () => _showLinkWalletSheet(context, state, 'JazzCash'),
            ),
            const SizedBox(height: 12),
            _buildSettingsOptionCard(
              title: "Connect Easypaisa",
              subtitle: "Sync with your Easypaisa mobile wallet",
              icon: Icons.account_balance_wallet_outlined,
              action: const Icon(Icons.link_rounded, color: AppTheme.accentTeal),
              onTap: () => _showLinkWalletSheet(context, state, 'Easypaisa'),
            ),
          ] else ...[
            _buildSettingsOptionCard(
              title: "Linked Wallet: ${state.currentUser!.linkedProvider}",
              subtitle: "Account: ${state.currentUser!.linkedAccountNo} | Balance: PKR ${state.currentUser!.balance.toStringAsFixed(2)}",
              icon: Icons.wallet_rounded,
              action: const Icon(Icons.link_off_rounded, color: Colors.redAccent),
              onTap: () => state.disconnectWallet(),
            ),
          ],
          const SizedBox(height: 25),

          // Custom Setting options list
          const Text("App Configurations", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
          const SizedBox(height: 12),

          // Translation switcher
          _buildSettingsOptionCard(
            title: state.translate('language'),
            subtitle: "Current: ${state.currentLanguage == 'en' ? 'English' : 'Urdu'}",
            icon: Icons.language_rounded,
            action: Switch(
              value: state.currentLanguage == 'ur',
              activeColor: AppTheme.accentTeal,
              onChanged: (_) {
                state.toggleLanguage();
              },
            ),
          ),
          const SizedBox(height: 12),

          // Font Multiplier Selector
          _buildSettingsOptionCard(
            title: state.translate('font_size'),
            subtitle: "Scale size: ${state.fontSizeSetting.toUpperCase()}",
            icon: Icons.format_size_rounded,
            action: DropdownButton<String>(
              value: state.fontSizeSetting,
              dropdownColor: AppTheme.secondaryDark,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'small', child: Text("Small")),
                DropdownMenuItem(value: 'medium', child: Text("Medium")),
                DropdownMenuItem(value: 'large', child: Text("Large")),
              ],
              onChanged: (val) {
                if (val != null) state.setFontSize(val);
              },
            ),
          ),
          const SizedBox(height: 12),

          // About Us Expandable block
          _buildSettingsOptionCard(
            title: state.translate('about_us'),
            subtitle: "App information & specifications",
            icon: Icons.info_outline_rounded,
            action: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
            onTap: () => _showAboutUsDialog(state),
          ),
          const SizedBox(height: 35),

          // Red Logout Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.withOpacity(0.15),
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: const Icon(Icons.logout_rounded),
            label: Text(state.translate('logout'), style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              state.logout();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const AuthScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget action,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.secondaryDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderDark, width: 1),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.primaryDark,
              child: Icon(icon, color: AppTheme.accentTeal, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            action,
          ],
        ),
      ),
    );
  }

  void _showAboutUsDialog(AppStateService state) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: AppTheme.secondaryDark,
          title: Text(state.translate('about_us'), style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  state.translate('about_description'),
                  style: const TextStyle(fontSize: 13, height: 1.5, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 16),
                const Divider(color: AppTheme.borderDark),
                const SizedBox(height: 8),
                const Text("Version: 1.0.0 (BETA)", style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                const Text("Developed for: Entrepreneurship Sem-6", style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CLOSE", style: TextStyle(color: AppTheme.accentTeal, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showProfileDialog(BuildContext context, AppStateService state) {
    final nameController = TextEditingController(text: state.currentUser?.name);
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: AppTheme.secondaryDark,
          title: const Text("My Profile", style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text("Email: ${state.currentUser?.email}", style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  Text("CNIC: ${state.currentUser?.cnic}", style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      labelText: "Username (Name)",
                      labelStyle: TextStyle(color: AppTheme.accentTeal),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? "Name required" : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      labelText: "New Password (Optional)",
                      labelStyle: TextStyle(color: AppTheme.accentTeal),
                    ),
                    obscureText: true,
                    validator: (v) {
                      if (v != null && v.isNotEmpty && v.length < 6) {
                        return "At least 6 characters";
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL", style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentTeal,
                foregroundColor: AppTheme.primaryDark,
              ),
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                state.updateProfile(nameController.text, passwordController.text);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Profile updated successfully!"),
                    backgroundColor: AppTheme.accentGreen,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text("SAVE CHANGES", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // ==================== LUCKY DRAW WHEEL SCREEN ====================
  void _navigateToWheelScreen(AppStateService state) {
    if (state.committees.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          return const _ManagerDrawScreen();
        },
      ),
    );
  }



  void _showReceiptsSheet(BuildContext context, AppStateService state) {
    final receipts = state.receipts; // Manager sees all receipts in the system

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: AppTheme.primaryDark,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            border: Border(top: BorderSide(color: AppTheme.borderDark, width: 1.5)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.receipt_long_rounded, color: AppTheme.accentTeal, size: 24),
                      SizedBox(width: 8),
                      Text(
                        "System Payment Receipts",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (receipts.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text(
                      "No payment receipts found.",
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: receipts.length,
                    itemBuilder: (context, idx) {
                      final r = receipts[idx];
                      final isSub = r.type == 'Subscription';
                      return PremiumCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  r.type,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isSub ? AppTheme.accentGold : AppTheme.accentGreen,
                                  ),
                                ),
                                Text(
                                  "PKR ${r.amount.toStringAsFixed(0)}",
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "User: ${r.userName} (${r.userEmail})",
                              style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Reference: ${r.referenceName}",
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Method: ${r.gateway} (${r.phoneOrAccount})",
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Date: ${r.timestamp.toString().split('.')[0]}",
                              style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _triggerCommitteePaymentDialog(BuildContext context, AppStateService state, CommitteeModel comm) {
    String selectedGateway = 'easypaisa';
    bool isPaying = false;
    _phoneController.clear();
    _otpController.clear();

    final paymentFormKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppTheme.secondaryDark,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                  border: Border(
                    top: BorderSide(color: AppTheme.borderDark, width: 1.5),
                  ),
                ),
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: paymentFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 50,
                          height: 5,
                          decoration: BoxDecoration(
                            color: AppTheme.borderDark,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Committee Contribution",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${comm.name} • PKR ${comm.monthlyContribution.toStringAsFixed(0)}",
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.accentTeal,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              _buildGatewayOption(
                                name: 'easypaisa',
                                color: const Color(0xFF10B981),
                                label: 'EP',
                                isSelected: selectedGateway == 'easypaisa',
                                onTap: () => setModalState(() => selectedGateway = 'easypaisa'),
                              ),
                              const SizedBox(width: 8),
                              _buildGatewayOption(
                                name: 'jazzcash',
                                color: const Color(0xFFF59E0B),
                                label: 'JC',
                                isSelected: selectedGateway == 'jazzcash',
                                onTap: () => setModalState(() => selectedGateway = 'jazzcash'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      CustomTextField(
                        labelText: state.translate('phone'),
                        hintText: "03xx-xxxxxxx",
                        prefixIcon: Icons.phone_android_outlined,
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        validator: (v) {
                          if (v == null || v.isEmpty) return "Phone required";
                          if (v.length < 11) return "Enter complete mobile number";
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        labelText: "4-Digit Security OTP",
                        hintText: "xxxx",
                        prefixIcon: Icons.lock_outline_rounded,
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        isPassword: true,
                        validator: (v) {
                          if (v == null || v.isEmpty) return "OTP code required";
                          if (v.length != 4) return "OTP must be exactly 4 digits";
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        selectedGateway == 'easypaisa'
                            ? "Simulating Easypaisa USSD push checkout."
                            : "Simulating JazzCash mobile wallet API gateway.",
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      GradientButton(
                        text: "Confirm & Pay Contribution",
                        isLoading: isPaying,
                        onPressed: () async {
                          if (!paymentFormKey.currentState!.validate()) return;
                          
                          setModalState(() {
                            isPaying = true;
                          });
                          
                          final success = await state.payCommitteeInstallment(
                            comm.id,
                            selectedGateway.toUpperCase(),
                            _phoneController.text,
                          );
                              
                          setModalState(() {
                            isPaying = false;
                          });
                          
                          if (context.mounted) {
                            Navigator.pop(context); // Close bottom sheet
                            
                            if (success) {
                              _showPaymentSuccessPopup(context, comm);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Payment failed. Please verify credentials."),
                                  backgroundColor: Colors.redAccent,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGatewayOption({
    required String name,
    required Color color,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppTheme.borderDark,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSelected ? color : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentSuccessPopup(BuildContext context, CommitteeModel comm) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: AppTheme.secondaryDark,
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 75,
                  height: 75,
                  decoration: const BoxDecoration(
                    color: AppTheme.accentGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 45,
                    color: AppTheme.primaryDark,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Installment Received!",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Your contribution of PKR ${comm.monthlyContribution.toStringAsFixed(0)} for '${comm.name}' has been processed successfully.",
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentGreen,
                      foregroundColor: AppTheme.primaryDark,
                    ),
                    child: const Text("OK"),
                    onPressed: () {
                      Navigator.pop(context); // Close dialogue
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLinkWalletSheet(BuildContext context, AppStateService state, String provider) {
    final phoneController = TextEditingController(text: state.currentUser?.phone ?? "");
    final pinController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLinking = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppTheme.secondaryDark,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                  border: Border(top: BorderSide(color: AppTheme.borderDark, width: 1.5)),
                ),
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 50,
                          height: 5,
                          decoration: BoxDecoration(
                            color: AppTheme.borderDark,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "Connect $provider Wallet",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Authenticate your $provider account to sync your available balance.",
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 20),
                      CustomTextField(
                        labelText: "Phone / Account Number",
                        hintText: "e.g. 03001234567",
                        prefixIcon: Icons.phone_android_outlined,
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        validator: (v) {
                          if (v == null || v.isEmpty) return "Phone number required";
                          if (v.length < 11) return "Enter complete mobile number";
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        labelText: "4-Digit Wallet PIN",
                        hintText: "xxxx",
                        prefixIcon: Icons.lock_outline_rounded,
                        controller: pinController,
                        keyboardType: TextInputType.number,
                        isPassword: true,
                        validator: (v) {
                          if (v == null || v.isEmpty) return "PIN required";
                          if (v.length != 4) return "PIN must be exactly 4 digits";
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      GradientButton(
                        text: "Link Wallet Account",
                        isLoading: isLinking,
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          
                          setModalState(() {
                            isLinking = true;
                          });

                          final success = await state.connectWalletProvider(
                            provider.toUpperCase(),
                            phoneController.text,
                            pinController.text,
                          );

                          setModalState(() {
                            isLinking = false;
                          });

                          if (context.mounted) {
                            Navigator.pop(context);
                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Successfully linked your $provider wallet!"),
                                  backgroundColor: AppTheme.accentGreen,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Connection Failed: JazzCash/Easypaisa connection failed. Please check your credentials."),
                                  backgroundColor: Colors.redAccent,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleRefreshWallet(AppStateService state) async {
    setState(() {
      _isRefreshingWallet = true;
    });

    final success = await state.refreshWalletBalance();

    setState(() {
      _isRefreshingWallet = false;
    });

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Wallet balance synchronized successfully!"),
            backgroundColor: AppTheme.accentGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Error: Failed to refresh balance."),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildChatCommitteeSelectionView(AppStateService state) {
    final committees = state.committees;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: Icon(Icons.forum_outlined, size: 60, color: AppTheme.accentTeal),
          ),
          const SizedBox(height: 12),
          const ScaledText(
            "Select Committee Chat",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            "As Manager, you have access to chat rooms of all active committees.",
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 25),
          
          if (committees.isEmpty) ...[
            const PremiumCard(
              child: Center(
                child: Text("No committees launched yet. Please launch a committee first.", style: TextStyle(color: AppTheme.textSecondary)),
              ),
            ),
          ] else ...[
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: committees.length,
              itemBuilder: (context, idx) {
                final comm = committees[idx];
                final bool isSelected = _selectedRadioCommitteeId == comm.id;

                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isSelected ? AppTheme.accentTeal : AppTheme.borderDark,
                      width: isSelected ? 2 : 0.8,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      setState(() {
                        _selectedRadioCommitteeId = comm.id;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      child: Row(
                        children: [
                          Radio<String>(
                            value: comm.id,
                            groupValue: _selectedRadioCommitteeId,
                            activeColor: AppTheme.accentTeal,
                            onChanged: (val) {
                              setState(() {
                                _selectedRadioCommitteeId = val;
                              });
                            },
                          ),
                          const SizedBox(width: 4),
                          CircleAvatar(
                            backgroundColor: AppTheme.accentTeal.withOpacity(0.12),
                            child: const Icon(
                              Icons.groups_rounded,
                              color: AppTheme.accentTeal,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  comm.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${comm.joinedMembers.length}/${comm.membersLimit} Members enrolled",
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            GradientButton(
              text: "Open Selected Committee Chat",
              onPressed: () {
                if (_selectedRadioCommitteeId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Please select a committee chat group first."),
                      backgroundColor: AppTheme.accentOrange,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                
                setState(() {
                  _selectedChatCommitteeId = _selectedRadioCommitteeId;
                });
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _ManagerDrawScreen extends StatefulWidget {
  const _ManagerDrawScreen();

  @override
  State<_ManagerDrawScreen> createState() => _ManagerDrawScreenState();
}

class _ManagerDrawScreenState extends State<_ManagerDrawScreen> {
  String? _selectedCommitteeId;
  String _winnerName = "";
  bool _isSpinning = false;
  bool _drawExecuted = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateService>();
    
    // Auto-select first committee if not selected
    if (_selectedCommitteeId == null && state.committees.isNotEmpty) {
      _selectedCommitteeId = state.committees.first.id;
    }

    final activeCommittee = state.committees.firstWhere(
      (c) => c.id == _selectedCommitteeId,
      orElse: () => state.committees.first,
    );

    final bool isAllowedToDraw = state.canPerformDraw(activeCommittee.id);
    if (!isAllowedToDraw && activeCommittee.drawWinners.isNotEmpty && !_isSpinning && !_drawExecuted) {
      _winnerName = activeCommittee.drawWinners.last;
      _drawExecuted = true;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(state.translate('lucky_wheel')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.premiumGradient),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Committee selector dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderDark),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCommitteeId,
                    dropdownColor: AppTheme.secondaryDark,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.accentTeal),
                    items: state.committees.map((comm) {
                      return DropdownMenuItem(
                        value: comm.id,
                        child: Text(comm.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      );
                    }).toList(),
                    onChanged: _isSpinning
                        ? null
                        : (val) {
                            setState(() {
                              _selectedCommitteeId = val;
                              _drawExecuted = false;
                              _winnerName = "";
                            });
                          },
                  ),
                ),
              ),
               const SizedBox(height: 25),

              Builder(builder: (context) {
                final bool isAllowedToDraw = state.canPerformDraw(activeCommittee.id);
                final nextDrawDate = state.nextDrawAllowedAt(activeCommittee.id);
                final String nextDrawStr = nextDrawDate != null 
                    ? "${nextDrawDate.day}/${nextDrawDate.month}/${nextDrawDate.year}" 
                    : "";

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!isAllowedToDraw && !_drawExecuted) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.accentOrange.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.accentOrange.withOpacity(0.3), width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.timer_outlined, color: AppTheme.accentOrange, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Draw cycle locked. Next draw allowed on or after $nextDrawStr.",
                                style: const TextStyle(fontSize: 12, color: AppTheme.accentOrange, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    if (!_drawExecuted) ...[
                      // The Custom Canvas Paint spinning wheel module
                      Center(
                        child: activeCommittee.joinedMembers.where((member) => !activeCommittee.drawWinners.contains(member)).isEmpty
                            ? Container(
                                height: 250,
                                alignment: Alignment.center,
                                child: const Text(
                                  "All members have won this drawing cycle!",
                                  style: TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              )
                            : LuckyDrawWheel(
                                members: activeCommittee.joinedMembers.where((member) => !activeCommittee.drawWinners.contains(member)).toList(),
                                winnerName: _winnerName,
                                isSpinning: _isSpinning,
                                onSpinComplete: () {
                                  // Finalize draw in state service when spin animation completes
                                  state.finalizeLuckyDraw(activeCommittee.id, _winnerName);
                                  setState(() {
                                    _isSpinning = false;
                                    _drawExecuted = true;
                                  });
                                },
                              ),
                      ),
                      const SizedBox(height: 30),

                      // Spin Payout Draw Action Trigger Button
                      GradientButton(
                        text: isAllowedToDraw ? state.translate('spin') : "DRAW LOCKED (Next: $nextDrawStr)",
                        gradientColors: isAllowedToDraw 
                            ? const [AppTheme.accentGold, AppTheme.accentOrange]
                            : const [AppTheme.borderDark, AppTheme.borderDark],
                        isLoading: _isSpinning,
                        onPressed: () {
                          if (!isAllowedToDraw) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("A draw has already been performed for this cycle. Next draw is allowed on or after $nextDrawStr."),
                                backgroundColor: Colors.redAccent,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }
                          // Call pickLuckyDrawWinner to get winner name from state list without saving yet
                          final result = state.pickLuckyDrawWinner(activeCommittee.id);
                          if (result.contains("already") || result.contains("not found")) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(result), backgroundColor: Colors.redAccent),
                            );
                          } else {
                            setState(() {
                              _winnerName = result;
                              _isSpinning = true;
                            });
                          }
                        },
                      ),
                    ] else ...[
                      PremiumCard(
                        child: Column(
                          children: [
                            const Icon(Icons.stars_rounded, color: AppTheme.accentGold, size: 55),
                            const SizedBox(height: 10),
                            Text(
                              state.translate('winner'),
                              style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _winnerName,
                              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "PKR ${activeCommittee.totalAmount.toStringAsFixed(0)} rotated saving pool has been awarded!",
                              style: const TextStyle(fontSize: 11, color: AppTheme.accentTeal),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppTheme.accentTeal),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text("DONE", style: TextStyle(color: AppTheme.accentTeal, fontWeight: FontWeight.bold)),
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

Color _getLuckyDrawStatusColor(String status) {
  switch (status) {
    case 'Active':
      return AppTheme.accentGreen;
    case 'Upcoming':
      return AppTheme.accentOrange;
    case 'Completed':
      return AppTheme.accentGold;
    case 'Closed':
    default:
      return AppTheme.borderDark;
  }
}
