class BillItem {
  final String productId;
  final String name;
  final String? brand;
  final String? category;
  final String sku;
  final double sellingPrice;
  final double? mrp;
  final int qty;
  final double basePrice;
  final double gstAmount;
  final double total;

  BillItem({
    required this.productId,
    required this.name,
    this.brand,
    this.category,
    required this.sku,
    required this.sellingPrice,
    this.mrp,
    required this.qty,
    required this.basePrice,
    required this.gstAmount,
    required this.total,
  });

  factory BillItem.fromJson(Map<String, dynamic> json) {
    return BillItem(
      productId: json['productId'] as String? ?? json['product_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      brand: json['brand'] as String?,
      category: json['category'] as String?,
      sku: json['sku'] as String? ?? '',
      sellingPrice: (json['sellingPrice'] as num? ?? json['selling_price'] as num? ?? 0).toDouble(),
      mrp: json['mrp'] != null ? (json['mrp'] as num).toDouble() : null,
      qty: (json['qty'] as num? ?? 0).toInt(),
      basePrice: (json['basePrice'] as num? ?? json['base_price'] as num? ?? 0).toDouble(),
      gstAmount: (json['gstAmount'] as num? ?? json['gst_amount'] as num? ?? 0).toDouble(),
      total: (json['total'] as num? ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'name': name,
      'brand': brand,
      'category': category,
      'sku': sku,
      'sellingPrice': sellingPrice,
      'mrp': mrp,
      'qty': qty,
      'basePrice': basePrice,
      'gstAmount': gstAmount,
      'total': total,
    };
  }
}

class Bill {
  final String id;
  final String billNumber;
  final String branchId;
  final String userId;
  final String? customerId;
  final String customerName;
  final String customerPhone;
  final List<BillItem> items;
  final double subTotal;
  final double gstAmount;
  final double total;
  final String paymentStatus; // 'paid' | 'unpaid' | 'advance' | 'partial'
  final double advanceAmount;
  final double discount;
  final DateTime createdAt;
  final String? createdBy;
  final DateTime updatedAt;
  final String? updatedBy;

  Bill({
    required this.id,
    required this.billNumber,
    required this.branchId,
    required this.userId,
    this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.items,
    required this.subTotal,
    required this.gstAmount,
    required this.total,
    required this.paymentStatus,
    required this.advanceAmount,
    required this.discount,
    required this.createdAt,
    this.createdBy,
    required this.updatedAt,
    this.updatedBy,
  });

  factory Bill.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['items'] as List<dynamic>? ?? [])
        .map((item) => BillItem.fromJson(item as Map<String, dynamic>))
        .toList();

    return Bill(
      id: json['id'] as String,
      billNumber: json['bill_number'] as String,
      branchId: json['branch_id'] as String,
      userId: json['user_id'] as String,
      customerId: json['customer_id'] as String?,
      customerName: json['customer_name'] as String,
      customerPhone: json['customer_phone'] as String,
      items: itemsList,
      subTotal: (json['sub_total'] as num).toDouble(),
      gstAmount: (json['gst_amount'] as num? ?? 0).toDouble(),
      total: (json['total'] as num).toDouble(),
      paymentStatus: json['payment_status'] as String,
      advanceAmount: (json['advance_amount'] as num? ?? 0).toDouble(),
      discount: (json['discount'] as num? ?? 0).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      createdBy: json['created_by'] as String?,
      updatedAt: DateTime.parse(json['updated_at'] as String),
      updatedBy: json['updated_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bill_number': billNumber,
      'branch_id': branchId,
      'user_id': userId,
      'customer_id': customerId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'items': items.map((e) => e.toJson()).toList(),
      'sub_total': subTotal,
      'gst_amount': gstAmount,
      'total': total,
      'payment_status': paymentStatus,
      'advance_amount': advanceAmount,
      'discount': discount,
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
      'updated_at': updatedAt.toIso8601String(),
      'updated_by': updatedBy,
    };
  }

  double get dueAmount => total - advanceAmount;
}
