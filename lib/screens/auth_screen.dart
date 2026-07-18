import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/state_service.dart';
import '../models/user.dart';
import '../utils/cnic_validator.dart';
import '../widgets/custom_widgets.dart';
import '../theme/app_theme.dart';
import 'subscription_screen.dart';
import 'manager_dashboard.dart';
import 'member_dashboard.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  bool _isLoginTab = true;
  bool _isManagerRole = false;
  bool _isLoading = false;

  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _cnicController = TextEditingController();
  final _phoneController = TextEditingController();

  late AnimationController _animController;
  late Animation<double> _fadeOffsetAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeOffsetAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _cnicController.dispose();
    _phoneController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _toggleTab() {
    setState(() {
      _isLoginTab = !_isLoginTab;
      _formKey.currentState?.reset();
    });
    _animController.reset();
    _animController.forward();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final state = Provider.of<AppStateService>(context, listen: false);
    bool success = false;

    if (_isLoginTab) {
      success = await state.login(_emailController.text, _passwordController.text, _isManagerRole ? UserRole.manager : UserRole.member);
    } else {
      success = await state.signUp(
        _nameController.text,
        _emailController.text,
        _passwordController.text,
        _cnicController.text,
        _phoneController.text,
        _isManagerRole ? UserRole.manager : UserRole.member,
      );
    }

    setState(() {
      _isLoading = false;
    });

    if (success && mounted) {
      final user = state.currentUser!;
      if (user.role == UserRole.manager) {
        if (user.isSubscribed) {
          // Nav to Manager Dashboard
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ManagerDashboard()),
          );
        } else {
          // Nav to Subscription plan screen first
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const SubscriptionScreen(role: UserRole.manager)),
          );
        }
      } else {
        // Members go straight to Dashboard (Free Signup)
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MemberDashboard()),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isLoginTab
                  ? "Incorrect email or password. Please try again."
                  : "This email is already registered with the same role. Try logging in.",
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Logo Area
                    const Icon(
                      Icons.groups_rounded,
                      size: 60,
                      color: AppTheme.accentTeal,
                    ),
                    const SizedBox(height: 10),
                    ScaledText(
                      state.translate('app_title'),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: AppTheme.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    ScaledText(
                      state.translate('tagline'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 35),

                    // Beautiful Tab Selector Card
                    Container(
                      height: 55,
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryDark,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.borderDark, width: 1),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: _isLoginTab ? null : _toggleTab,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _isLoginTab ? AppTheme.accentTeal : Colors.transparent,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                alignment: Alignment.center,
                                child: ScaledText(
                                  state.translate('login'),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: _isLoginTab ? AppTheme.primaryDark : AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: !_isLoginTab ? null : _toggleTab,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: !_isLoginTab ? AppTheme.accentTeal : Colors.transparent,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                alignment: Alignment.center,
                                child: ScaledText(
                                  state.translate('signup'),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: !_isLoginTab ? AppTheme.primaryDark : AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),

                    // Interactive Animated Form Body
                    FadeTransition(
                      opacity: _fadeOffsetAnim,
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        child: PremiumCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ScaledText(
                                _isLoginTab
                                    ? state.translate('welcome_back')
                                    : state.translate('lets_get_started'),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 20),

                              if (!_isLoginTab) ...[
                                CustomTextField(
                                  labelText: state.translate('name'),
                                  hintText: "Enter your full name",
                                  prefixIcon: Icons.person_outline,
                                  controller: _nameController,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return "Name required";
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                              ],

                              CustomTextField(
                                labelText: state.translate('email'),
                                hintText: "name@example.com",
                                prefixIcon: Icons.email_outlined,
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return "Email required";
                                  if (!v.contains("@")) return "Enter a valid email";
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              CustomTextField(
                                labelText: state.translate('password'),
                                hintText: "Enter security password",
                                prefixIcon: Icons.lock_outline,
                                controller: _passwordController,
                                isPassword: true,
                                validator: (v) {
                                  if (v == null || v.isEmpty) return "Password required";
                                  if (v.length < 6) return "At least 6 characters required";
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              if (!_isLoginTab) ...[
                                CustomTextField(
                                  labelText: state.translate('cnic'),
                                  hintText: "xxxxx-xxxxxxx-x",
                                  prefixIcon: Icons.credit_card_outlined,
                                  controller: _cnicController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [CnicInputFormatter()],
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return "CNIC required";
                                    if (!CnicValidator.isValid(v)) return "Must match format XXXXX-XXXXXXX-X";
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                CustomTextField(
                                  labelText: state.translate('phone'),
                                  hintText: "03xxxxxxxxx",
                                  prefixIcon: Icons.phone_android_outlined,
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(11),
                                  ],
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return "Phone number required";
                                    if (v.length != 11) return "Must be exactly 11 digits";
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Manager / Member selection checkbox row
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _isManagerRole = !_isManagerRole;
                                  });
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                                  child: Row(
                                    children: [
                                      Checkbox(
                                        value: _isManagerRole,
                                        activeColor: AppTheme.accentTeal,
                                        checkColor: AppTheme.primaryDark,
                                        onChanged: (val) {
                                          setState(() {
                                            _isManagerRole = val ?? false;
                                          });
                                        },
                                      ),
                                      Expanded(
                                        child: ScaledText(
                                          state.translate(_isLoginTab ? 'role_selection_login' : 'role_selection'),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              const SizedBox(height: 8),
                              GradientButton(
                                text: _isLoginTab
                                    ? state.translate('login')
                                    : state.translate('signup'),
                                isLoading: _isLoading,
                                onPressed: _handleSubmit,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),

                    // Quick Toggle Helper Text
                    GestureDetector(
                      onTap: _toggleTab,
                      child: ScaledText(
                        _isLoginTab
                            ? state.translate('dont_have_account')
                            : state.translate('already_have_account'),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.accentTeal,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
