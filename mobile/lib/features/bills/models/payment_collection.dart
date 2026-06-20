class PaymentCollection {
  final String id;
  final String billId;
  final double amount;
  final String paymentType; // 'advance' | 'partial' | 'final'
  final String paymentMethod; // 'upi' | 'bank' | 'cash' | 'card'
  final String? collectedBy;
  final DateTime createdAt;

  PaymentCollection({
    required this.id,
    required this.billId,
    required this.amount,
    required this.paymentType,
    required this.paymentMethod,
    this.collectedBy,
    required this.createdAt,
  });

  factory PaymentCollection.fromJson(Map<String, dynamic> json) {
    return PaymentCollection(
      id: json['id'] as String,
      billId: json['bill_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      paymentType: json['payment_type'] as String,
      paymentMethod: json['payment_method'] as String,
      collectedBy: json['collected_by'] as String?,
      createdAt: DateTime.parse(json['collected_at'] ?? json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bill_id': billId,
      'amount': amount,
      'payment_type': paymentType,
      'payment_method': paymentMethod,
      'collected_by': collectedBy,
      'collected_at': createdAt.toIso8601String(),
    };
  }
}
