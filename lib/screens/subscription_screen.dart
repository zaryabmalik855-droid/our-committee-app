import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/state_service.dart';
import '../models/user.dart';
import '../widgets/custom_widgets.dart';
import '../theme/app_theme.dart';
import 'manager_dashboard.dart';
import 'member_dashboard.dart';
import 'auth_screen.dart';

class SubscriptionScreen extends StatefulWidget {
  final UserRole role;

  const SubscriptionScreen({super.key, required this.role});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  String _selectedPlan = 'monthly'; // 'weekly', 'monthly', 'yearly'
  String _selectedGateway = 'easypaisa'; // 'easypaisa', 'jazzcash'
  
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  
  bool _isProcessing = false;
  final _sheetFormKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _triggerPaymentDialog(String planName, double amount) {
    _phoneController.text = Provider.of<AppStateService>(context, listen: false).currentUser?.phone ?? "";
    _otpController.clear();

    // Capture stable outer-widget references BEFORE opening the sheet.
    // The bottom-sheet builder will shadow 'context' with its own local context,
    // so we must grab everything we need from the parent widget here.
    final appState = Provider.of<AppStateService>(context, listen: false);
    final outerScaffold = ScaffoldMessenger.of(context);
    final outerNavigator = Navigator.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (BuildContext modalCtx, StateSetter setModalState) {
            final state = appState; // use pre-captured service, not context.watch inside sheet

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom,
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
                  key: _sheetFormKey,
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
                                state.translate('select_payment'),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              ScaledText(
                                "$planName • PKR ${amount.toStringAsFixed(0)}",
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
                          final digits = v.replaceAll(RegExp(r'[\s\-]'), '');
                          if (digits.length < 10) return "Enter complete mobile number";
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
                        text: state.translate('confirm_payment'),
                        isLoading: _isProcessing,
                        onPressed: () async {
                          if (!_sheetFormKey.currentState!.validate()) return;

                          // Snapshot values before async gap
                          final gateway = _selectedGateway.toUpperCase();
                          final phone = _phoneController.text;
                          final plan = _selectedPlan;

                          setModalState(() { _isProcessing = true; });

                          final success = await appState.processSubscription(gateway, phone, plan);

                          setModalState(() { _isProcessing = false; });

                          // Pop the sheet using its own navigator, then respond
                          outerNavigator.pop();

                          if (success) {
                            _showSuccessPopup();
                          } else {
                            outerScaffold.showSnackBar(
                              const SnackBar(
                                content: Text("Payment failed. Please try again with a valid mobile number."),
                                backgroundColor: Colors.redAccent,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
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

  void _showSuccessPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
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
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x3310B981),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 45,
                    color: AppTheme.primaryDark,
                  ),
                ),
                const SizedBox(height: 20),
                ScaledText(
                  "Payment Successful!",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                ScaledText(
                  "Welcome to Premium 'Our Committee'. Your subscription has been active.",
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
                    child: const Text("Launch Dashboard"),
                    onPressed: () {
                      Navigator.pop(context); // Close dialogue
                      if (widget.role == UserRole.manager) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const ManagerDashboard()),
                        );
                      } else {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const MemberDashboard()),
                        );
                      }
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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateService>();
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.premiumGradient,
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Custom Header Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textPrimary),
                      onPressed: () {
                        // Return to Auth
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => AuthScreen()),
                        );
                      },
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          "Go Premium",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48), // Balancing back button
                  ],
                ),
              ),
              
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: Icon(
                          Icons.workspace_premium_rounded,
                          size: 65,
                          color: AppTheme.accentGold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ScaledText(
                        "Activate Premium Features",
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      ScaledText(
                        widget.role == UserRole.manager
                            ? "Managers must activate a subscription to launch, manage, and drawing rotating committees."
                            : "Members can access committees for free, but require premium membership before submitting micro-loans.",
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),
                      
                      // Plans list
                      _buildPlanCard(
                        id: 'weekly',
                        title: state.translate('weekly'),
                        price: "PKR 50",
                        description: "Full access to dashboard and messaging for 7 days.",
                        icon: Icons.date_range_outlined,
                      ),
                      const SizedBox(height: 16),
                      
                      _buildPlanCard(
                        id: 'monthly',
                        title: state.translate('monthly'),
                        price: "PKR 300",
                        description: "Most popular choice. Direct group chats and loan permissions for 30 days.",
                        icon: Icons.calendar_month_outlined,
                        isPopular: true,
                      ),
                      const SizedBox(height: 16),
                      
                      _buildPlanCard(
                        id: 'yearly',
                        title: state.translate('yearly'),
                        price: "PKR 3600",
                        description: "Best Value! Save 33% over standard monthly rates. Includes prioritized support.",
                        icon: Icons.stars_rounded,
                        isBestValue: true,
                      ),
                      const SizedBox(height: 40),
                      
                      GradientButton(
                        text: state.translate('subscribe_now'),
                        gradientColors: const [AppTheme.accentGold, AppTheme.accentOrange],
                        onPressed: () {
                          double amount = 300;
                          String planName = "Monthly Plan";
                          if (_selectedPlan == 'weekly') {
                            amount = 50;
                            planName = "Weekly Plan";
                          } else if (_selectedPlan == 'yearly') {
                            amount = 3600;
                            planName = "Yearly Plan";
                          }
                          _triggerPaymentDialog(planName, amount);
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required String id,
    required String title,
    required String price,
    required String description,
    required IconData icon,
    bool isPopular = false,
    bool isBestValue = false,
  }) {
    final bool isSelected = _selectedPlan == id;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPlan = id;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.secondaryDark : AppTheme.secondaryDark.withOpacity(0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (isBestValue ? AppTheme.accentGold : AppTheme.accentTeal)
                : AppTheme.borderDark,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (isBestValue ? AppTheme.accentGold : AppTheme.accentTeal).withOpacity(0.15),
                    blurRadius: 15,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 30,
              color: isSelected
                  ? (isBestValue ? AppTheme.accentGold : AppTheme.accentTeal)
                  : AppTheme.textSecondary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (isPopular) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.accentTeal.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            "Popular",
                            style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.accentTeal,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      if (isBestValue) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.accentGold.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            "Save 33%",
                            style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.accentGold,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              price,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? (isBestValue ? AppTheme.accentGold : AppTheme.accentTeal)
                    : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
