import 'dart:math';
import '../../../core/supabase/api_client.dart';
import '../models/bill.dart';
import '../models/payment_collection.dart';

class BillRepository {
  final _client = supabase;

  Future<List<Bill>> getBills(String branchId) async {
    final response = await _client
        .from('bills')
        .select('*, profiles:user_id(name), payment_collections(*, profiles:collected_by(name))')
        .eq('branch_id', branchId)
        .order('created_at', ascending: false);
    return (response as List).map((json) => Bill.fromJson(json)).toList();
  }

  Future<Map<String, dynamic>> createBill({
    required String branchId,
    required String userId,
    required String? customerId,
    required String customerName,
    required String customerPhone,
    String? customerEmail,
    String? customerAddress,
    required List<Map<String, dynamic>> items,
    required String paymentStatus,
    double? advanceAmount,
    double? discount,
    String? paymentMethod,
  }) async {
    // 1. Resolve Customer (Create inline if 'new' or not exists)
    String? resolvedCustomerId = customerId;
    if (resolvedCustomerId == null || resolvedCustomerId == 'new') {
      final existingResponse = await _client
          .from('customers')
          .select('id')
          .eq('branch_id', branchId)
          .eq('phone', customerPhone)
          .maybeSingle();

      if (existingResponse != null) {
        resolvedCustomerId = existingResponse['id'] as String;
      } else {
        final newCustomerResponse = await _client.from('customers').insert({
          'branch_id': branchId,
          'name': customerName,
          'phone': customerPhone,
          'email': customerEmail,
          'address': customerAddress,
          'created_by': userId,
          'updated_by': userId,
        }).select().single();
        resolvedCustomerId = newCustomerResponse['id'] as String;
      }
    }

    // 2. Resolve Products (Create inline if 'new')
    final List<Map<String, dynamic>> processedItems = [];
    double subTotal = 0.0;

    for (final item in items) {
      String resolvedProductId = item['productId'] as String;
      if (resolvedProductId == 'new') {
        final existingProductResponse = await _client
            .from('products')
            .select('id')
            .eq('branch_id', branchId)
            .eq('sku', item['sku'])
            .maybeSingle();

        if (existingProductResponse != null) {
          resolvedProductId = existingProductResponse['id'] as String;
        } else {
          final newProductResponse = await _client.from('products').insert({
            'branch_id': branchId,
            'name': item['name'],
            'brand': item['brand'],
            'category': item['category'],
            'sku': item['sku'],
            'selling_price': item['sellingPrice'],
            'mrp': item['mrp'],
            'gst_rate': 0,
            'created_by': userId,
            'updated_by': userId,
          }).select().single();
          resolvedProductId = newProductResponse['id'] as String;
        }
      }

      final double sellingPrice = (item['sellingPrice'] as num).toDouble();
      final int qty = (item['qty'] as num).toInt();
      final double itemTotal = sellingPrice * qty;
      subTotal += itemTotal;

      processedItems.add({
        'productId': resolvedProductId,
        'name': item['name'],
        'brand': item['brand'],
        'category': item['category'],
        'sku': item['sku'],
        'sellingPrice': sellingPrice,
        'mrp': item['mrp'],
        'qty': qty,
        'basePrice': double.parse(itemTotal.toStringAsFixed(2)),
        'gstAmount': 0.0,
        'total': double.parse(itemTotal.toStringAsFixed(2)),
      });
    }

    double finalTotal = subTotal - (discount ?? 0.0);
    finalTotal = max(0.0, double.parse(finalTotal.toStringAsFixed(2)));

    // 3. Generate Sequential Bill Number with Retries
    const maxRetries = 3;
    Map<String, dynamic>? billData;
    dynamic insertError;

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      final countResponse = await _client
          .from('bills')
          .select('id')
          .eq('branch_id', branchId);

      final int count = (countResponse as List).length;
      final int nextIndex = count + 1 + attempt;
      final String paddedNumber = nextIndex.toString().padLeft(4, '0');
      final String billNumber = 'INV-$paddedNumber';

      try {
        final result = await _client.from('bills').insert({
          'bill_number': billNumber,
          'branch_id': branchId,
          'user_id': userId,
          'customer_id': resolvedCustomerId,
          'customer_name': customerName,
          'customer_phone': customerPhone,
          'items': processedItems,
          'sub_total': double.parse(subTotal.toStringAsFixed(2)),
          'gst_amount': 0.0,
          'total': finalTotal,
          'payment_status': paymentStatus,
          'advance_amount': advanceAmount ?? 0.0,
          'discount': discount ?? 0.0,
          'created_by': userId,
          'updated_by': userId,
        }).select().single();

        billData = result;
        insertError = null;
        break;
      } catch (e) {
        insertError = e;
      }
    }

    if (insertError != null && billData == null) {
      throw insertError;
    }

