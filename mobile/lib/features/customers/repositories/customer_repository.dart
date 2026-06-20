import '../../../core/supabase/api_client.dart';
import '../models/customer.dart';

class CustomerRepository {
  final _client = supabase;

  Future<List<Customer>> getCustomers(String branchId) async {
    final response = await _client
        .from('customers')
        .select()
        .eq('branch_id', branchId)
        .order('name');
    return (response as List).map((json) => Customer.fromJson(json)).toList();
  }

  Future<List<Customer>> searchCustomers(String branchId, String query) async {
    final response = await _client
        .from('customers')
        .select()
        .eq('branch_id', branchId)
        .or('name.ilike.%$query%,phone.ilike.%$query%')
        .limit(10);
    return (response as List).map((json) => Customer.fromJson(json)).toList();
  }

  Future<Customer> createCustomer({
    required String branchId,
    required String name,
    required String phone,
    String? email,
    String? address,
    String? userId,
  }) async {
    final response = await _client.from('customers').insert({
      'branch_id': branchId,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'created_by': userId,
      'updated_by': userId,
    }).select().single();
    return Customer.fromJson(response);
  }

  Future<Customer> updateCustomer(
    String id, {
    required String name,
    required String phone,
    String? email,
    String? address,
    String? userId,
  }) async {
    final response = await _client.from('customers').update({
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'updated_by': userId,
    }).eq('id', id).select().single();
    return Customer.fromJson(response);
  }

  Future<void> deleteCustomer(String id) async {
    await _client.from('customers').delete().eq('id', id);
  }
}
