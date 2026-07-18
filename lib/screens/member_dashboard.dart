import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/state_service.dart';
import '../models/user.dart';
import '../models/committee.dart';
import '../models/receipt.dart';
import '../widgets/custom_widgets.dart';
import '../theme/app_theme.dart';
import 'auth_screen.dart';
import 'subscription_screen.dart';
import 'ai_chat_screen.dart';
import '../services/ai_service.dart';

class MemberDashboard extends StatefulWidget {
  const MemberDashboard({super.key});

  @override
  State<MemberDashboard> createState() => _MemberDashboardState();
}

class _MemberDashboardState extends State<MemberDashboard> {
  int _currentIndex = 0;
  bool _isRefreshingWallet = false;
  String? _selectedChatCommitteeId;
  // AI assistant state
  String _aiInsight = '';
  bool _isLoadingAiInsight = false;
  bool _isAiInsightExpanded = false;
  String? _selectedRadioCommitteeId;
  String _selectedLoanSubPlan = 'monthly';

  // Loan Request Form Controllers
  final _loanAmountController = TextEditingController();
  final _loanReasonController = TextEditingController();
  int _selectedDurationMonths = 12; // 3, 6, or 12 months max
  final _loanFormKey = GlobalKey<FormState>();



  // Chat Controller
  final _chatController = TextEditingController();
  final _chatScrollController = ScrollController();

