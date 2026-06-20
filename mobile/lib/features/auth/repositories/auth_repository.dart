import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';
import '../../branches/models/branch.dart';
import '../../../core/supabase/api_client.dart';

class AuthRepository {
  final SupabaseClient _client = supabase;

  Future<bool> checkIfSetupRequired() async {
    try {
      final response = await _client
          .from('profiles')
          .select('*')
          .limit(1);
      return (response as List).isEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<void> setupAdmin({
    required String email,
    required String password,
    required String name,
    required String username,
    required String branchName,
    String? branchAddress,
    String? branchPhone,
    String? branchGstin,
  }) async {
    // 1. Create the first branch
    final branchResponse = await _client.from('branches').insert({
      'name': branchName,
      'address': branchAddress,
      'phone': branchPhone,
      'gstin': branchGstin,
    }).select().single();

    final branch = Branch.fromJson(branchResponse);

    try {
      // 2. Sign up user (trigger handle_new_user will handle profile insertion)
      await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'role': 'admin',
          'username': username,
          'name': name,
          'branch_id': branch.id,
        },
      );
    } catch (e) {
      // Clean up branch if signup fails
      await _client.from('branches').delete().eq('id', branch.id);
      rethrow;
    }
  }

  Future<AuthResponse> signIn({required String email, required String password}) async {
    return await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<Profile?> getCurrentUserProfile(String userId) async {
    try {
      final response = await _client.from('profiles').select().eq('id', userId).single();
      return Profile.fromJson(response);
    } catch (e) {
      return null;
    }
  }
}
