import '../../../core/supabase/api_client.dart';
import '../models/branch.dart';

class BranchRepository {
  final _client = supabase;

  Future<List<Branch>> getBranches() async {
    final response = await _client.from('branches').select().order('name');
    return (response as List).map((json) => Branch.fromJson(json)).toList();
  }

  Future<Branch> createBranch({
    required String name,
    String? address,
    String? phone,
    String? gstin,
  }) async {
    final response = await _client.from('branches').insert({
      'name': name,
      'address': address,
      'phone': phone,
      'gstin': gstin,
    }).select().single();
    return Branch.fromJson(response);
  }

  Future<Branch> updateBranch(
    String id, {
    required String name,
    String? address,
    String? phone,
    String? gstin,
  }) async {
    final response = await _client.from('branches').update({
      'name': name,
      'address': address,
      'phone': phone,
      'gstin': gstin,
    }).eq('id', id).select().single();
    return Branch.fromJson(response);
  }

  Future<void> deleteBranch(String id) async {
    await _client.from('branches').delete().eq('id', id);
  }
}