    final bill = Bill.fromJson(billData!);

    // 4. Record payment collection
    if (paymentStatus == 'advance' && (advanceAmount ?? 0.0) > 0) {
      await _client.from('payment_collections').insert({
        'bill_id': bill.id,
        'amount': advanceAmount,
        'payment_type': 'advance',
        'payment_method': paymentMethod ?? 'cash',
        'collected_by': userId,
      });
    } else if (paymentStatus == 'paid') {
      await _client.from('payment_collections').insert({
        'bill_id': bill.id,
        'amount': finalTotal,
        'payment_type': 'final',
        'payment_method': paymentMethod ?? 'cash',
        'collected_by': userId,
      });
    }

    return billData;
  }

  Future<void> collectPayment({
    required String billId,
    required String branchId,
    required String userId,
    required double amount,
    required String paymentMethod,
  }) async {
    final billResponse = await _client
        .from('bills')
        .select('id, total, advance_amount, payment_status')
        .eq('id', billId)
        .eq('branch_id', branchId)
        .single();

    final double total = (billResponse['total'] as num).toDouble();
    final double currentAdvance = (billResponse['advance_amount'] as num? ?? 0.0).toDouble();
    final double newTotalPaid = currentAdvance + amount;
    final double remaining = total - newTotalPaid;

    String newStatus;
    double newAdvanceAmount;

    if (remaining <= 0) {
      newStatus = 'paid';
      newAdvanceAmount = total;
    } else if (newTotalPaid > 0) {
      newStatus = 'partial';
      newAdvanceAmount = newTotalPaid;
    } else {
      newStatus = 'unpaid';
      newAdvanceAmount = 0.0;
    }

    await _client.from('bills').update({
      'payment_status': newStatus,
      'advance_amount': newAdvanceAmount,
      'updated_by': userId,
    }).eq('id', billId);

    await _client.from('payment_collections').insert({
      'bill_id': billId,
      'amount': amount,
      'payment_type': remaining <= 0 ? 'final' : 'partial',
      'payment_method': paymentMethod,
      'collected_by': userId,
    });
  }

  Future<void> updateBill({
    required String billId,
    required String branchId,
    required String userId,
    required String customerName,
    required String customerPhone,
    String? customerEmail,
    String? customerAddress,
    required List<Map<String, dynamic>> items,
    required String paymentStatus,
    double? advanceAmount,
    double? discount,
  }) async {
    final List<Map<String, dynamic>> processedItems = [];
    double subTotal = 0.0;

    for (final item in items) {
      String resolvedProductId = item['productId'] as String;
      if (resolvedProductId == 'new') {
        final newProductResponse = await _client.from('products').insert({
          'branch_id': branchId,
          'name': item['name'],
          'brand': item['brand'],
          'category': item['category'],
          'sku': item['sku'],
          'selling_price': item['sellingPrice'],
          'mrp': item['mrp'],
          'gst_rate': 0,
          'created_by': userId,
          'updated_by': userId,
        }).select().single();
        resolvedProductId = newProductResponse['id'] as String;
      }

      final double sellingPrice = (item['sellingPrice'] as num).toDouble();
      final int qty = (item['qty'] as num).toInt();
      final double itemTotal = sellingPrice * qty;
      subTotal += itemTotal;

      processedItems.add({
        'productId': resolvedProductId,
        'name': item['name'],
        'brand': item['brand'],
        'category': item['category'],
        'sku': item['sku'],
        'sellingPrice': sellingPrice,
        'mrp': item['mrp'],
        'qty': qty,
        'basePrice': double.parse(itemTotal.toStringAsFixed(2)),
        'gstAmount': 0.0,
        'total': double.parse(itemTotal.toStringAsFixed(2)),
      });
    }

    double finalTotal = subTotal - (discount ?? 0.0);
    finalTotal = max(0.0, double.parse(finalTotal.toStringAsFixed(2)));

    await _client.from('bills').update({
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'items': processedItems,
      'sub_total': double.parse(subTotal.toStringAsFixed(2)),
      'gst_amount': 0.0,
      'total': finalTotal,
      'payment_status': paymentStatus,
      'advance_amount': advanceAmount ?? 0.0,
      'discount': discount ?? 0.0,
      'updated_by': userId,
    }).eq('id', billId).eq('branch_id', branchId);
  }

  Future<void> deleteBill(String id, String branchId) async {
    await _client.from('bills').delete().eq('id', id).eq('branch_id', branchId);
  }

  Future<List<PaymentCollection>> getPaymentCollections(String billId) async {
    final response = await _client
        .from('payment_collections')
        .select('*, profiles(name)')
        .eq('bill_id', billId)
        .order('collected_at', ascending: false);
    return (response as List).map((json) => PaymentCollection.fromJson(json)).toList();
  }
}
