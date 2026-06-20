import '../../../core/supabase/api_client.dart';
import '../models/analytics_metrics.dart';

class AnalyticsRepository {
  final _client = supabase;

  Future<List<BranchAnalytics>> getAnalyticsData(String startDate, String endDate) async {
    try {
      final branchesResponse = await _client
          .from('branches')
          .select('id, name')
          .order('name');

      final branches = branchesResponse as List;
      final List<BranchAnalytics> results = [];

      for (final branch in branches) {
        final String branchId = branch['id'] as String;
        final String branchName = branch['name'] as String;

        // Fetch bills for this branch in the date range
        final billsResponse = await _client
            .from('bills')
            .select('id, bill_number, customer_name, total, advance_amount, payment_status, user_id, created_at')
            .eq('branch_id', branchId)
            .gte('created_at', startDate)
            .lt('created_at', endDate);

        final bills = billsResponse as List;

        // Fetch all bills for overdue calculation (since overdue is calculated from all time, not just this range)
        final allBranchBillsResponse = await _client
            .from('bills')
            .select('id, bill_number, customer_name, total, advance_amount, payment_status, created_at')
            .eq('branch_id', branchId);

        final allBranchBills = allBranchBillsResponse as List;

        final List<String> billIds = bills.map((b) => b['id'] as String).toList();

        // Fetch collections for these bills
        List collections = [];
        if (billIds.isNotEmpty) {
          final collectionsResponse = await _client
              .from('payment_collections')
              .select('id, bill_id, amount, payment_method, payment_type, collected_at')
              .inFilter('bill_id', billIds);
          collections = collectionsResponse as List;
        }

        final int totalInvoices = bills.length;
        final double totalSales = bills.fold(0.0, (sum, b) => sum + (b['total'] as num).toDouble());
        final double totalReceived = collections.fold(0.0, (sum, pc) => sum + (pc['amount'] as num).toDouble());
        final double avgBillValue = totalInvoices > 0 ? totalSales / totalInvoices : 0.0;

        // Payment Methods Breakdown
        final Map<String, Map<String, dynamic>> methodMap = {};
        for (final pc in collections) {
          final String method = pc['payment_method'] as String? ?? 'cash';
          final double amt = (pc['amount'] as num).toDouble();
          if (methodMap.containsKey(method)) {
            methodMap[method]!['count'] = (methodMap[method]!['count'] as int) + 1;
            methodMap[method]!['amount'] = (methodMap[method]!['amount'] as double) + amt;
          } else {
            methodMap[method] = {'method': method, 'count': 1, 'amount': amt};
          }
        }
        final paymentMethodBreakdown = methodMap.values
            .map((e) => PaymentMethodStat.fromJson(e))
            .toList()
          ..sort((a, b) => b.amount.compareTo(a.amount));

        // Overdue calculation
        final overdueDues = allBranchBills
            .where((b) => b['payment_status'] != 'paid')
            .map((b) {
              final double totalAmt = (b['total'] as num).toDouble();
              final double advAmt = (b['advance_amount'] as num? ?? 0.0).toDouble();
              final double due = totalAmt - advAmt;
              final age = DateTime.now()
                  .difference(DateTime.parse(b['created_at'] as String))
                  .inDays;
              return {
                'billNumber': b['bill_number'],
                'customerName': b['customer_name'],
                'amount': due,
                'age': age,
                'branchName': branchName,
              };
            })
            .where((d) => (d['amount'] as double) > 0.0)
            .map((e) => OverdueDue.fromJson(e))
            .toList()
          ..sort((a, b) => b.age.compareTo(a.age));

        final double totalDue = overdueDues.fold(0.0, (sum, d) => sum + d.amount);

        // Staff Leaderboard calculation
        final Set<String> userIds = bills.map((b) => b['user_id'] as String).toSet();
        Map<String, String> profileMap = {};
        if (userIds.isNotEmpty) {
          final profilesResponse = await _client
              .from('profiles')
              .select('id, name')
              .inFilter('id', userIds.toList());
          for (final p in profilesResponse as List) {
            profileMap[p['id'] as String] = p['name'] as String;
          }
        }

        final Map<String, Map<String, dynamic>> staffMap = {};
        for (final bill in bills) {
          final String userId = bill['user_id'] as String;
          final String staffName = profileMap[userId] ?? 'Unknown';
          final double totalAmt = (bill['total'] as num).toDouble();

          if (staffMap.containsKey(userId)) {
            staffMap[userId]!['billCount'] = (staffMap[userId]!['billCount'] as int) + 1;
            staffMap[userId]!['totalSales'] = (staffMap[userId]!['totalSales'] as double) + totalAmt;
          } else {
            staffMap[userId] = {
              'name': staffName,
              'billCount': 1,
              'totalSales': totalAmt,
              'collectedAmount': 0.0,
              'branchName': branchName,
            };
          }
        }

        final Map<String, List<String>> staffBillIds = {};
        for (final bill in bills) {
          final String userId = bill['user_id'] as String;
          staffBillIds.putIfAbsent(userId, () => []).add(bill['id'] as String);
        }

        for (final pc in collections) {
          final String billId = pc['bill_id'] as String;
          final double amt = (pc['amount'] as num).toDouble();
          for (final entry in staffBillIds.entries) {
            if (entry.value.contains(billId)) {
              if (staffMap.containsKey(entry.key)) {
                staffMap[entry.key]!['collectedAmount'] =
                    (staffMap[entry.key]!['collectedAmount'] as double) + amt;
              }
            }
          }
        }

        final staffRanking = staffMap.values
            .map((e) => StaffRanking.fromJson(e))
            .toList()
          ..sort((a, b) => b.billCount.compareTo(a.billCount) != 0
              ? b.billCount.compareTo(a.billCount)
              : b.totalSales.compareTo(a.totalSales));

        results.add(BranchAnalytics(
          branchId: branchId,
          branchName: branchName,
          totalInvoices: totalInvoices,
          totalSales: totalSales,
          totalReceived: totalReceived,
          totalDue: totalDue,
          avgBillValue: avgBillValue,
          paymentMethodBreakdown: paymentMethodBreakdown,
          overdueDues: overdueDues,
          staffRanking: staffRanking,
        ));
      }

      return results;
    } catch (e) {
      return [];
    }
  }
}
