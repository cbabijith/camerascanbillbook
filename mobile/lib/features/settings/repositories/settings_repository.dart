import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/config.dart';
import '../../auth/models/profile.dart';

class SettingsRepository {
  final SupabaseClient _client = Supabase.instance.client;

  // Instantiate an admin client for service role key actions
  SupabaseClient get _adminClient => SupabaseClient(
        SupabaseConfig.url,
        SupabaseConfig.serviceRoleKey,
      );

  Future<List<Profile>> getStaffProfiles() async {
    final response = await _client
        .from('profiles')
        .select('*, branches(name)')
        .eq('role', 'staff')
        .order('name');
    
    return (response as List).map((json) => Profile.fromJson(json)).toList();
  }

  Future<Profile> createStaffAccount({
    required String email,
    required String password,
    required String name,
    required String username,
    required String branchId,
  }) async {
    // Create the user account in auth using admin client
    final userResponse = await _adminClient.auth.admin.createUser(
      AdminUserAttributes(
        email: email,
        password: password,
        emailConfirm: true,
        userMetadata: {
          'role': 'staff',
          'username': username,
          'name': name,
          'branch_id': branchId,
        },
      ),
    );

    if (userResponse.user == null) {
      throw Exception('Failed to create user account');
    }

    // Query the profile with branch name
    final profileResponse = await _client
        .from('profiles')
        .select('*, branches(name)')
        .eq('id', userResponse.user!.id)
        .single();

    return Profile.fromJson(profileResponse);
  }

  Future<void> deleteStaffAccount(String id) async {
    // Delete from auth via admin client (cascades to profiles)
    await _adminClient.auth.admin.deleteUser(id);
  }
}
