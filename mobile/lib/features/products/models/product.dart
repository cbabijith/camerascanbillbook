class Product {
  final String id;
  final String branchId;
  final String name;
  final String? brand;
  final String? category;
  final String sku; // Serial Number / Barcode
  final double sellingPrice;
  final double? mrp;
  final double gstRate;
  final int stock;
  final DateTime createdAt;
  final String? createdBy;
  final DateTime updatedAt;
  final String? updatedBy;

  Product({
    required this.id,
    required this.branchId,
    required this.name,
    this.brand,
    this.category,
    required this.sku,
    required this.sellingPrice,
    this.mrp,
    required this.gstRate,
    required this.stock,
    required this.createdAt,
    this.createdBy,
    required this.updatedAt,
    this.updatedBy,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      branchId: json['branch_id'] as String,
      name: json['name'] as String,
      brand: json['brand'] as String?,
      category: json['category'] as String?,
      sku: json['sku'] as String,
      sellingPrice: (json['selling_price'] as num).toDouble(),
      mrp: json['mrp'] != null ? (json['mrp'] as num).toDouble() : null,
      gstRate: (json['gst_rate'] as num? ?? 0).toDouble(),
      stock: (json['stock'] as num? ?? 0).toInt(),
      createdAt: DateTime.parse(json['created_at'] as String),
      createdBy: json['created_by'] as String?,
      updatedAt: DateTime.parse(json['updated_at'] as String),
      updatedBy: json['updated_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'branch_id': branchId,
      'name': name,
      'brand': brand,
      'category': category,
      'sku': sku,
      'selling_price': sellingPrice,
      'mrp': mrp,
      'gst_rate': gstRate,
      'stock': stock,
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
      'updated_at': updatedAt.toIso8601String(),
      'updated_by': updatedBy,
    };
  }
}
