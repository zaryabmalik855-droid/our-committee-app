class EmergencyRequestModel {
  final String id;
  final String applicantName;
  final String applicantEmail;
  final double amount;
  final String reason;
  String status; // 'pending', 'approved', 'rejected'
  final DateTime dateRequested;

  EmergencyRequestModel({
    required this.id,
    required this.applicantName,
    required this.applicantEmail,
    required this.amount,
    required this.reason,
    this.status = 'pending',
    required this.dateRequested,
  });
}
