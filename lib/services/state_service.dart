import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/committee.dart';
import '../models/loan.dart';
import '../models/chat.dart';
import '../models/notification.dart';
import '../models/receipt.dart';

class AppStateService extends ChangeNotifier {
  // Authentication & Session
  UserModel? _currentUser;
  String? _jwtToken;
  
  UserModel? get currentUser => _currentUser;
  String? get jwtToken => _jwtToken;
  bool get isAuthenticated => _jwtToken != null;

  // Emergency Support Pool (1% of loan interest goes here)
  double _emergencyPoolBalance = 5000.0;
  double get emergencyPoolBalance => _emergencyPoolBalance;

  // Language & Custom Font Sizing
  String _currentLanguage = 'en'; // 'en' or 'ur'
  String _fontSizeSetting = 'medium'; // 'small', 'medium', 'large'

  String get currentLanguage => _currentLanguage;
  String get fontSizeSetting => _fontSizeSetting;

  double get fontMultiplier {
    switch (_fontSizeSetting) {
      case 'small':
        return 0.85;
      case 'large':
        return 1.25;
      case 'medium':
      default:
        return 1.0;
    }
  }

  // Pre-populated Mock Data for elegant presentation
  final List<UserModel> _users = [
    UserModel(
      name: "Ali Ahmed",
      email: "ali@gmail.com",
      password: "password123",
      cnic: "42101-1234567-1",
      phone: "0300-1234567",
      role: UserRole.manager,
      isSubscribed: true,
      subscriptionPlan: "monthly",
      balance: 100000.0,
    ),
    UserModel(
      name: "Fatima Khan",
      email: "fatima@gmail.com",
      password: "password123",
      cnic: "35202-7654321-2",
      phone: "0312-9876543",
      role: UserRole.member,
      isSubscribed: false,
      balance: 100000.0,
    ),
    UserModel(
      name: "Zainab Bibi",
      email: "zainab@gmail.com",
      password: "password123",
      cnic: "34101-9988776-4",
      phone: "0321-5556677",
      role: UserRole.member,
      isSubscribed: true,
      subscriptionPlan: "weekly",
      balance: 100000.0,
    ),
  ];

  final List<CommitteeModel> _committees = [
    CommitteeModel(
      id: "c1",
      name: "Roshan Savings 2026",
      description: "Monthly rotating savings pool for local small vendors.",
      totalAmount: 100000,
      monthlyContribution: 10000,
      membersLimit: 10,
      joinedMembers: ["Ali Ahmed", "Fatima Khan", "Zainab Bibi", "Hamza Shah", "Sana Ali"],
      installmentsPaid: 4,
      totalInstallments: 10,
      drawWinners: ["Zainab Bibi", "Hamza Shah"],
      status: "active",
      frequency: "monthly",
    ),
    CommitteeModel(
      id: "c2",
      name: "Gold Circle Bisi",
      description: "Short term premium drawing cycle.",
      totalAmount: 40000,
      monthlyContribution: 5000,
      membersLimit: 8,
      joinedMembers: ["Ali Ahmed", "Sana Ali", "Usman Ghafoor", "Zainab Bibi"],
      installmentsPaid: 2,
      totalInstallments: 8,
      drawWinners: ["Usman Ghafoor"],
      status: "active",
      frequency: "weekly",
    ),
  ];

  final List<LoanModel> _loans = [
    LoanModel(
      id: "l1",
      applicantName: "Zainab Bibi",
      applicantEmail: "zainab@gmail.com",
      amount: 15000,
      reason: "To purchase sewing materials for boutique work.",
      monthlyRepayment: 1030,
      durationMonths: 15,
      interestAmount: 450,
      totalRepayable: 15450,
      status: "pending",
      dateRequested: DateTime.now().subtract(const Duration(days: 2)),
    ),
    LoanModel(
      id: "l2",
      applicantName: "Hamza Shah",
      applicantEmail: "hamza@gmail.com",
      amount: 20000,
      reason: "Paying semester university fee.",
      monthlyRepayment: 2060,
      durationMonths: 10,
      interestAmount: 600,
      totalRepayable: 20600,
      status: "approved",
      dateRequested: DateTime.now().subtract(const Duration(days: 5)),
    ),
  ];