  // Payment Controllers
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loanAmountController.addListener(_onAmountChanged);
  }

  void _onAmountChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _loanAmountController.removeListener(_onAmountChanged);
    _loanAmountController.dispose();
    _loanReasonController.dispose();
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
      _buildChatTab(state),
      _buildLoanTab(state),
      _buildSettingsTab(state),
    ];

    return Scaffold(
      // ── AI Assistant FAB ─────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AiChatScreen(agentType: 'member'),
            ),
          );
        },
        backgroundColor: AppTheme.accentTeal,
        foregroundColor: AppTheme.primaryDark,
        icon: const Icon(Icons.smart_toy_rounded),
        label: Text(
          state.currentLanguage == 'ur' ? 'AI اسسٹنٹ' : 'AI Assistant',
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
            icon: const Icon(Icons.home_rounded),
            label: state.translate('home'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            label: state.translate('chats'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.monetization_on_outlined),
            label: state.translate('loan_tab'),
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
    final memberEmail = state.currentUser?.email ?? "";
    final memberName = state.currentUser?.name ?? "";

    // Filter committees that this specific member has joined
    final myCommittees = state.committees.where(
      (c) => c.joinedMembers.contains(memberName),
    ).toList();

    final availableCommittees = state.committees.where(
      (c) => !c.joinedMembers.contains(memberName) && c.joinedMembers.length < c.membersLimit,
    ).toList();

    double totalPaid = 0;
    double totalRemaining = 0;
    for (var c in myCommittees) {
      final personalInstallmentsPaid = state.receipts
          .where((r) => r.userEmail == memberEmail && r.referenceId == c.id && r.type == 'Committee Installment')
          .length;
      totalPaid += personalInstallmentsPaid * c.monthlyContribution;
      
      final remainingInstallments = (c.totalInstallments - personalInstallmentsPaid).clamp(0, c.totalInstallments);
      totalRemaining += remainingInstallments * c.monthlyContribution;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Welcome Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ScaledText(
                    "Welcome back,",
                    style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                  ),
                  ScaledText(
                    state.currentUser?.name ?? "Member",
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                ],
              ),
              if (state.currentUser?.isSubscribed ?? false)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accentTeal.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.accentTeal, width: 0.8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.workspace_premium_rounded, color: AppTheme.accentTeal, size: 14),
                      const SizedBox(width: 4),
                      Text("PREMIUM", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.accentTeal)),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.borderDark.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderDark, width: 0.8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline, color: AppTheme.textSecondary, size: 14),
                      const SizedBox(width: 4),
                      Text("FREE USER", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
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
                if (state.currentUser?.linkedProvider == null) ...[
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Link Provider Wallet:",
                        style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white24,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              minimumSize: Size.zero,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _showLinkWalletSheet(context, state, 'JazzCash'),
                            child: const Text("JazzCash", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white24,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              minimumSize: Size.zero,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _showLinkWalletSheet(context, state, 'Easypaisa'),
                            child: const Text("Easypaisa", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            state.currentUser!.linkedProvider == 'JAZZCASH' ? Icons.stars_rounded : Icons.check_circle_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "Linked: ${state.currentUser!.linkedProvider} (${state.currentUser!.linkedAccountNo})",
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: _isRefreshingWallet
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                                  )
                                : const Icon(Icons.refresh_rounded, color: Colors.white, size: 16),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: _isRefreshingWallet ? null : () => _handleRefreshWallet(state),
                          ),
                          const SizedBox(width: 14),
                          GestureDetector(
                            onTap: () => state.disconnectWallet(),
                            child: const Text(
                              "Unlink",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── AI Insights Card ──────────────────────────────────────
          _buildAiInsightsCard(state),
          const SizedBox(height: 20),

          // Total Financial Progress Card
          PremiumCard(
            gradientColors: const [Color(0xFF1E293B), Color(0xFF0F172A)],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Total Financial Overview", style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Total Invested / Saved", style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                        const SizedBox(height: 2),
                        Text("PKR ${totalPaid.toStringAsFixed(0)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.accentGreen)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text("Total Scheduled Pool Remaining", style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                        const SizedBox(height: 2),
                        Text("PKR ${totalRemaining.toStringAsFixed(0)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.accentTeal)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),

          // Committees joined list Header
          ScaledText(
            "My Committees (${myCommittees.length})",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 12),

          if (myCommittees.isEmpty) ...[
            const PremiumCard(
              child: Center(
                child: Text(
                  "You are not enrolled in any rotating committees yet. Ask your manager to add your name to a savings pool!",
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ] else ...[
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: myCommittees.length,
              itemBuilder: (context, idx) {
                final comm = myCommittees[idx];
                final personalInstallments = state.receipts
                    .where((r) => r.userEmail == memberEmail && r.referenceId == comm.id && r.type == 'Committee Installment')
                    .length;
                final progress = personalInstallments / comm.totalInstallments;

                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(comm.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentTeal.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    comm.status.toUpperCase(),
                                    style: const TextStyle(fontSize: 9, color: AppTheme.accentTeal, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _getLuckyDrawStatusColor(state.getLuckyDrawStatus(comm.id)).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: _getLuckyDrawStatusColor(state.getLuckyDrawStatus(comm.id)),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    state.getLuckyDrawStatus(comm.id).toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: _getLuckyDrawStatusColor(state.getLuckyDrawStatus(comm.id)),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(comm.description, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        const SizedBox(height: 16),
                        
                        // Amount Paid and Amount Remaining
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(state.translate('paid'), style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                                const SizedBox(height: 2),
                                Text("PKR ${comm.amountPaid.toStringAsFixed(0)}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.accentGreen)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(state.translate('remaining'), style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                                const SizedBox(height: 2),
                                Text("PKR ${comm.amountRemaining.toStringAsFixed(0)}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.accentTeal)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        // Beautiful Custom Payout Installment Progress Bar
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 8,
                                  backgroundColor: AppTheme.primaryDark,
                                  color: AppTheme.accentGreen,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              "$personalInstallments / ${comm.totalInstallments}",
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                            ),
                          ],
                        ),
                        if (personalInstallments < comm.totalInstallments) ...[
                          const SizedBox(height: 16),
                          Builder(builder: (context) {
                            final bool isAllowedToPay = state.canPayInstallment(comm.id);
                            final nextAllowedDate = state.nextInstallmentAllowedAt(comm.id);
                            final String nextAllowedStr = nextAllowedDate != null 
                                ? "${nextAllowedDate.day}/${nextAllowedDate.month}/${nextAllowedDate.year}" 
                                : "";

                            return SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: Icon(isAllowedToPay ? Icons.payment_rounded : Icons.check_circle_outline, size: 18),
                                label: Text(isAllowedToPay 
                                  ? "PAY INSTALLMENT (PKR ${comm.monthlyContribution.toStringAsFixed(0)})"
                                  : "PAID FOR THIS CYCLE (Next: $nextAllowedStr)"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isAllowedToPay ? AppTheme.accentGreen : AppTheme.borderDark,
                                  foregroundColor: isAllowedToPay ? AppTheme.primaryDark : AppTheme.textSecondary,
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
                          }),
                        ] else ...[
                          const SizedBox(height: 16),
                          const Center(
                            child: Text(
                              "All Installments Completed!",
                              style: TextStyle(fontSize: 12, color: AppTheme.accentGreen, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 25),
          ScaledText(
            "Available Committees (Members Required)",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 12),
          if (availableCommittees.isEmpty) ...[
            const PremiumCard(
              child: Center(
                child: Text(
                  "No open rotating committees available to join at this time.",
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ] else ...[
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: availableCommittees.length,
              itemBuilder: (context, idx) {
                final comm = availableCommittees[idx];

                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(comm.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.accentGold.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "${comm.joinedMembers.length}/${comm.membersLimit} Slots",
                                style: const TextStyle(fontSize: 9, color: AppTheme.accentGold, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(comm.description, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        const SizedBox(height: 12),
                        
                        // Joined Members list
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
                              ],
                            ),
                          )).toList(),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("${comm.frequency[0].toUpperCase()}${comm.frequency.substring(1)} Payout", style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                                const SizedBox(height: 2),
                                Text("PKR ${comm.totalAmount.toStringAsFixed(0)}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text("${comm.frequency[0].toUpperCase()}${comm.frequency.substring(1)} Contribution", style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                                const SizedBox(height: 2),
                                Text("PKR ${comm.monthlyContribution.toStringAsFixed(0)}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.accentTeal)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentTeal,
                              foregroundColor: AppTheme.primaryDark,
                            ),
                            child: const Text("JOIN SAVINGS POOL"),
                            onPressed: () => _showJoinConfirmationDialog(context, state, comm),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 20),
          
          // Notifications Panel
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ScaledText(
                state.translate('recent_notifications'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const Icon(Icons.notifications_active_outlined, color: AppTheme.accentTeal, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: state.notifications.take(3).length,
            itemBuilder: (context, idx) {
              final notif = state.notifications[idx];
              IconData icon = Icons.notifications_none_rounded;
              Color color = AppTheme.accentTeal;
              
              if (notif.type == 'payment') {
                icon = Icons.payment_rounded;
                color = AppTheme.accentGreen;
              } else if (notif.type == 'draw') {
                icon = Icons.stars_rounded;
                color = AppTheme.accentGold;
              } else if (notif.type == 'loan') {
                icon = Icons.money_rounded;
                color = AppTheme.accentOrange;
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                color: AppTheme.secondaryDark.withOpacity(0.6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withOpacity(0.1),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  title: Text(notif.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  subtitle: Text(notif.body, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ==================== AI INSIGHTS CARD ====================
  Widget _buildAiInsightsCard(AppStateService state) {
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
                  const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    isUrdu ? 'AI اسسٹنٹ' : 'AI Assistant',
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
                  color: Colors.white24,
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
              maxHeight: _isAiInsightExpanded ? 350.0 : 120.0,
            ),
            child: Scrollbar(
              thumbVisibility: _aiInsight.isNotEmpty && _aiInsight.length > 120,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                    _isLoadingAiInsight
                        ? (isUrdu ? 'تجزیہ ہو رہا ہے...' : 'Analyzing your data...')
                        : (_aiInsight.isNotEmpty
                            ? _aiInsight
                            : (isUrdu
                                ? 'اپنی کمیٹیوں، قرض اور ادائیگیوں کے بارے میں AI سے پوچھیں۔'
                                : 'Ask me about your committees, payments, loans, or get personalized financial insights!')),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                      height: 1.5,
                    ),
                    softWrap: true,
                  ),
                ),
              ),
            ),
          ),
          if (_aiInsight.isNotEmpty && _aiInsight.length > 120) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _isAiInsightExpanded = !_isAiInsightExpanded),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _isAiInsightExpanded
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
                    _isAiInsightExpanded
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
                      builder: (_) => const AiChatScreen(agentType: 'member'),
                    ),
                  ),
                  icon: const Icon(Icons.chat_rounded, size: 16),
                  label: Text(isUrdu ? 'چیٹ کریں' : 'Open Chat'),
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
                onPressed: _isLoadingAiInsight
                    ? null
                    : () => _fetchAiInsight(state),
                icon: _isLoadingAiInsight
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentTeal),
                      )
                    : const Icon(Icons.auto_awesome_rounded, size: 16),
                label: Text(isUrdu ? 'Insight' : 'Insight'),
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

  Future<void> _fetchAiInsight(AppStateService state) async {
    if (_isLoadingAiInsight) return;
    setState(() => _isLoadingAiInsight = true);
    final user = state.currentUser;
    if (user == null) {
      setState(() => _isLoadingAiInsight = false);
      return;
    }
    final lang = state.currentLanguage;
    final result = await AiService.chat(
      message: lang == 'ur'
          ? 'میری کمیٹیوں اور ادائیگیوں کا مختصر جائزہ دیں'
          : 'Give me a brief summary of my committee and payment health in 2 sentences',
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
        _aiInsight = result.reply;
        _isLoadingAiInsight = false;
      });
    }
  }

  // ==================== CHAT TAB ====================
  Widget _buildChatTab(AppStateService state) {

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
        // Forum Topic Header
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
                    const Text("Live Group Chat Room", style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
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

        // Live Chat Bubble list
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

        // Send Input Bar
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
                    hintText: "Write message...",
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

  // ==================== LOAN TAB ====================
  Widget _buildLoanTab(AppStateService state) {
    final bool isSubscribed = state.currentUser?.isSubscribed ?? false;
    final bool isExpired = state.isSubscriptionExpired;

    // Filter loans submitted by this specific member
    final myLoans = state.loans.where((l) => l.applicantEmail == state.currentUser?.email).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Active Loan Form or locked plan card
          if (isSubscribed && !isExpired) ...[
            Form(
              key: _loanFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.monetization_on_outlined, size: 50, color: AppTheme.accentGreen),
                  const SizedBox(height: 10),
                  ScaledText(
                    state.translate('loan_request'),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Simple zero-interest loans. Pay back exactly what you borrow, spread equally over your chosen period.",
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // Loan Amount Field (PKR 1,000 - 50,000)
                  CustomTextField(
                    labelText: "Loan Amount (PKR 1,000 - 50,000)",
                    hintText: "e.g. 1000",
                    prefixIcon: Icons.account_balance_wallet_outlined,
                    controller: _loanAmountController,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return "Amount required";
                      final amt = double.tryParse(v);
                      if (amt == null || amt < 1000 || amt > 50000) {
                        return "Amount must be between 1,000 PKR and 50,000 PKR";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Reason for loan
                  CustomTextField(
                    labelText: state.translate('loan_reason'),
                    hintText: "State purpose of loan request",
                    prefixIcon: Icons.description_outlined,
                    controller: _loanReasonController,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return "Reason required";
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Repayment Period Dropdown (Months)
                  DropdownButtonFormField<int>(
                    value: _selectedDurationMonths,
                    dropdownColor: AppTheme.secondaryDark,
                    decoration: const InputDecoration(
                      labelText: "Repayment Period (Months)",
                      prefixIcon: Icon(Icons.calendar_today_rounded, color: AppTheme.accentTeal),
                    ),
                    items: const [
                      DropdownMenuItem(value: 3, child: Text("3 Months")),
                      DropdownMenuItem(value: 6, child: Text("6 Months")),
                      DropdownMenuItem(value: 12, child: Text("12 Months")),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedDurationMonths = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 20),

                  // Interactive Auto-Installment Calculations Panel
                  _buildInstallmentCalculationPanel(),

                  const SizedBox(height: 25),

                  GradientButton(
                    text: state.translate('submit_request'),
                    onPressed: () async {
                      if (!_loanFormKey.currentState!.validate()) return;

                      final double amount = double.parse(_loanAmountController.text);
                      final bool success = state.requestLoan(
                        amount,
                        _loanReasonController.text,
                        _selectedDurationMonths,
                      );

                      if (success) {
                        _loanAmountController.clear();
                        _loanReasonController.clear();

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Loan Application Submitted to Manager!"),
                            backgroundColor: AppTheme.accentGreen,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.secondaryDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.borderDark, width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: Icon(
                      Icons.lock_person_rounded,
                      size: 48,
                      color: AppTheme.accentGold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const ScaledText(
                    "Loan Access Premium Only",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Applying for zero-interest rotating savers micro-loans requires a premium subscription. Choose a plan to unlock.",
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  _buildLoanPlanCard(
                    id: 'weekly',
                    title: state.translate('weekly'),
                    price: "PKR 50",
                    description: "Access loans and group chats for 7 days.",
                    icon: Icons.date_range_outlined,
                  ),
                  const SizedBox(height: 10),
                  _buildLoanPlanCard(
                    id: 'monthly',
                    title: state.translate('monthly'),
                    price: "PKR 300",
                    description: "Direct group chats and loan permissions for 30 days.",
                    icon: Icons.calendar_month_outlined,
                    isPopular: true,
                  ),
                  const SizedBox(height: 10),
                  _buildLoanPlanCard(
                    id: 'yearly',
                    title: state.translate('yearly'),
                    price: "PKR 3600",
                    description: "Best Value! Full premium access for 365 days.",
                    icon: Icons.stars_rounded,
                  ),
                  const SizedBox(height: 20),
                  GradientButton(
                    text: "Unlock Loans Now",
                    gradientColors: const [AppTheme.accentGold, AppTheme.accentOrange],
                    onPressed: () {
                      double amount = 300;
                      String planName = "Monthly Plan";
                      if (_selectedLoanSubPlan == 'weekly') {
                        amount = 50;
                        planName = "Weekly Plan";
                      } else if (_selectedLoanSubPlan == 'yearly') {
                        amount = 3600;
                        planName = "Yearly Plan";
                      }
                      _triggerLoanSubscriptionPaymentDialog(state, planName, amount, _selectedLoanSubPlan);
                    },
                  ),
                ],
              ),
            ),
          ],

          // History of Member's loans list
          if (myLoans.isNotEmpty) ...[
            const SizedBox(height: 35),
            const Text("My Loan Applications", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: myLoans.length,
              itemBuilder: (context, idx) {
                final loan = myLoans[idx];
                Color statusColor = AppTheme.accentGold;
                if (loan.status == 'approved') statusColor = AppTheme.accentGreen;
                if (loan.status == 'rejected') statusColor = Colors.redAccent;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("PKR ${loan.amount.toStringAsFixed(0)}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                loan.status.toUpperCase(),
                                style: TextStyle(fontSize: 9, color: statusColor, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text("Reason: ${loan.reason}", style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Repayment Option: PKR ${loan.monthlyRepayment.toStringAsFixed(0)} / mo", style: const TextStyle(fontSize: 11, color: AppTheme.accentTeal)),
                            Text("Duration: ${loan.durationMonths} mo", style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          ],
                        ),
                        if (loan.status == 'approved' || loan.status == 'completed') ...[
                           const SizedBox(height: 12),
                           const Divider(color: AppTheme.borderDark),
                           const SizedBox(height: 8),
                           Row(
                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                             children: [
                               const Text("Repayment Progress:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                               Text("${loan.installmentsPaid} / ${loan.durationMonths} Paid", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.accentGreen)),
                             ],
                           ),
                           const SizedBox(height: 8),
                           if (loan.installmentsPaid < loan.durationMonths && loan.status == 'approved')
                             SizedBox(
                               width: double.infinity,
                               child: ElevatedButton.icon(
                                 icon: const Icon(Icons.payment_rounded, size: 14),
                                 label: Text("REPAY INSTALLMENT (PKR ${loan.monthlyRepayment.toStringAsFixed(0)})", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                 style: ElevatedButton.styleFrom(
                                   backgroundColor: AppTheme.accentGreen,
                                   foregroundColor: AppTheme.primaryDark,
                                   padding: const EdgeInsets.symmetric(vertical: 10),
                                 ),
                                 onPressed: () {
                                   if (state.currentUser!.balance < loan.monthlyRepayment) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text("Insufficient wallet balance. Please add funds."),
                                          backgroundColor: Colors.redAccent,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                      return;
                                   }
                                   _triggerLoanRepaymentDialog(context, state, loan);
                                 },
                               ),
                             ),
                        ],
                      ],
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
  // ==================== SETTINGS TAB ====================
  Widget _buildSettingsTab(AppStateService state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Profile Details Card
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

          const Text("App Configurations", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
          const SizedBox(height: 12),

          // Localization Language options English/Urdu switcher
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

          // Font Scaling Adjustments selector
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

          // About Us descriptive pop-up trigger
          _buildSettingsOptionCard(
            title: state.translate('about_us'),
            subtitle: "App specifications & purpose",
            icon: Icons.info_outline_rounded,
            action: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
            onTap: () => _showAboutUsDialog(state),
          ),
          const SizedBox(height: 12),

          // Receipts History descriptive trigger
          _buildSettingsOptionCard(
            title: "Payment Receipts",
            subtitle: "View history of all paid transactions",
            icon: Icons.receipt_long_rounded,
            action: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
            onTap: () => _showReceiptsSheet(context, state),
          ),
          const SizedBox(height: 35),

          const Text("Developer Testing Tools", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          _buildSettingsOptionCard(
            title: "Simulate Expired Subscription",
            subtitle: "Force subscription expired state for testing",
            icon: Icons.timer_off_outlined,
            action: Switch(
              value: state.isSubscriptionExpired,
              activeColor: AppTheme.accentOrange,
              onChanged: (_) {
                state.toggleSubscriptionExpiry();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.isSubscriptionExpired
                        ? "Subscription Expired Simulation Enabled!"
                        : "Subscription Expired Simulation Disabled!"),
                    backgroundColor: state.isSubscriptionExpired ? AppTheme.accentOrange : AppTheme.accentGreen,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 25),

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

  void _showJoinConfirmationDialog(BuildContext context, AppStateService state, CommitteeModel comm) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: AppTheme.secondaryDark,
          title: const Text(
            "Confirm Joining Pool",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textPrimary),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                comm.name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.accentTeal),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                comm.description,
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const Divider(color: AppTheme.borderDark),
              const SizedBox(height: 12),
              _buildDialogRow("Savings Cycle:", comm.frequency.toUpperCase()),
              _buildDialogRow("Installment Amount:", "PKR ${comm.monthlyContribution.toStringAsFixed(0)}"),
              _buildDialogRow("Total Target Payout:", "PKR ${comm.totalAmount.toStringAsFixed(0)}"),
              _buildDialogRow("Slots Limit Capacity:", "${comm.membersLimit} Members"),
              _buildDialogRow("Joined Members:", "${comm.joinedMembers.length} Joined"),
              const SizedBox(height: 12),
              const Divider(color: AppTheme.borderDark),
              const SizedBox(height: 16),
              Text(
                "By joining this savings pool, you commit to paying PKR ${comm.monthlyContribution.toStringAsFixed(0)} every ${comm.frequency == 'daily' ? 'day' : comm.frequency == 'weekly' ? 'week' : 'month'} for the duration of the cycle.",
                style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, height: 1.4),
                textAlign: TextAlign.center,
              ),
            ],
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () {
                Navigator.pop(context);
                final success = state.joinCommittee(comm.id);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Successfully joined ${comm.name}!"),
                      backgroundColor: AppTheme.accentGreen,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Failed to join committee. You might already be enrolled or the slots are full."),
                      backgroundColor: Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text("CONFIRM JOIN", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInstallmentCalculationPanel() {
    final double? amount = double.tryParse(_loanAmountController.text);
    if (amount == null || amount < 1000) {
      return const SizedBox.shrink();
    }
    // Zero-interest: repay exactly the borrowed amount
    final installment = amount / _selectedDurationMonths;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.secondaryDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderDark, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Auto-Installment Breakdown",
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.accentTeal),
          ),
          const SizedBox(height: 10),
          _buildCalculationRow("Loan Amount (Principal)", "PKR ${amount.toStringAsFixed(0)}"),
          const SizedBox(height: 6),
          _buildCalculationRow("Interest", "PKR 0 (Zero Interest)"),
          const SizedBox(height: 6),
          _buildCalculationRow("Total Repayable", "PKR ${amount.toStringAsFixed(0)}"),
          const Divider(color: AppTheme.borderDark, height: 16),
          _buildCalculationRow(
            "Monthly Repayment",
            "PKR ${installment.toStringAsFixed(2)} / month",
            isHighlight: true,
          ),
          const SizedBox(height: 4),
          Text(
            "Paid equally over $_selectedDurationMonths months. No hidden charges.",
            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildCalculationRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isHighlight ? 13 : 11,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
            color: isHighlight ? AppTheme.textPrimary : AppTheme.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlight ? 14 : 11,
            fontWeight: FontWeight.bold,
            color: isHighlight ? AppTheme.accentGreen : AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  bool _isPaying = false;
  String _selectedGateway = 'easypaisa';

  void _triggerCommitteePaymentDialog(BuildContext context, AppStateService state, CommitteeModel comm) {
    _phoneController.text = state.currentUser?.phone ?? "";
    _otpController.clear();
    _selectedGateway = 'easypaisa';
    _isPaying = false;

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
                  border: Border(
                    top: BorderSide(color: AppTheme.borderDark, width: 1.5),
                  ),
                ),
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _paymentFormKey,
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
                              ScaledText(
                                "Committee Contribution",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              ScaledText(
                                "${comm.name} • PKR ${comm.monthlyContribution.toStringAsFixed(0)}",
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.accentTeal,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          // Gateway Icons Toggles
                          Row(
                            children: [
                              _buildGatewayOption(
                                name: 'easypaisa',
                                color: const Color(0xFF10B981),
                                label: 'EP',
                                isSelected: _selectedGateway == 'easypaisa',
                                onTap: () => setModalState(() => _selectedGateway = 'easypaisa'),
                              ),
                              const SizedBox(width: 8),
                              _buildGatewayOption(
                                name: 'jazzcash',
                                color: const Color(0xFFF59E0B),
                                label: 'JC',
                                isSelected: _selectedGateway == 'jazzcash',
                                onTap: () => setModalState(() => _selectedGateway = 'jazzcash'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      // Payment Phone Input
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
                      
                      // OTP Security Input
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
                      ScaledText(
                        _selectedGateway == 'easypaisa'
                            ? "Simulating Easypaisa USSD push checkout."
                            : "Simulating JazzCash mobile wallet API gateway.",
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      
                      GradientButton(
                        text: "Confirm & Pay Contribution",
                        isLoading: _isPaying,
                        onPressed: () async {
                          if (!_paymentFormKey.currentState!.validate()) return;
                          
                          setModalState(() {
                            _isPaying = true;
                          });
                          
                          // Execute payment logic in service
                          final success = await state.payCommitteeInstallment(
                            comm.id,
                            _selectedGateway.toUpperCase(),
                            _phoneController.text,
                          );
                              
                          setModalState(() {
                            _isPaying = false;
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
                const ScaledText(
                  "Installment Received!",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                ScaledText(
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

  void _triggerLoanRepaymentDialog(BuildContext parentContext, AppStateService state, loan) {
    String selectedGateway = 'EASYPAISA';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: parentContext,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (statefulCtx, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: AppTheme.secondaryDark,
              title: const Row(
                children: [
                  Icon(Icons.payment_rounded, color: AppTheme.accentGreen),
                  SizedBox(width: 8),
                  Text("Confirm Repayment", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        "You are about to repay PKR ${loan.monthlyRepayment.toStringAsFixed(0)} towards your loan.",
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedGateway,
                        dropdownColor: AppTheme.secondaryDark,
                        decoration: const InputDecoration(
                          labelText: "Select Payment Gateway",
                          prefixIcon: Icon(Icons.account_balance_wallet_outlined, color: AppTheme.accentTeal),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'EASYPAISA', child: Text("Easypaisa Wallet")),
                          DropdownMenuItem(value: 'JAZZCASH', child: Text("JazzCash Account")),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              selectedGateway = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        labelText: "Phone Number",
                        hintText: "e.g. 0300-1234567",
                        prefixIcon: Icons.phone_android_rounded,
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return "Phone required";
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        labelText: "Security PIN (OTP)",
                        hintText: "****",
                        prefixIcon: Icons.lock_outline_rounded,
                        controller: _otpController,
                        isPassword: true,
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().length != 4) return "Enter 4-digit PIN";
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _phoneController.clear();
                    _otpController.clear();
                    Navigator.pop(dialogCtx);
                  },
                  child: const Text("CANCEL", style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentGreen,
                    foregroundColor: AppTheme.primaryDark,
                  ),
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    
                    final phone = _phoneController.text;
                    _phoneController.clear();
                    _otpController.clear();
                    
                    Navigator.pop(dialogCtx); // pop confirmation dialog

                    // Show loading
                    showDialog(
                      context: parentContext,
                      barrierDismissible: false,
                      builder: (loadingCtx) {
                        state.repayLoanInstallment(
                          loan.id,
                          selectedGateway,
                          phone,
                        ).then((success) {
                          Navigator.pop(loadingCtx); // pop loading dialog

                          if (success) {
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              const SnackBar(
                                content: Text("Installment Paid Successfully!"),
                                backgroundColor: AppTheme.accentGreen,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              const SnackBar(
                                content: Text("Payment Failed. Try again."),
                                backgroundColor: Colors.redAccent,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        });

                        return const Center(child: CircularProgressIndicator(color: AppTheme.accentGreen));
                      },
                    );
                  },
                  child: const Text("PAY NOW", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showReceiptsSheet(BuildContext context, AppStateService state) {
    final userEmail = state.currentUser?.email ?? "";
    final myReceipts = state.receipts.where((r) => r.userEmail == userEmail).toList();

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
                        "Payment Receipts",
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
              if (myReceipts.isEmpty)
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
                    itemCount: myReceipts.length,
                    itemBuilder: (context, idx) {
                      final r = myReceipts[idx];
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

  final _paymentFormKey = GlobalKey<FormState>();

  Widget _buildDialogRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildLockedLoanView(AppStateService state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: Icon(
              Icons.lock_person_rounded,
              size: 65,
              color: AppTheme.accentGold,
            ),
          ),
          const SizedBox(height: 12),
          const ScaledText(
            "Subscription Required",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            "Applying for micro-loans requires an active premium subscription. Choose a plan below to activate instantly.",
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 25),
          
          _buildLoanPlanCard(
            id: 'weekly',
            title: state.translate('weekly'),
            price: "PKR 50",
            description: "Access loans and group chats for 7 days.",
            icon: Icons.date_range_outlined,
          ),
          const SizedBox(height: 12),
          _buildLoanPlanCard(
            id: 'monthly',
            title: state.translate('monthly'),
            price: "PKR 300",
            description: "Direct group chats and loan permissions for 30 days.",
            icon: Icons.calendar_month_outlined,
            isPopular: true,
          ),
          const SizedBox(height: 12),
          _buildLoanPlanCard(
            id: 'yearly',
            title: state.translate('yearly'),
            price: "PKR 3600",
            description: "Best Value! Full premium access for 365 days.",
            icon: Icons.stars_rounded,
          ),
          const SizedBox(height: 30),
          
          GradientButton(
            text: "Subscribe Now",
            gradientColors: const [AppTheme.accentGold, AppTheme.accentOrange],
            onPressed: () {
              double amount = 300;
              String planName = "Monthly Plan";
              if (_selectedLoanSubPlan == 'weekly') {
                amount = 50;
                planName = "Weekly Plan";
              } else if (_selectedLoanSubPlan == 'yearly') {
                amount = 3600;
                planName = "Yearly Plan";
              }
              _triggerLoanSubscriptionPaymentDialog(state, planName, amount, _selectedLoanSubPlan);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoanPlanCard({
    required String id,
    required String title,
    required String price,
    required String description,
    required IconData icon,
    bool isPopular = false,
  }) {
    final bool isSelected = _selectedLoanSubPlan == id;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedLoanSubPlan = id;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.secondaryDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.accentTeal : AppTheme.borderDark,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppTheme.accentTeal : AppTheme.textSecondary, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary)),
                      if (isPopular) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: AppTheme.accentTeal.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                          child: const Text("Popular", style: TextStyle(color: AppTheme.accentTeal, fontSize: 8, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(description, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(price, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isSelected ? AppTheme.accentTeal : AppTheme.textPrimary)),
          ],
        ),
      ),
    );
  }

  void _triggerLoanSubscriptionPaymentDialog(AppStateService state, String planName, double amount, String plan) {
    final phoneController = TextEditingController(text: state.currentUser?.phone ?? "");
    final pinController = TextEditingController();
    final paymentFormKey = GlobalKey<FormState>();
    bool isPaying = false;
    String selectedGateway = 'easypaisa';

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
                                "Premium Subscription",
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "$planName • PKR ${amount.toStringAsFixed(0)}",
                                style: const TextStyle(fontSize: 13, color: AppTheme.accentTeal, fontWeight: FontWeight.w600),
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
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        validator: (v) {
                          if (v == null || v.isEmpty) return "Phone number required";
                          if (v.length < 11) return "Enter complete mobile number";
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        labelText: "4-Digit Wallet PIN / OTP",
                        hintText: "xxxx",
                        prefixIcon: Icons.lock_outline_rounded,
                        controller: pinController,
                        keyboardType: TextInputType.number,
                        isPassword: true,
                        validator: (v) {
                          if (v == null || v.isEmpty) return "PIN / OTP required";
                          if (v.length != 4) return "Must be exactly 4 digits";
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
                        text: "Confirm & Pay Subscription",
                        isLoading: isPaying,
                        onPressed: () async {
                          if (!paymentFormKey.currentState!.validate()) return;
                          
                          setModalState(() {
                            isPaying = true;
                          });
                          
                          final success = await state.processSubscription(
                            selectedGateway.toUpperCase(),
                            phoneController.text,
                            plan,
                          );
                              
                          setModalState(() {
                            isPaying = false;
                          });
                          
                          if (context.mounted) {
                            Navigator.pop(context); // Close bottom sheet
                            
                            if (success) {
                              // Show success dialog
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
                                            "Subscription Activated!",
                                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                          ),
                                          const SizedBox(height: 10),
                                          const Text(
                                            "Your premium account is now active and the loan application form has been enabled.",
                                            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
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
                                              onPressed: () => Navigator.pop(context),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Error: Subscription failed. Verify your balance/number and try again."),
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
    final memberName = state.currentUser?.name ?? "";
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
            "Select a committee group's chat to open. Access is limited to joined members.",
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 25),
          
          if (committees.isEmpty) ...[
            const PremiumCard(
              child: Center(
                child: Text("No committees available.", style: TextStyle(color: AppTheme.textSecondary)),
              ),
            ),
          ] else ...[
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: committees.length,
              itemBuilder: (context, idx) {
                final comm = committees[idx];
                final bool isJoined = comm.joinedMembers.contains(memberName);
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
                            backgroundColor: isJoined ? AppTheme.accentTeal.withOpacity(0.12) : AppTheme.borderDark.withOpacity(0.2),
                            child: Icon(
                              isJoined ? Icons.groups_rounded : Icons.lock_outline_rounded,
                              color: isJoined ? AppTheme.accentTeal : AppTheme.textSecondary,
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
                                Row(
                                  children: [
                                    Text(
                                      "${comm.joinedMembers.length}/${comm.membersLimit} Members",
                                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isJoined ? AppTheme.accentGreen.withOpacity(0.12) : Colors.redAccent.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isJoined ? "Enrolled" : "Locked",
                                        style: TextStyle(
                                          fontSize: 8,
                                          color: isJoined ? AppTheme.accentGreen : Colors.redAccent,
                                          fontWeight: FontWeight.bold,
                                        ),
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
                
                final comm = committees.firstWhere((c) => c.id == _selectedRadioCommitteeId);
                final bool isJoined = comm.joinedMembers.contains(memberName);
                
                if (isJoined) {
                  setState(() {
                    _selectedChatCommitteeId = _selectedRadioCommitteeId;
                  });
                } else {
                  // ACCESS DENIED: Show SnackBar
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Access Denied: Committee chat access denied. You must be a joined member of this committee to access its chat."),
                      backgroundColor: Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
          ],
        ],
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
