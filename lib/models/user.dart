enum UserRole { member, manager }

class UserModel {
  final String name;
  final String email;
  final String password;
  final String cnic;
  final String phone;
  final UserRole role;
  bool isSubscribed;
  String subscriptionPlan; // 'none', 'weekly', 'monthly', 'yearly'
  double balance;
  String? linkedProvider; // 'jazzcash', 'easypaisa' or null
  String? linkedAccountNo; // phone or account number

  UserModel({
    required this.name,
    required this.email,
    required this.password,
    required this.cnic,
    required this.phone,
    required this.role,
    this.isSubscribed = false,
    this.subscriptionPlan = 'none',
    required this.balance,
    this.linkedProvider,
    this.linkedAccountNo,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'password': password,
      'cnic': cnic,
      'phone': phone,
      'role': role.toString(),
      'isSubscribed': isSubscribed,
      'subscriptionPlan': subscriptionPlan,
      'balance': balance,
      'linkedProvider': linkedProvider,
      'linkedAccountNo': linkedAccountNo,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      name: json['name'],
      email: json['email'],
      password: json['password'],
      cnic: json['cnic'],
      phone: json['phone'],
      role: json['role'] == 'UserRole.manager' ? UserRole.manager : UserRole.member,
      isSubscribed: json['isSubscribed'] ?? false,
      subscriptionPlan: json['subscriptionPlan'] ?? 'none',
      balance: (json['balance'] ?? 0).toDouble(),
      linkedProvider: json['linkedProvider'],
      linkedAccountNo: json['linkedAccountNo'],
    );
  }
}
