class Customer {
  final String id;
  final String branchId;
  final String name;
  final String phone;
  final String? email;
  final String? address;
  final DateTime createdAt;
  final String? createdBy;
  final DateTime updatedAt;
  final String? updatedBy;

  final String? creatorName;

  Customer({
    required this.id,
    required this.branchId,
    required this.name,
    required this.phone,
    this.email,
    this.address,
    required this.createdAt,
    this.createdBy,
    this.creatorName,
    required this.updatedAt,
    this.updatedBy,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    String? cName;
    if (json['creator'] != null && json['creator'] is Map) {
      cName = json['creator']['name'] as String?;
    }
    return Customer(
      id: json['id'] as String,
      branchId: json['branch_id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String?,
      address: json['address'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      createdBy: json['created_by'] as String?,
      creatorName: cName ?? json['creator_name'] as String?,
      updatedAt: DateTime.parse(json['updated_at'] as String),
      updatedBy: json['updated_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'branch_id': branchId,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
      'creator_name': creatorName,
      'updated_at': updatedAt.toIso8601String(),
      'updated_by': updatedBy,
    };
  }
}
