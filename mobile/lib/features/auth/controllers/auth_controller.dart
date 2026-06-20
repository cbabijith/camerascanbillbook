import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../models/profile.dart';
import '../repositories/auth_repository.dart';

class AuthState {
  final Profile? profile;
  final bool isLoading;
  final String? errorMessage;
  final bool isSetupRequired;

  AuthState({
    this.profile,
    this.isLoading = false,
    this.errorMessage,
    this.isSetupRequired = false,
  });

  AuthState copyWith({
    Profile? Function()? profile,
    bool? isLoading,
    String? errorMessage,
    bool? isSetupRequired,
  }) {
    return AuthState(
      profile: profile != null ? profile() : this.profile,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isSetupRequired: isSetupRequired ?? this.isSetupRequired,
    );
  }
}

class AuthController extends Notifier<AuthState> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  AuthState build() {
    _init();
    return AuthState();
  }

  void _init() {
    sb.Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final user = data.session?.user;
      if (user != null) {
        state = state.copyWith(isLoading: true);
        final profile = await _repository.getCurrentUserProfile(user.id);
        state = state.copyWith(profile: () => profile, isLoading: false);
      } else {
        state = state.copyWith(profile: () => null, isLoading: false);
      }
    });
  }

  Future<void> checkSetup() async {
    state = state.copyWith(isLoading: true);
    final required = await _repository.checkIfSetupRequired();
    state = state.copyWith(isSetupRequired: required, isLoading: false);
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.signIn(email: email, password: password);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
      return false;
    }
  }

  Future<bool> setupFirstAdmin({
    required String email,
    required String password,
    required String name,
    required String username,
    required String branchName,
    String? branchAddress,
    String? branchPhone,
    String? branchGstin,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.setupAdmin(
        email: email,
        password: password,
        name: name,
        username: username,
        branchName: branchName,
        branchAddress: branchAddress,
        branchPhone: branchPhone,
        branchGstin: branchGstin,
      );
      state = state.copyWith(isSetupRequired: false, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
      return false;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    await _repository.signOut();
    state = AuthState();
  }
}

// Providers
final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);
