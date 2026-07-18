class ReceiptModel {
  final String id;
  final String userEmail;
  final String userName;
  final String type; // 'Subscription', 'Committee Installment'
  final double amount;
  final String referenceId; // committeeId or plan name
  final String referenceName; // committee name or subscription plan details
  final String gateway;
  final String phoneOrAccount;
  final DateTime timestamp;

  ReceiptModel({
    required this.id,
    required this.userEmail,
    required this.userName,
    required this.type,
    required this.amount,
    required this.referenceId,
    required this.referenceName,
    required this.gateway,
    required this.phoneOrAccount,
    required this.timestamp,
  });
}
