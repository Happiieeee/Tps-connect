class UserModel {
  final String userId;
  final String name;
  final String email;
  final String? phone;
  final String role;
  final String? branchId;
  final bool isActive;

  UserModel({
    required this.userId,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
    this.branchId,
    required this.isActive,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        userId: json['user_id'] ?? '',
        name: json['name'] ?? '',
        email: json['email'] ?? '',
        phone: json['phone'],
        role: json['role'] ?? '',
        branchId: json['branch_id'],
        isActive: json['is_active'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role,
        'branch_id': branchId,
        'is_active': isActive,
      };
}
