import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/customer.dart';
import '../repositories/customer_repository.dart';
import '../../branches/controllers/branch_controller.dart';
import '../../auth/controllers/auth_controller.dart';

class CustomerState {
  final List<Customer> customers;
  final List<Customer> searchResults;
  final bool isLoading;
  final String? errorMessage;

  CustomerState({
    this.customers = const [],
    this.searchResults = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  CustomerState copyWith({
    List<Customer>? customers,
    List<Customer>? searchResults,
    bool? isLoading,
    String? errorMessage,
  }) {
    return CustomerState(
      customers: customers ?? this.customers,
      searchResults: searchResults ?? this.searchResults,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class CustomerController extends Notifier<CustomerState> {
  CustomerRepository get _repository => ref.read(customerRepositoryProvider);

  @override
  CustomerState build() {
    // Watch active branch to reload customers automatically on switch
    final branchState = ref.watch(branchControllerProvider);
    if (branchState.activeBranchId != null) {
      Future.microtask(() => fetchCustomers());
    }

    return CustomerState();
  }

  String? get _activeBranchId => ref.read(branchControllerProvider).activeBranchId;
  String? get _currentUserId => ref.read(authControllerProvider).profile?.id;

  Future<void> fetchCustomers() async {
    final branchId = _activeBranchId;
    if (branchId == null) return;

    state = state.copyWith(isLoading: true);
    try {
      final list = await _repository.getCustomers(branchId);
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      state = state.copyWith(customers: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
    }
  }

  Future<List<Customer>> search(String query) async {
    final branchId = _activeBranchId;
    if (branchId == null || query.trim().isEmpty) {
      state = state.copyWith(searchResults: const []);
      return const [];
    }

    try {
      final results = await _repository.searchCustomers(branchId, query);
      state = state.copyWith(searchResults: results);
      return results;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return const [];
    }
  }

  Future<bool> addCustomer({
    required String name,
    required String phone,
    String? email,
    String? address,
  }) async {
    final branchId = _activeBranchId;
    if (branchId == null) {
      state = state.copyWith(errorMessage: 'No active branch selected');
      return false;
    }

    state = state.copyWith(isLoading: true);
    try {
      final customer = await _repository.createCustomer(
        branchId: branchId,
        name: name,
        phone: phone,
        email: email,
        address: address,
        userId: _currentUserId,
      );
      state = state.copyWith(
        customers: [...state.customers, customer]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
      return false;
    }
  }

  Future<bool> editCustomer(
    String id, {
    required String name,
    required String phone,
    String? email,
    String? address,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final updated = await _repository.updateCustomer(
        id,
        name: name,
        phone: phone,
        email: email,
        address: address,
        userId: _currentUserId,
      );
      state = state.copyWith(
        customers: state.customers.map((c) => c.id == id ? updated : c).toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
      return false;
    }
  }

  Future<bool> removeCustomer(String id) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.deleteCustomer(id);
      state = state.copyWith(
        customers: state.customers.where((c) => c.id != id).toList(),
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
final customerRepositoryProvider = Provider<CustomerRepository>((ref) => CustomerRepository());

final customerControllerProvider = NotifierProvider<CustomerController, CustomerState>(CustomerController.new);
