class Profile {
  final String id;
  final String username;
  final String name;
  final String role; // 'admin' | 'staff'
  final String? branchId;
  final String? branchName;
  final DateTime createdAt;

  Profile({
    required this.id,
    required this.username,
    required this.name,
    required this.role,
    this.branchId,
    this.branchName,
    required this.createdAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    String? bName;
    if (json['branches'] != null && json['branches'] is Map) {
      bName = json['branches']['name'] as String?;
    }
    return Profile(
      id: json['id'] as String,
      username: json['username'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
      branchId: json['branch_id'] as String?,
      branchName: bName ?? json['branch_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'name': name,
      'role': role,
      'branch_id': branchId,
      'branch_name': branchName,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isAdmin => role == 'admin';
  bool get isStaff => role == 'staff';
}
