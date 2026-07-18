import 'dart:convert';
import 'dart:ui' show Color;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../models/committee.dart';
import '../models/loan.dart';
import '../models/receipt.dart';
import '../models/notification.dart';

/// AI Service — connects Flutter to the FastAPI AI backend.
/// Falls back to smart mock responses when the backend is unreachable.
class AiService {
  // Change this to your deployed backend URL when using Docker/HF Spaces
  static String get _backendUrl {
    const String envUrl = String.fromEnvironment('AI_BACKEND_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }
    if (kIsWeb) {
      return 'http://localhost:8000';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    } else {
      return 'http://localhost:8000';
    }
  }

  static const Duration _timeout = Duration(seconds: 30);

  // ── Build the app context payload ─────────────────────────────

  static Map<String, dynamic> _buildContext({
    required UserModel user,
    required List<CommitteeModel> committees,
    required List<LoanModel> loans,
    required List<ReceiptModel> receipts,
    required List<AppNotification> notifications,
    required String language,
    double emergencyPoolBalance = 0.0,
  }) {
    return {
      'current_user': {
        'name': user.name,
        'email': user.email,
        'role': user.role == UserRole.manager ? 'manager' : 'member',
        'is_subscribed': user.isSubscribed,
        'balance': user.balance,
        'subscription_plan': user.subscriptionPlan,
      },
      'committees': committees.map((c) => {
        'id': c.id,
        'name': c.name,
        'description': c.description,
        'total_amount': c.totalAmount,
        'monthly_contribution': c.monthlyContribution,
        'members_limit': c.membersLimit,
        'joined_members': c.joinedMembers,
        'installments_paid': c.installmentsPaid,
        'total_installments': c.totalInstallments,
        'draw_winners': c.drawWinners,
        'status': c.status,
        'frequency': c.frequency,
      }).toList(),
      'loans': loans.map((l) => {
        'id': l.id,
        'applicant_name': l.applicantName,
        'applicant_email': l.applicantEmail,
        'amount': l.amount,
        'reason': l.reason,
        'monthly_repayment': l.monthlyRepayment,
        'duration_months': l.durationMonths,
        'status': l.status,
        'date_requested': l.dateRequested.toIso8601String(),
        'installments_paid': l.installmentsPaid,
        'total_repayable': l.totalRepayable,
      }).toList(),
      'receipts': receipts.take(15).map((r) => {
        'id': r.id,
        'user_email': r.userEmail,
        'user_name': r.userName,
        'type': r.type,
        'amount': r.amount,
        'reference_name': r.referenceName,
        'gateway': r.gateway,
        'timestamp': r.timestamp.toIso8601String(),
      }).toList(),
      'notifications': notifications.take(10).map((n) => {
        'id': n.id,
        'title': n.title,
        'body': n.body,
        'timestamp': n.timestamp.toIso8601String(),
        'type': n.type,
      }).toList(),
      'language': language,
      // Emergency Support Pool balance — sent from AppStateService
      'emergency_pool_balance': emergencyPoolBalance,
    };
  }

  // ── Smart mock fallback (no backend required) ─────────────────

  static String _mockChat(String message, String language, UserModel user) {
    final msg = message.toLowerCase();
    final isUrdu = language == 'ur';

    if (msg.contains('payment') || msg.contains('receipt') || msg.contains('ادائیگی') || msg.contains('رسید')) {
      return isUrdu
          ? '💳 آپ کی آخری ادائیگی کا ریکارڈ دیکھنے کے لیے ریسیپٹس سیکشن میں جائیں۔ آپ کا موجودہ بیلنس PKR ${user.balance.toStringAsFixed(0)} ہے۔'
          : '💳 Your last payment records are in the Receipts section. Your current balance is PKR ${user.balance.toStringAsFixed(0)}.';
    }
    if (msg.contains('loan') || msg.contains('قرض')) {
      return isUrdu
          ? '💰 قرض کی درخواست کے لیے آپ کا سبسکرائب ہونا ضروری ہے (PKR 10,000 – 20,000)۔ آپ کی موجودہ قرض درخواست لونز ٹیب میں دیکھیں۔'
          : '💰 Loans range from PKR 10,000–20,000 at zero interest. You must be subscribed to apply. Check the Loans tab for your current status.';
    }
    if (msg.contains('committee') || msg.contains('kameti') || msg.contains('کمیٹی') || msg.contains('بی سی')) {
      return isUrdu
          ? '🏦 آپ کی کمیٹیوں کی تفصیل ہوم ٹیب میں دیکھی جا سکتی ہے۔ ہر کمیٹی میں ماہانہ حصہ ادا کریں اور لکی ڈرا میں حصہ لیں!'
          : '🏦 Your committees are listed on the Home tab. Pay your monthly installment and participate in the lucky draw!';
    }
    if (msg.contains('balance') || msg.contains('بیلنس')) {
      return isUrdu
          ? '💵 آپ کا موجودہ والیٹ بیلنس PKR ${user.balance.toStringAsFixed(2)} ہے۔'
          : '💵 Your current wallet balance is PKR ${user.balance.toStringAsFixed(2)}.';
    }

    return isUrdu
        ? 'السلام علیکم ${user.name}! میں ہماری کمیٹی کا AI اسسٹنٹ ہوں۔ کمیٹی، قرض، ادائیگیاں، یا بیلنس کے بارے میں پوچھیں۔\n\n⚠️ مکمل AI جوابات کے لیے backend سرور شروع کریں۔'
        : 'Hello ${user.name}! I\'m the Our Committee AI assistant.\nAsk me about your committees, payments, loans, or balance!\n\n⚠️ Start the backend server for full AI responses:\n`cd backend && uvicorn main:app --reload`';
  }

  // ── /chat endpoint ────────────────────────────────────────────

  static Future<AiChatResult> chat({
    required String message,
    required List<Map<String, String>> history,
    required UserModel user,
    required List<CommitteeModel> committees,
    required List<LoanModel> loans,
    required List<ReceiptModel> receipts,
    required List<AppNotification> notifications,
    required String language,
    double emergencyPoolBalance = 0.0,
  }) async {
    final context = _buildContext(
      user: user,
      committees: committees,
      loans: loans,
      receipts: receipts,
      notifications: notifications,
      language: language,
      emergencyPoolBalance: emergencyPoolBalance,
    );

    try {
      final response = await http
          .post(
            Uri.parse('$_backendUrl/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'message': message,
              'history': history,
              'context': context,
              'agent_type': user.role == UserRole.manager ? 'manager' : 'member',
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return AiChatResult(
          reply: data['reply'] as String? ?? '',
          intent: data['intent'] as String?,
          actionsTaken: (data['actions_taken'] as List?)?.cast<String>() ?? [],
          sources: (data['sources'] as List?)?.cast<String>() ?? [],
          isFromBackend: true,
        );
      }
    } catch (_) {
      // Backend unreachable — use smart mock
    }

    return AiChatResult(
      reply: _mockChat(message, language, user),
      intent: 'mock',
      actionsTaken: [],
      sources: [],
      isFromBackend: false,
    );
  }

  // ── /notifications/generate endpoint ─────────────────────────

  static Future<Map<String, String>> generateNotification({
    required String eventType,
    required Map<String, dynamic> data,
    required String language,
    required String userName,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_backendUrl/notifications/generate'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'event_type': eventType,
              'data': data,
              'language': language,
              'user_name': userName,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'title': data['title'] as String? ?? '',
          'body': data['body'] as String? ?? '',
          'type': data['type'] as String? ?? 'payment',
        };
      }
    } catch (_) {}

    // Fallback
    return {
      'title': language == 'ur' ? 'ہماری کمیٹی اطلاع' : 'Our Committee Notification',
      'body': language == 'ur'
          ? 'آپ کی کمیٹی سے متعلق ایک اہم اطلاع ہے۔'
          : 'You have an important update from your committee.',
      'type': 'payment',
    };
  }

