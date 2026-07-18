class CommitteeModel {
  final String id;
  final String name;
  final String description;
  final double totalAmount;
  final double monthlyContribution; // Represents the contribution size per cycle slot
  final int membersLimit;
  final List<String> joinedMembers;
  int installmentsPaid;
  final int totalInstallments;
  final List<String> drawWinners; // Names of members who already won the draw
  final String status; // 'active', 'completed', 'pending'
  final String frequency; // 'daily', 'weekly', 'monthly'

  CommitteeModel({
    required this.id,
    required this.name,
    required this.description,
    required this.totalAmount,
    required this.monthlyContribution,
    required this.membersLimit,
    required this.joinedMembers,
    this.installmentsPaid = 0,
    required this.totalInstallments,
    required this.drawWinners,
    this.status = 'active',
    this.frequency = 'monthly',
  });

  double get amountPaid => installmentsPaid * monthlyContribution;
  double get amountRemaining => (totalInstallments - installmentsPaid) * monthlyContribution;
}
