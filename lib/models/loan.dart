class LoanModel {
  final String id;
  final String applicantName;
  final String applicantEmail;
  final double amount; // Range: 10,000 to 20,000 PKR
  final String reason;
  final double monthlyRepayment; // 1,000 or 2,000 PKR
  final int durationMonths; // Calculated as amount / monthlyRepayment
  String status; // 'pending', 'approved', 'rejected', 'completed'
  final DateTime dateRequested;
  final double interestAmount;
  final double totalRepayable;
  int installmentsPaid;

  LoanModel({
    required this.id,
    required this.applicantName,
    required this.applicantEmail,
    required this.amount,
    required this.reason,
    required this.monthlyRepayment,
    required this.durationMonths,
    this.status = 'pending',
    required this.dateRequested,
    required this.interestAmount,
    required this.totalRepayable,
    this.installmentsPaid = 0,
  });
}
