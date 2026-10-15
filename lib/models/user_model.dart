import 'dart:convert';

class UserModel {
  final String id;
  final String email;
  final String name;
  final String shopName;
  final String passwordHash;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.shopName,
    required this.passwordHash,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email.toLowerCase().trim(),
      'name': name.trim(),
      'shopName': shopName.trim(),
      'passwordHash': passwordHash,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String? ?? '',
      email: (map['email'] as String? ?? '').toLowerCase().trim(),
      name: map['name'] as String? ?? '',
      shopName: map['shopName'] as String? ?? 'MK Star',
      passwordHash: map['passwordHash'] as String? ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory UserModel.fromJson(String source) =>
      UserModel.fromMap(json.decode(source) as Map<String, dynamic>);
}

