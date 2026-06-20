import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/branch.dart';
import '../repositories/branch_repository.dart';
import '../../auth/controllers/auth_controller.dart';

class BranchState {
  final List<Branch> branches;
  final String? activeBranchId;
  final bool isLoading;
  final String? errorMessage;

  BranchState({
    this.branches = const [],
    this.activeBranchId,
    this.isLoading = false,
    this.errorMessage,
  });

  BranchState copyWith({
    List<Branch>? branches,
    String? activeBranchId,
    bool? isLoading,
    String? errorMessage,
  }) {
    return BranchState(
      branches: branches ?? this.branches,
      activeBranchId: activeBranchId ?? this.activeBranchId,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class BranchController extends Notifier<BranchState> {
  BranchRepository get _repository => ref.read(branchRepositoryProvider);

  @override
  BranchState build() {
    // Watch profile to extract active branch id dynamically
    final authState = ref.watch(authControllerProvider);
    final activeId = authState.profile?.branchId;

    return BranchState(activeBranchId: activeId);
  }

  Future<void> fetchBranches() async {
    state = state.copyWith(isLoading: true);
    try {
      final list = await _repository.getBranches();
      state = state.copyWith(branches: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
    }
  }

  void setActiveBranch(String branchId) {
    state = state.copyWith(activeBranchId: branchId);
  }

  Future<bool> createBranch({
    required String name,
    String? address,
    String? phone,
    String? gstin,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final newBranch = await _repository.createBranch(
        name: name,
        address: address,
        phone: phone,
        gstin: gstin,
      );
      state = state.copyWith(
        branches: [...state.branches, newBranch]..sort((a, b) => a.name.compareTo(b.name)),
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
      return false;
    }
  }

  Future<bool> updateBranch(
    String id, {
    required String name,
    String? address,
    String? phone,
    String? gstin,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final updated = await _repository.updateBranch(
        id,
        name: name,
        address: address,
        phone: phone,
        gstin: gstin,
      );
      state = state.copyWith(
        branches: state.branches.map((b) => b.id == id ? updated : b).toList(),
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
      return false;
    }
  }

  Future<bool> deleteBranch(String id) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.deleteBranch(id);
      state = state.copyWith(
        branches: state.branches.where((b) => b.id != id).toList(),
        activeBranchId: state.activeBranchId == id ? null : state.activeBranchId,
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
final branchRepositoryProvider = Provider<BranchRepository>((ref) => BranchRepository());

final branchControllerProvider = NotifierProvider<BranchController, BranchState>(BranchController.new);
