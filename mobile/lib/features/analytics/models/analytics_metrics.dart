class PaymentMethodStat {
  final String method;
  final int count;
  final double amount;

  PaymentMethodStat({
    required this.method,
    required this.count,
    required this.amount,
  });

  factory PaymentMethodStat.fromJson(Map<String, dynamic> json) {
    return PaymentMethodStat(
      method: json['method'] as String? ?? 'cash',
      count: (json['count'] as num? ?? 0).toInt(),
      amount: (json['amount'] as num? ?? 0).toDouble(),
    );
  }
}

class StaffRanking {
  final String name;
  final int billCount;
  final double totalSales;
  final double collectedAmount;
  final String? branchName;

  StaffRanking({
    required this.name,
    required this.billCount,
    required this.totalSales,
    required this.collectedAmount,
    this.branchName,
  });

  factory StaffRanking.fromJson(Map<String, dynamic> json) {
    return StaffRanking(
      name: json['name'] as String? ?? 'Staff Member',
      billCount: (json['billCount'] as num? ?? json['bill_count'] as num? ?? 0).toInt(),
      totalSales: (json['totalSales'] as num? ?? json['total_sales'] as num? ?? 0).toDouble(),
      collectedAmount: (json['collectedAmount'] as num? ?? json['collected_amount'] as num? ?? 0).toDouble(),
      branchName: json['branchName'] as String? ?? json['branch_name'] as String?,
    );
  }
}

class OverdueDue {
  final String billNumber;
  final String customerName;
  final double amount;
  final int age;
  final String branchName;

  OverdueDue({
    required this.billNumber,
    required this.customerName,
    required this.amount,
    required this.age,
    required this.branchName,
  });

  factory OverdueDue.fromJson(Map<String, dynamic> json) {
    return OverdueDue(
      billNumber: json['billNumber'] as String? ?? json['bill_number'] as String? ?? '',
      customerName: json['customerName'] as String? ?? json['customer_name'] as String? ?? '',
      amount: (json['amount'] as num? ?? 0).toDouble(),
      age: (json['age'] as num? ?? 0).toInt(),
      branchName: json['branchName'] as String? ?? json['branch_name'] as String? ?? '',
    );
  }
}

class BranchAnalytics {
  final String branchId;
  final String branchName;
  final int totalInvoices;
  final double totalSales;
  final double totalReceived;
  final double totalDue;
  final double avgBillValue;
  final List<PaymentMethodStat> paymentMethodBreakdown;
  final List<StaffRanking> staffRanking;
  final List<OverdueDue> overdueDues;

  BranchAnalytics({
    required this.branchId,
    required this.branchName,
    required this.totalInvoices,
    required this.totalSales,
    required this.totalReceived,
    required this.totalDue,
    required this.avgBillValue,
    required this.paymentMethodBreakdown,
    required this.staffRanking,
    required this.overdueDues,
  });

  factory BranchAnalytics.fromJson(Map<String, dynamic> json) {
    final payments = (json['paymentMethodBreakdown'] as List<dynamic>? ?? [])
        .map((e) => PaymentMethodStat.fromJson(e as Map<String, dynamic>))
        .toList();

    final staff = (json['staffRanking'] as List<dynamic>? ?? [])
        .map((e) => StaffRanking.fromJson(e as Map<String, dynamic>))
        .toList();

    final dues = (json['overdueDues'] as List<dynamic>? ?? [])
        .map((e) => OverdueDue.fromJson(e as Map<String, dynamic>))
        .toList();

    return BranchAnalytics(
      branchId: json['branchId'] as String? ?? json['branch_id'] as String? ?? '',
      branchName: json['branchName'] as String? ?? json['branch_name'] as String? ?? '',
      totalInvoices: (json['totalInvoices'] as num? ?? json['total_invoices'] as num? ?? 0).toInt(),
      totalSales: (json['totalSales'] as num? ?? json['total_sales'] as num? ?? 0).toDouble(),
      totalReceived: (json['totalReceived'] as num? ?? json['total_received'] as num? ?? 0).toDouble(),
      totalDue: (json['totalDue'] as num? ?? json['total_due'] as num? ?? 0).toDouble(),
      avgBillValue: (json['avgBillValue'] as num? ?? json['avg_bill_value'] as num? ?? 0).toDouble(),
      paymentMethodBreakdown: payments,
      staffRanking: staff,
      overdueDues: dues,
    );
  }
}
