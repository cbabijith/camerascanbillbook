class Branch {
  final String id;
  final String name;
  final String? address;
  final String? phone;
  final String? gstin;
  final DateTime createdAt;

  Branch({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    this.gstin,
    required this.createdAt,
  });

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      gstin: json['gstin'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'phone': phone,
      'gstin': gstin,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