  // ── /loan/analyze endpoint ────────────────────────────────────

  static Future<LoanRiskResult> analyzeLoan({
    required LoanModel loan,
    required List<ReceiptModel> applicantHistory,
    required String language,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_backendUrl/loan/analyze'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'loan': {
                'id': loan.id,
                'applicant_name': loan.applicantName,
                'applicant_email': loan.applicantEmail,
                'amount': loan.amount,
                'reason': loan.reason,
                'monthly_repayment': loan.monthlyRepayment,
                'duration_months': loan.durationMonths,
                'status': loan.status,
                'date_requested': loan.dateRequested.toIso8601String(),
                'installments_paid': loan.installmentsPaid,
                'total_repayable': loan.totalRepayable,
              },
              'applicant_history': applicantHistory.map((r) => {
                'id': r.id,
                'user_email': r.userEmail,
                'user_name': r.userName,
                'type': r.type,
                'amount': r.amount,
                'reference_name': r.referenceName,
                'gateway': r.gateway,
                'timestamp': r.timestamp.toIso8601String(),
              }).toList(),
              'committee_membership': [],
              'language': language,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return LoanRiskResult(
          riskLevel: data['risk_level'] as String? ?? 'medium',
          recommendation: data['recommendation'] as String? ?? 'review',
          reasoning: data['reasoning'] as String? ?? '',
          confidenceScore: (data['confidence_score'] as num?)?.toDouble() ?? 0.5,
          isFromBackend: true,
        );
      }
    } catch (_) {}

    return LoanRiskResult(
      riskLevel: 'medium',
      recommendation: 'review',
      reasoning: language == 'ur'
          ? 'Backend سے رابطہ نہیں ہو سکا۔ دستی جائزہ لیں۔'
          : 'Could not reach AI backend. Manual review recommended.',
      confidenceScore: 0.5,
      isFromBackend: false,
    );
  }

  // ── Health check ─────────────────────────────────────────────

  static Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$_backendUrl/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

// ── Result models ─────────────────────────────────────────────────

class AiChatResult {
  final String reply;
  final String? intent;
  final List<String> actionsTaken;
  final List<String> sources;
  final bool isFromBackend;

  const AiChatResult({
    required this.reply,
    this.intent,
    required this.actionsTaken,
    required this.sources,
    required this.isFromBackend,
  });
}

class LoanRiskResult {
  final String riskLevel; // 'low' | 'medium' | 'high'
  final String recommendation; // 'approve' | 'reject' | 'review'
  final String reasoning;
  final double confidenceScore;
  final bool isFromBackend;

  const LoanRiskResult({
    required this.riskLevel,
    required this.recommendation,
    required this.reasoning,
    required this.confidenceScore,
    required this.isFromBackend,
  });

  Color get riskColor {
    switch (riskLevel) {
      case 'low':
        return const Color(0xFF10B981);
      case 'high':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFFD97706);
    }
  }
}