  final List<ChatMessage> _chatHistory = [
    ChatMessage(
      committeeId: "c1",
      senderName: "Ali Ahmed",
      senderRole: "manager",
      message: "Assalam-o-Alaikum members! Welcome to Our Committee group chat.",
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    ChatMessage(
      committeeId: "c1",
      senderName: "Zainab Bibi",
      senderRole: "member",
      message: "Walaikum Assalam, sir. When is the next lucky draw scheduled?",
      timestamp: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    ChatMessage(
      committeeId: "c1",
      senderName: "Ali Ahmed",
      senderRole: "manager",
      message: "The lucky draw wheel will spin this Friday evening. Keep contributions ready!",
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
    ),
  ];

  final List<AppNotification> _notifications = [
    AppNotification(
      id: "n1",
      title: "Lucky Draw Result!",
      body: "Zainab Bibi has won the June cycle draw for Roshan Savings 2026!",
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      type: "draw",
    ),
    AppNotification(
      id: "n2",
      title: "Monthly Contribution Reminder",
      body: "Roshan Savings 2026: Please submit PKR 10,000 contribution by the 5th.",
      timestamp: DateTime.now().subtract(const Duration(hours: 12)),
      type: "payment",
    ),
  ];

  // Pre-populated mock receipts history
  final List<ReceiptModel> _receipts = [
    ReceiptModel(
      id: "rec1",
      userEmail: "zainab@gmail.com",
      userName: "Zainab Bibi",
      type: "Subscription",
      amount: 50.0,
      referenceId: "weekly",
      referenceName: "Weekly Premium Subscription",
      gateway: "EASYPAISA",
      phoneOrAccount: "0321-5556677",
      timestamp: DateTime.now().subtract(const Duration(days: 4)),
    ),
    ReceiptModel(
      id: "rec2",
      userEmail: "zainab@gmail.com",
      userName: "Zainab Bibi",
      type: "Committee Installment",
      amount: 10000.0,
      referenceId: "c1",
      referenceName: "Roshan Savings 2026",
      gateway: "EASYPAISA",
      phoneOrAccount: "0321-5556677",
      timestamp: DateTime.now().subtract(const Duration(days: 3)),
    ),
    ReceiptModel(
      id: "rec3",
      userEmail: "fatima@gmail.com",
      userName: "Fatima Khan",
      type: "Committee Installment",
      amount: 10000.0,
      referenceId: "c1",
      referenceName: "Roshan Savings 2026",
      gateway: "JAZZCASH",
      phoneOrAccount: "0312-9876543",
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  // Emergency Pool is now only used for loans directly

  // Installment timing: userEmail -> committeeId -> last payment DateTime
  final Map<String, Map<String, DateTime>> _lastInstallmentDates = {};

  // Lucky draw timing: committeeId -> last draw DateTime
  final Map<String, DateTime> _lastDrawDates = {};

  // Getters
  List<UserModel> get users => _users;
  List<CommitteeModel> get committees => _committees;
  List<LoanModel> get loans => _loans;
  List<ChatMessage> get chatHistory => _chatHistory;
  List<AppNotification> get notifications => _notifications;
  List<ReceiptModel> get receipts => _receipts;

  // Urdu & English Translation Dictionary Mapping
  static const Map<String, Map<String, String>> _translations = {
    'en': {
      'app_title': 'Our Committee',
      'tagline': 'Secure Rotating Committees & Loans',
      'login': 'Login',
      'signup': 'Sign Up',
      'email': 'Email Address',
      'password': 'Password',
      'name': 'Full Name',
      'cnic': 'CNIC (e.g. 42101-1234567-1)',
      'phone': 'Phone Number (e.g. 0300-1234567)',
      'manager': 'Manager',
      'member': 'Member',
      'role_selection': 'Register as Manager?',
      'role_selection_login': 'Login as Manager?',
      'dont_have_account': "Don't have an account? Sign Up",
      'already_have_account': 'Already have an account? Login',
      'welcome_back': 'Welcome Back!',
      'lets_get_started': "Let's Get Started",
      'logout': 'Logout',
      'settings': 'Settings',
      'chats': 'Group Chats',
      'home': 'Home',
      'create_committee': 'Create Committee',
      'about_us': 'About Us',
      'about_description': 'Our Committee is a secure, digital rotating savings (Bisi/Kameti) and zero-interest peer micro-loan application designed to foster local financial inclusion, transparency, and safety within trust networks in Pakistan.',
      'language': 'Language / زبان',
      'font_size': 'Font Size',
      'weekly': 'Weekly Plan',
      'monthly': 'Monthly Plan',
      'yearly': 'Yearly Plan',
      'subscribe_now': 'Subscribe Now',
      'easypaisa': 'Easypaisa',
      'jazzcash': 'JazzCash',
      'select_payment': 'Select Payment Method',
      'enter_otp': 'Enter 4-Digit Security OTP',
      'confirm_payment': 'Confirm Payment',
      'loan_tab': 'Loans',
      'loan_request': 'Request Loan',
      'loan_amount': 'Loan Amount (PKR 10,000 - 20,000)',
      'loan_reason': 'Reason for Loan',
      'loan_repayment': 'Monthly Repayment Rate',
      'loan_limit_error': 'Amount must be between 10,000 PKR and 20,000 PKR',
      'repayment_rate_info': 'Repayments are locked to exactly 1,000 PKR or 2,000 PKR monthly',
      'submit_request': 'Submit Request',
      'no_subscribed_msg': 'You must be subscribed to request a loan.',
      'status': 'Status',
      'approved': 'Approved',
      'pending': 'Pending',
      'rejected': 'Rejected',
      'active': 'Active',
      'completed': 'Completed',
      'lucky_wheel': 'Lucky Draw Wheel',
      'spin': 'SPIN!',
      'winner': 'Winner!',
      'recent_notifications': 'Recent Notifications',
      'paid': 'Paid',
      'remaining': 'Remaining',
      'out_of': 'out of',
    },
    'ur': {
      'app_title': 'ہماری کمیٹی',
      'tagline': 'محفوظ روٹیٹنگ کمیٹیاں اور قرضے',
      'login': 'لاگ ان کریں',
      'signup': 'سائن اپ کریں',
      'email': 'ای میل ایڈریس',
      'password': 'پاس ورڈ',
      'name': 'پورا نام',
      'cnic': 'شناختی کارڈ (42101-1234567-1)',
      'phone': 'فون نمبر (0300-1234567)',
      'manager': 'منیجر',
      'member': 'ممبر',
      'role_selection': 'بطور منیجر رجسٹر کریں؟',
      'role_selection_login': 'بطور منیجر لاگ ان کریں؟',
      'dont_have_account': "اکاؤنٹ نہیں ہے؟ سائن اپ کریں",
      'already_have_account': 'پہلے سے اکاؤنٹ ہے؟ لاگ ان',
      'welcome_back': 'خوش آمدید!',
      'lets_get_started': 'شروع کرتے ہیں',
      'logout': 'لاگ آؤٹ',
      'settings': 'ترتیبات',
      'chats': 'گروپ چیٹ',
      'home': 'ہوم',
      'create_committee': 'کمیٹی بنائیں',
      'about_us': 'ہمارے بارے میں',
      'about_description': 'ہماری کمیٹی ایک محفوظ، ڈیجیٹل روٹیٹنگ سیونگ (بی سی/کمیٹی) اور بغیر سود کے مائیکرو لون کی ایپلی کیشن ہے جو پاکستان میں مقامی مالیاتی شمولیت، شفافیت اور نیٹ ورکس میں حفاظت کو فروغ دینے کے لیے بنائی گئی ہے۔',
      'language': 'Language / زبان',
      'font_size': 'فونٹ کا سائز',
      'weekly': 'ہفتہ وار پلان',
      'monthly': 'ماہانہ پلان',
      'yearly': 'سالانہ پلان',
      'subscribe_now': 'سبسکرائب کریں',
      'easypaisa': 'ایزی پیسہ',
      'jazzcash': 'جاز کیش',
      'select_payment': 'طریقہ ادائیگی منتخب کریں',
      'enter_otp': '4 ہندسوں کا سیکیورٹی OTP درج کریں',
      'confirm_payment': 'ادائیگی کی تصدیق کریں',
      'loan_tab': 'قرضے',
      'loan_request': 'قرض کی درخواست',
      'loan_amount': 'قرض کی رقم (10,000 - 20,000 PKR)',
      'loan_reason': 'قرض کی وجہ',
      'loan_repayment': 'ماہانہ واپسی کی رقم',
      'loan_limit_error': 'رقم 10,000 PKR اور 20,000 PKR کے درمیان ہونی چاہیے',
      'repayment_rate_info': 'واپسی ماہانہ بالکل 1,000 PKR یا 2,000 PKR پر لاک ہے',
      'submit_request': 'درخواست جمع کروائیں',
      'no_subscribed_msg': 'قرض کی درخواست کے لیے آپ کا سبسکرائب ہونا ضروری ہے۔',
      'status': 'حیثیت',
      'approved': 'منظور شدہ',
      'pending': 'زیر التواء',
      'rejected': 'مسترد',
      'active': 'سرگرم',
      'completed': 'مکمل',
      'lucky_wheel': 'لکی ڈرا وہیل',
      'spin': 'گھمائیں!',
      'winner': 'فاتح!',
      'recent_notifications': 'حالیہ اطلاعات',
      'paid': 'ادا شدہ',
      'remaining': 'باقی رقم',
      'out_of': 'کل میں سے',
    }
  };

  // Helper method for translations
  String translate(String key) {
    return _translations[_currentLanguage]?[key] ?? key;
  }

  // Settings modification
  void toggleLanguage() {
    _currentLanguage = _currentLanguage == 'en' ? 'ur' : 'en';
    notifyListeners();
  }

  void setFontSize(String size) {
    _fontSizeSetting = size;
    notifyListeners();
  }

  // Session Persistence logic
  Future<void> _saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (_currentUser != null) {
      await prefs.setString('currentUser', jsonEncode(_currentUser!.toJson()));
      await prefs.setString('jwtToken', _jwtToken ?? '');
      final drawDatesJson = jsonEncode(_lastDrawDates.map((k, v) => MapEntry(k, v.toIso8601String())));
      await prefs.setString('lastDrawDates', drawDatesJson);
    }
  }

  Future<bool> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('currentUser');
    final token = prefs.getString('jwtToken');
    final drawDatesJson = prefs.getString('lastDrawDates');
    if (drawDatesJson != null) {
      try {
        final decoded = jsonDecode(drawDatesJson) as Map<String, dynamic>;
        _lastDrawDates.clear();
        decoded.forEach((k, v) {
          _lastDrawDates[k] = DateTime.parse(v as String);
        });
      } catch (_) {}
    }
    if (userJson != null && token != null && token.isNotEmpty) {
      try {
        final decoded = jsonDecode(userJson);
        _currentUser = UserModel.fromJson(decoded);
        _jwtToken = token;
        
        // Make sure the mock _users list contains this user so routing/logic doesn't fail
        final idx = _users.indexWhere((u) => u.email.toLowerCase() == _currentUser!.email.toLowerCase() && u.role == _currentUser!.role);
        if (idx == -1) {
          _users.add(_currentUser!);
        } else {
          // Sync state from saved session
          _users[idx] = _currentUser!;
        }
        
        notifyListeners();
        return true;
      } catch (e) {
        // Parse error, clear corrupt session
        await clearSession();
      }
    }
    return false;
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('currentUser');
    await prefs.remove('jwtToken');
    await prefs.remove('lastDrawDates');
  }
  }

  // Authentication Logic
  Future<bool> login(String email, String password, UserRole role) async {
    // Artificial networking delay
    await Future.delayed(const Duration(milliseconds: 800));

    try {
      // Find user by email + password only (no role filter) so one account
      // can log in as either Manager or Member with the same credentials.
      final foundUser = _users.firstWhere(
        (u) => u.email.toLowerCase() == email.trim().toLowerCase() && u.password == password,
      );
      
      // Sync balance across all profiles sharing this email
      double sharedBalance = foundUser.balance;
      String? sharedProvider = foundUser.linkedProvider;
      String? sharedAccountNo = foundUser.linkedAccountNo;
      for (var u in _users) {
        if (u.email.toLowerCase() == email.trim().toLowerCase()) {
          sharedBalance = u.balance; // last synced value wins
          sharedProvider = u.linkedProvider;
          sharedAccountNo = u.linkedAccountNo;
        }
      }

      // Determine subscription status for the requested role:
      // If requesting manager role and the found user is a manager, honour their isSubscribed.
      // If role-switching (e.g. member account logging in as manager), treat as not subscribed
      // unless a separate manager profile exists for this email.
      bool resolvedSubscribed = foundUser.isSubscribed;
      String resolvedPlan = foundUser.subscriptionPlan;
      if (foundUser.role != role) {
        // Look for a profile matching the requested role
        final roleProfile = _users.where(
          (u) => u.email.toLowerCase() == email.trim().toLowerCase() && u.role == role,
        );
        if (roleProfile.isNotEmpty) {
          resolvedSubscribed = roleProfile.first.isSubscribed;
          resolvedPlan = roleProfile.first.subscriptionPlan;
        } else {
          // No existing profile for this role — create one in memory so routing works
          final switchedProfile = UserModel(
            name: foundUser.name,
            email: foundUser.email,
            password: foundUser.password,
            cnic: foundUser.cnic,
            phone: foundUser.phone,
            role: role,
            isSubscribed: false,
            subscriptionPlan: 'none',
            balance: sharedBalance,
            linkedProvider: sharedProvider,
            linkedAccountNo: sharedAccountNo,
          );
          _users.add(switchedProfile);
          resolvedSubscribed = false;
          resolvedPlan = 'none';
        }
      }

      // Build the active session user with the requested role
      _currentUser = UserModel(
        name: foundUser.name,
        email: foundUser.email,
        password: foundUser.password,
        cnic: foundUser.cnic,
        phone: foundUser.phone,
        role: role,
        isSubscribed: resolvedSubscribed,
        subscriptionPlan: resolvedPlan,
        balance: sharedBalance,
        linkedProvider: sharedProvider,
        linkedAccountNo: sharedAccountNo,
      );

      // Also keep the in-list profile in sync
      final idx = _users.indexWhere(
        (u) => u.email.toLowerCase() == email.trim().toLowerCase() && u.role == role,
      );
      if (idx != -1) {
        _users[idx].balance = sharedBalance;
        _users[idx].linkedProvider = sharedProvider;
        _users[idx].linkedAccountNo = sharedAccountNo;
      }

      _jwtToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.mock_session_token_for_${foundUser.email}";
      await _saveSession();
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> signUp(
    String name,
    String email,
    String password,
    String cnic,
    String phone,
    UserRole role,
  ) async {
    await Future.delayed(const Duration(milliseconds: 1000));

    // Check if email already exists with the same role
    if (_users.any((u) => u.email.toLowerCase() == email.trim().toLowerCase() && u.role == role)) {
      return false;
    }

    final newUser = UserModel(
      name: name,
      email: email,
      password: password,
      cnic: cnic,
      phone: phone,
      role: role,
      isSubscribed: false, // Managers must subscribe, members are free until loan
      balance: 0.0, // New registration balance must be 0 by default
    );

    _users.add(newUser);
    _currentUser = newUser;
    _jwtToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.mock_session_token_for_$email";
    await _saveSession();
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    _currentUser = null;
    _jwtToken = null;
    await clearSession();
    notifyListeners();
  }

  // Payment Gateways & Subscription Logic
  Future<bool> processSubscription(String gateway, String number, String plan) async {
    await Future.delayed(const Duration(milliseconds: 1200)); // Simulate gateway connection

    // Normalize: strip dashes, spaces and other separators so "0321-5556677" → "03215556677"
    final normalizedNumber = number.replaceAll(RegExp(r'[\s\-]'), '');
    
    if (normalizedNumber.length >= 10 && _currentUser != null) {
      double cost = 300.0; // monthly default PKR 300
      if (plan == 'weekly') cost = 50.0;
      else if (plan == 'yearly') cost = 3600.0;

      // Subscription is charged via Easypaisa/JazzCash mobile gateway (external payment).
      // No deduction from in-app wallet balance needed here.
      _currentUser!.isSubscribed = true;
      _currentUser!.subscriptionPlan = plan;
      
      // Add subscription fees to the emergency support pool
      _emergencyPoolBalance += cost;

      // Also update subscription details for the logged-in profile specifically
      final idx = _users.indexWhere((u) => u.email.toLowerCase() == _currentUser!.email.toLowerCase() && u.role == _currentUser!.role);
      if (idx != -1) {
        _users[idx].isSubscribed = true;
        _users[idx].subscriptionPlan = plan;
      }

      // Generate a receipt
      _receipts.insert(0, ReceiptModel(
        id: "rec_${_receipts.length + 1}",
        userEmail: _currentUser!.email,
        userName: _currentUser!.name,
        type: "Subscription",
        amount: cost,
        referenceId: plan,
        referenceName: "${plan.toUpperCase()} Premium Subscription",
        gateway: gateway,
        phoneOrAccount: number,
        timestamp: DateTime.now(),
      ));

      addNotification(
        "Subscription Activated!",
        "Thank you for choosing the ${_currentUser!.subscriptionPlan} plan using $gateway. Your account status is now Premium. PKR ${cost.toStringAsFixed(0)} deducted from wallet.",
        "payment"
      );
      
      notifyListeners();
      return true;
    }
    return false;
  }

  // Join a Rotating Committee
  bool joinCommittee(String committeeId) {
    if (_currentUser == null) return false;
    final idx = _committees.indexWhere((c) => c.id == committeeId);
    if (idx == -1) return false;
    
    final committee = _committees[idx];
    if (committee.joinedMembers.contains(_currentUser!.name)) return false;
    if (committee.joinedMembers.length >= committee.membersLimit) return false;

    committee.joinedMembers.add(_currentUser!.name);
    addNotification(
      "Joined Savings Pool!",
      "${_currentUser!.name} has successfully joined '${committee.name}'.",
      "payment"
    );
    notifyListeners();
    return true;
  }

  // Profile Edit (Username & Password only)
  void updateProfile(String newName, String newPassword) {
    if (_currentUser == null || newName.trim().isEmpty) return;
    
    final idx = _users.indexWhere((u) => u.email.toLowerCase() == _currentUser!.email.toLowerCase());
    if (idx != -1) {
      final oldName = _currentUser!.name;
      final targetPassword = newPassword.isNotEmpty ? newPassword : _currentUser!.password;
      
      // Update all users sharing this email
      for (int i = 0; i < _users.length; i++) {
        if (_users[i].email.toLowerCase() == _currentUser!.email.toLowerCase()) {
          _users[i] = UserModel(
            name: newName.trim(),
            email: _users[i].email,
            password: targetPassword,
            cnic: _users[i].cnic,
            phone: _users[i].phone,
            role: _users[i].role,
            isSubscribed: _users[i].isSubscribed,
            subscriptionPlan: _users[i].subscriptionPlan,
            balance: _users[i].balance,
          );
        }
      }
      
      _currentUser = UserModel(
        name: newName.trim(),
        email: _currentUser!.email,
        password: targetPassword,
        cnic: _currentUser!.cnic,
        phone: _currentUser!.phone,
        role: _currentUser!.role,
        isSubscribed: _currentUser!.isSubscribed,
        subscriptionPlan: _currentUser!.subscriptionPlan,
        balance: _currentUser!.balance,
      );

      // Rename user in committees
      for (var c in _committees) {
        for (int i = 0; i < c.joinedMembers.length; i++) {
          if (c.joinedMembers[i] == oldName) {
            c.joinedMembers[i] = newName.trim();
          }
        }
        for (int i = 0; i < c.drawWinners.length; i++) {
          if (c.drawWinners[i] == oldName) {
            c.drawWinners[i] = newName.trim();
          }
        }
      }

      addNotification(
        "Profile Updated",
        "Username / password changed successfully.",
        "payment"
      );
      notifyListeners();
    }
  }

  // Committee creation
  void createCommittee(
    String name,
    String description,
    double totalAmount,
    double contribution,
    int membersLimit,
    String frequency,
  ) {
    final newId = "c${_committees.length + 1}";
    final totalInstallments = (totalAmount / contribution).round();
    
    final newCommittee = CommitteeModel(
      id: newId,
      name: name,
      description: description,
      totalAmount: totalAmount,
      monthlyContribution: contribution,
      membersLimit: membersLimit,
      joinedMembers: [_currentUser?.name ?? "Manager"],
      totalInstallments: totalInstallments,
      drawWinners: [],
      status: "active",
      frequency: frequency,
    );

    _committees.insert(0, newCommittee);
    addNotification(
      "Committee Created",
      "New committee '$name' has been launched successfully with a PKR $totalAmount pool.",
      "payment"
    );
    notifyListeners();
  }

  // Simple Loan Request — no interest, repayment is principal divided equally over duration
  bool requestLoan(double amount, String reason, int durationMonths) {
    if (_currentUser == null) return false;
    
    // Security check: require active subscription before allowing loan application
    if (!_currentUser!.isSubscribed || _isSubscriptionExpired) {
      return false;
    }
    
    if (amount < 1000) return false;

    const double interestAmount = 0.0; // Zero interest — simple loan
    final double totalRepayable = amount;  // No interest added
    final double monthlyRepayment = amount / durationMonths;
    final newId = "l${_loans.length + 1}";

    final newLoan = LoanModel(
      id: newId,
      applicantName: _currentUser!.name,
      applicantEmail: _currentUser!.email,
      amount: amount,
      reason: reason,
      monthlyRepayment: monthlyRepayment,
      durationMonths: durationMonths,
      interestAmount: interestAmount,
      totalRepayable: totalRepayable,
      status: "pending",
      dateRequested: DateTime.now(),
    );

    _loans.insert(0, newLoan);
    addNotification(
      "New Loan Application",
      "${_currentUser!.name} has requested a loan of PKR ${amount.toStringAsFixed(0)}.",
      "loan"
    );
    notifyListeners();
    return true;
  }

  // Manage loans approval/rejection
  void updateLoanStatus(String loanId, String status) {
    final idx = _loans.indexWhere((l) => l.id == loanId);
    if (idx != -1) {
      final oldStatus = _loans[idx].status;
      _loans[idx].status = status;

      // When a loan is approved, disburse directly from the emergency pool
      if (status == 'approved' && oldStatus != 'approved') {
        _emergencyPoolBalance -= _loans[idx].amount;
      }

      // Dispatch notification
      addNotification(
        "Loan Application Status",
        "Your loan of PKR ${_loans[idx].amount.toStringAsFixed(0)} was $status by the Manager.",
        "loan"
      );
      notifyListeners();
    }
  }

  // Repay a loan installment
  Future<bool> repayLoanInstallment(String loanId, String gateway, String phone) async {
    await Future.delayed(const Duration(milliseconds: 1200));

    if (_currentUser == null) return false;
    final idx = _loans.indexWhere((l) => l.id == loanId);
    if (idx == -1) return false;

    final loan = _loans[idx];
    if (loan.status != 'approved') return false;
    if (loan.installmentsPaid >= loan.durationMonths) return false;

    if (_currentUser!.balance < loan.monthlyRepayment) return false;

    _currentUser!.balance -= loan.monthlyRepayment;
    for (var u in _users) {
      if (u.email.toLowerCase() == _currentUser!.email.toLowerCase()) {
        u.balance = _currentUser!.balance;
      }
    }

    loan.installmentsPaid++;
    _emergencyPoolBalance += loan.monthlyRepayment;

    if (loan.installmentsPaid >= loan.durationMonths) {
      loan.status = 'completed';
    }

    _receipts.insert(0, ReceiptModel(
      id: "rec_${_receipts.length + 1}",
      userEmail: _currentUser!.email,
      userName: _currentUser!.name,
      type: "Loan Repayment",
      amount: loan.monthlyRepayment,
      referenceId: loan.id,
      referenceName: "Loan Repayment",
      gateway: gateway,
      phoneOrAccount: phone,
      timestamp: DateTime.now(),
    ));

    addNotification(
      "Loan Repayment Successful",
      "You have repaid PKR ${loan.monthlyRepayment.toStringAsFixed(0)} towards your loan. ${loan.status == 'completed' ? 'Loan fully paid off!' : ''}",
      "payment"
    );
    notifyListeners();
    return true;
  }

  /// Returns true if the current user is allowed to pay an installment now.
  bool canPayInstallment(String committeeId) {
    final email = _currentUser?.email;
    if (email == null) return false;
    final lastDate = _lastInstallmentDates[email]?[committeeId];
    if (lastDate == null) return true; // never paid → always allowed
    final comm = _committees.firstWhere((c) => c.id == committeeId, orElse: () => _committees.first);
    final now = DateTime.now();
    if (comm.frequency == 'daily') {
      return now.difference(lastDate).inDays >= 1;
    } else if (comm.frequency == 'weekly') {
      return now.difference(lastDate).inDays >= 7;
    } else {
      // Monthly: allowed once the calendar month changes
      return now.month != lastDate.month || now.year != lastDate.year;
    }
  }

  /// Returns the DateTime when the next installment is allowed, or null if allowed now.
  DateTime? nextInstallmentAllowedAt(String committeeId) {
    final email = _currentUser?.email;
    if (email == null) return null;
    final lastDate = _lastInstallmentDates[email]?[committeeId];
    if (lastDate == null) return null;
    final comm = _committees.firstWhere((c) => c.id == committeeId, orElse: () => _committees.first);
    if (comm.frequency == 'daily') {
      return lastDate.add(const Duration(days: 1));
    } else if (comm.frequency == 'weekly') {
      return lastDate.add(const Duration(days: 7));
    } else {
      return DateTime(lastDate.year, lastDate.month + 1, 1);
    }
  }

  // ─── Lucky Draw Timing Helpers ──────────────────────────────────────────────

  /// Returns true if the committee's draw cycle allows a new spin now.
  bool canPerformDraw(String committeeId) {
    final lastDate = _lastDrawDates[committeeId];
    if (lastDate == null) return true;
    final comm = _committees.firstWhere((c) => c.id == committeeId, orElse: () => _committees.first);
    final now = DateTime.now();
    final freq = comm.frequency.toLowerCase();
    
    if (freq == 'daily') {
      return now.difference(lastDate).inDays >= 1;
    } else if (freq == 'weekly') {
      return now.difference(lastDate).inDays >= 7;
    } else if (freq == 'monthly') {
      return now.month != lastDate.month || now.year != lastDate.year;
    } else if (freq == 'yearly') {
      return now.year != lastDate.year;
    } else {
      return now.month != lastDate.month || now.year != lastDate.year;
    }
  }

  /// Returns when the next draw is allowed, or null if allowed now.
  DateTime? nextDrawAllowedAt(String committeeId) {
    final lastDate = _lastDrawDates[committeeId];
    if (lastDate == null) return null;
    final comm = _committees.firstWhere((c) => c.id == committeeId, orElse: () => _committees.first);
    final freq = comm.frequency.toLowerCase();
    
    if (freq == 'daily') {
      return lastDate.add(const Duration(days: 1));
    } else if (freq == 'weekly') {
      return lastDate.add(const Duration(days: 7));
    } else if (freq == 'monthly') {
      return DateTime(lastDate.year, lastDate.month + 1, 1);
    } else if (freq == 'yearly') {
      return DateTime(lastDate.year + 1, 1, 1);
    } else {
      return DateTime(lastDate.year, lastDate.month + 1, 1);
    }
  }

  /// Returns the current independent status of a committee's Lucky Draw cycle.
  String getLuckyDrawStatus(String committeeId) {
    final comm = _committees.firstWhere((c) => c.id == committeeId, orElse: () => _committees.first);
    if (comm.status == 'completed' || comm.installmentsPaid >= comm.totalInstallments) {
      return 'Closed';
    }
    final eligibleMembers = comm.joinedMembers
        .where((member) => !comm.drawWinners.contains(member))
        .toList();
    if (eligibleMembers.isEmpty) {
      return 'Completed';
    }
    if (canPerformDraw(committeeId)) {
      return 'Active';
    } else {
      return 'Upcoming';
    }
  }

  // Pay rotating committee installment via payment gateway simulation
  Future<bool> payCommitteeInstallment(String committeeId, String gateway, String phone) async {
    await Future.delayed(const Duration(milliseconds: 1200)); // Simulate gateway transaction

    if (_currentUser == null) return false;

    final idx = _committees.indexWhere((c) => c.id == committeeId);
    if (idx == -1) return false;

    final comm = _committees[idx];
    if (comm.installmentsPaid >= comm.totalInstallments) return false;

    // ── Timing restriction: one installment per cycle ──
    if (!canPayInstallment(committeeId)) return false;

    if (_currentUser!.balance < comm.monthlyContribution) return false; // Insufficient wallet balance

    _currentUser!.balance -= comm.monthlyContribution;

    // Update in _users list for all profiles sharing this email
    for (var u in _users) {
      if (u.email.toLowerCase() == _currentUser!.email.toLowerCase()) {
        u.balance = _currentUser!.balance;
      }
    }

    comm.installmentsPaid += 1;

    // Record this payment's timestamp for timing enforcement
    _lastInstallmentDates.putIfAbsent(_currentUser!.email, () => {})[committeeId] = DateTime.now();

    // Generate a receipt
    _receipts.insert(0, ReceiptModel(
      id: "rec_${_receipts.length + 1}",
      userEmail: _currentUser!.email,
      userName: _currentUser!.name,
      type: "Committee Installment",
      amount: comm.monthlyContribution,
      referenceId: comm.id,
      referenceName: comm.name,
      gateway: gateway,
      phoneOrAccount: phone,
      timestamp: DateTime.now(),
    ));

    addNotification(
      "Committee Contribution Paid",
      "${_currentUser!.name} paid PKR ${comm.monthlyContribution.toStringAsFixed(0)} for '${comm.name}' via $gateway.",
      "payment"
    );
    notifyListeners();
    return true;
  }

  // Add member to committee by name
  bool addMemberToCommittee(String committeeId, String memberName) {
    if (_currentUser?.role != UserRole.manager) return false;

    final idx = _committees.indexWhere((c) => c.id == committeeId);
    if (idx == -1) return false;

    final comm = _committees[idx];
    if (comm.joinedMembers.contains(memberName)) return false;
    if (comm.joinedMembers.length >= comm.membersLimit) return false;

    comm.joinedMembers.add(memberName);

    addNotification(
      "Member Added",
      "Manager Ali added $memberName to committee '${comm.name}'.",
      "payment"
    );
    notifyListeners();
    return true;
  }

  // Remove member from committee by name
  bool removeMemberFromCommittee(String committeeId, String memberName) {
    if (_currentUser?.role != UserRole.manager) return false;

    final idx = _committees.indexWhere((c) => c.id == committeeId);
    if (idx == -1) return false;

    final comm = _committees[idx];
    if (!comm.joinedMembers.contains(memberName)) return false;

    comm.joinedMembers.remove(memberName);

    addNotification(
      "Member Removed",
      "Manager Ali removed $memberName from committee '${comm.name}'.",
      "payment"
    );
    notifyListeners();
    return true;
  }



  // Live Group Chat
  void postChatMessage(String text, String committeeId) {
    if (_currentUser == null || text.trim().isEmpty) return;
    
    final newMsg = ChatMessage(
      committeeId: committeeId,
      senderName: _currentUser!.name,
      senderRole: _currentUser!.role == UserRole.manager ? 'manager' : 'member',
      message: text.trim(),
      timestamp: DateTime.now(),
    );

    _chatHistory.add(newMsg);
    notifyListeners();
  }

  // Lucky draw
  String performLuckyDraw(String committeeId) {
    final idx = _committees.indexWhere((c) => c.id == committeeId);
    if (idx == -1) return "Committee not found";
    
    final committee = _committees[idx];
    
    // Find eligible members (joined members who have NOT won yet)
    final eligibleMembers = committee.joinedMembers
        .where((member) => !committee.drawWinners.contains(member))
        .toList();

    if (eligibleMembers.isEmpty) {
      return "All members have already won in past draws!";
    }

    // Pick a random eligible winner
    eligibleMembers.shuffle();
    final winner = eligibleMembers.first;

    committee.drawWinners.add(winner);
    committee.installmentsPaid = (committee.installmentsPaid + 1).clamp(0, committee.totalInstallments);

    _lastDrawDates[committeeId] = DateTime.now();
    _saveSession();

    addNotification(
      "Lucky Draw Winner!",
      "Congratulations to $winner for winning the latest draw in '${committee.name}'!",
      "draw"
    );

    notifyListeners();
    return winner;
  }

  // Pick a winner without saving yet
  String pickLuckyDrawWinner(String committeeId) {
    final idx = _committees.indexWhere((c) => c.id == committeeId);
    if (idx == -1) return "Committee not found";
    
    final committee = _committees[idx];
    
    // Find eligible members (joined members who have NOT won yet)
    final eligibleMembers = committee.joinedMembers
        .where((member) => !committee.drawWinners.contains(member))
        .toList();

    if (eligibleMembers.isEmpty) {
      return "All members have already won in past draws!";
    }

    // Pick a random eligible winner
    eligibleMembers.shuffle();
    final winner = eligibleMembers.first;
    return winner;
  }

  // Finalize lucky draw — records timing so next draw is blocked until next cycle
  void finalizeLuckyDraw(String committeeId, String winner) {
    final idx = _committees.indexWhere((c) => c.id == committeeId);
    if (idx == -1) return;

    final committee = _committees[idx];
    if (!committee.drawWinners.contains(winner)) {
      committee.drawWinners.add(winner);
      committee.installmentsPaid = (committee.installmentsPaid + 1).clamp(0, committee.totalInstallments);

      // Record draw timestamp → enforces cycle restriction
      _lastDrawDates[committeeId] = DateTime.now();
      _saveSession();

      addNotification(
        "Lucky Draw Winner!",
        "Congratulations to $winner for winning the latest draw in '${committee.name}'!",
        "draw"
      );
      notifyListeners();
    }
  }

  // Wallet Integration state
  Future<bool> connectWalletProvider(String provider, String phone, String pin) async {
    // Artificial network delay
    await Future.delayed(const Duration(milliseconds: 1500));

    // Connect fails for specific phone number for testing
    if (phone == "0300-0000000" || phone == "03000000000" || pin.length != 4) {
      return false;
    }

    if (_currentUser != null) {
      _currentUser!.linkedProvider = provider;
      _currentUser!.linkedAccountNo = phone;
      // Fetch user's available balance from selected provider (Mock balance: PKR 25,000)
      _currentUser!.balance = 25000.0;

      // Sync balances across all profiles sharing this email
      for (var u in _users) {
        if (u.email.toLowerCase() == _currentUser!.email.toLowerCase()) {
          u.linkedProvider = provider;
          u.linkedAccountNo = phone;
          u.balance = 25000.0;
        }
      }

      addNotification(
        "Wallet Linked Successfully",
        "Your account is now synced with $provider ($phone). Wallet balance is PKR 25,000.00.",
        "payment"
      );

      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> refreshWalletBalance() async {
    if (_currentUser == null || _currentUser!.linkedProvider == null) return false;

    await Future.delayed(const Duration(milliseconds: 1200));

    // Simulate minor change in balance to show live refresh
    final double updatedBalance = _currentUser!.balance == 25000.0 ? 27500.0 : 25000.0;
    _currentUser!.balance = updatedBalance;

    for (var u in _users) {
      if (u.email.toLowerCase() == _currentUser!.email.toLowerCase()) {
        u.balance = updatedBalance;
      }
    }

    addNotification(
      "Balance Refreshed",
      "Successfully synced with ${_currentUser!.linkedProvider}. Updated Balance: PKR ${updatedBalance.toStringAsFixed(2)}.",
      "payment"
    );

    notifyListeners();
    return true;
  }

  Future<void> disconnectWallet() async {
    if (_currentUser != null) {
      _currentUser!.linkedProvider = null;
      _currentUser!.linkedAccountNo = null;
      _currentUser!.balance = 0.0; // Reset balance to 0.0 upon unlinking provider

      for (var u in _users) {
        if (u.email.toLowerCase() == _currentUser!.email.toLowerCase()) {
          u.linkedProvider = null;
          u.linkedAccountNo = null;
          u.balance = 0.0; // Reset balance for all profiles sharing this email
        }
      }

      addNotification(
        "Wallet Disconnected",
        "Your mobile wallet provider has been unlinked from this profile. Balance reset to 0.0 PKR.",
        "payment"
      );

      notifyListeners();
    }
  }

  // Simulated Subscription Expiry testing
  bool _isSubscriptionExpired = false;
  bool get isSubscriptionExpired => _isSubscriptionExpired;

  void toggleSubscriptionExpiry() {
    _isSubscriptionExpired = !_isSubscriptionExpired;
    if (_isSubscriptionExpired && _currentUser != null) {
      _currentUser!.isSubscribed = false;
      _currentUser!.subscriptionPlan = 'none';
      for (var u in _users) {
        if (u.email.toLowerCase() == _currentUser!.email.toLowerCase()) {
          u.isSubscribed = false;
          u.subscriptionPlan = 'none';
        }
      }
      addNotification(
        "Subscription Expired",
        "Your rotating committee subscription plan has expired. Please renew access.",
        "payment"
      );
    } else if (!_isSubscriptionExpired && _currentUser != null) {
      // Re-enable subscription
      _currentUser!.isSubscribed = true;
      _currentUser!.subscriptionPlan = 'monthly';
      for (var u in _users) {
        if (u.email.toLowerCase() == _currentUser!.email.toLowerCase()) {
          u.isSubscribed = true;
          u.subscriptionPlan = 'monthly';
        }
      }
    }
    notifyListeners();
  }

  // Adding dynamic notification
  void addNotification(String title, String body, String type) {
    final newNotif = AppNotification(
      id: "n${_notifications.length + 1}",
      title: title,
      body: body,
      timestamp: DateTime.now(),
      type: type,
    );
    _notifications.insert(0, newNotif);
    notifyListeners();
  }
}
