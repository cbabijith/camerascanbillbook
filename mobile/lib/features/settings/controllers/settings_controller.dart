import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/settings_repository.dart';
import '../../auth/models/profile.dart';

class SettingsState {
  final List<Profile> staff;
  final bool isLoading;
  final String? errorMessage;

  SettingsState({
    this.staff = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  SettingsState copyWith({
    List<Profile>? staff,
    bool? isLoading,
    String? errorMessage,
  }) {
    return SettingsState(
      staff: staff ?? this.staff,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class SettingsController extends Notifier<SettingsState> {
  SettingsRepository get _repository => ref.read(settingsRepositoryProvider);

  @override
  SettingsState build() {
    return SettingsState();
  }

  Future<void> fetchStaff() async {
    state = state.copyWith(isLoading: true);
    try {
      final list = await _repository.getStaffProfiles();
      state = state.copyWith(staff: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
    }
  }

  Future<bool> createStaff({
    required String email,
    required String password,
    required String name,
    required String username,
    required String branchId,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final newStaff = await _repository.createStaffAccount(
        email: email,
        password: password,
        name: name,
        username: username,
        branchId: branchId,
      );
      state = state.copyWith(
        staff: [...state.staff, newStaff]..sort((a, b) => a.name.compareTo(b.name)),
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
      return false;
    }
  }

  Future<bool> deleteStaff(String id) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.deleteStaffAccount(id);
      state = state.copyWith(
        staff: state.staff.where((s) => s.id != id).toList(),
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
      return false;
    }
  }
}

// Providers
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) => SettingsRepository());

final settingsControllerProvider = NotifierProvider<SettingsController, SettingsState>(SettingsController.new);
