import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bill.dart';
import '../repositories/bill_repository.dart';
import '../../branches/controllers/branch_controller.dart';
import '../../auth/controllers/auth_controller.dart';

class BillState {
  final List<Bill> bills;
  final bool isLoading;
  final String? errorMessage;

  BillState({
    this.bills = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  BillState copyWith({
    List<Bill>? bills,
    bool? isLoading,
    String? errorMessage,
  }) {
    return BillState(
      bills: bills ?? this.bills,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class BillController extends Notifier<BillState> {
  BillRepository get _repository => ref.read(billRepositoryProvider);

  @override
  BillState build() {
    // Watch active branch to reload bills automatically on switch
    final branchState = ref.watch(branchControllerProvider);
    if (branchState.activeBranchId != null) {
      Future.microtask(() => fetchBills());
    }

    return BillState();
  }

  String? get _activeBranchId => ref.read(branchControllerProvider).activeBranchId;
  String? get _currentUserId => ref.read(authControllerProvider).profile?.id;

  Future<void> fetchBills() async {
    final branchId = _activeBranchId;
    if (branchId == null) return;

    state = state.copyWith(isLoading: true);
    try {
      final list = await _repository.getBills(branchId);
      state = state.copyWith(bills: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
    }
  }

  Future<bool> createInvoice({
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
    final branchId = _activeBranchId;
    final userId = _currentUserId;
    if (branchId == null || userId == null) {
      state = state.copyWith(errorMessage: 'Unauthorized or no active branch');
      return false;
    }

    state = state.copyWith(isLoading: true);
    try {
      await _repository.createBill(
        branchId: branchId,
        userId: userId,
        customerId: customerId,
        customerName: customerName,
        customerPhone: customerPhone,
        customerEmail: customerEmail,
        customerAddress: customerAddress,
        items: items,
        paymentStatus: paymentStatus,
        advanceAmount: advanceAmount,
        discount: discount,
        paymentMethod: paymentMethod,
      );
      await fetchBills();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
      return false;
    }
  }

  Future<bool> updateInvoice(
    String billId, {
    required String customerName,
    required String customerPhone,
    String? customerEmail,
    String? customerAddress,
    required List<Map<String, dynamic>> items,
    required String paymentStatus,
    double? advanceAmount,
    double? discount,
  }) async {
    final branchId = _activeBranchId;
    final userId = _currentUserId;
    if (branchId == null || userId == null) {
      state = state.copyWith(errorMessage: 'Unauthorized or no active branch');
      return false;
    }

    state = state.copyWith(isLoading: true);
    try {
      await _repository.updateBill(
        billId: billId,
        branchId: branchId,
        userId: userId,
        customerName: customerName,
        customerPhone: customerPhone,
        customerEmail: customerEmail,
        customerAddress: customerAddress,
        items: items,
        paymentStatus: paymentStatus,
        advanceAmount: advanceAmount,
        discount: discount,
      );
      await fetchBills();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
      return false;
    }
  }

  Future<bool> collectPayment({
    required String billId,
    required double amount,
    required String paymentMethod,
  }) async {
    final branchId = _activeBranchId;
    final userId = _currentUserId;
    if (branchId == null || userId == null) {
      state = state.copyWith(errorMessage: 'Unauthorized or no active branch');
      return false;
    }

    state = state.copyWith(isLoading: true);
    try {
      await _repository.collectPayment(
        billId: billId,
        branchId: branchId,
        userId: userId,
        amount: amount,
        paymentMethod: paymentMethod,
      );
      await fetchBills();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
      return false;
    }
  }

  Future<bool> removeBill(String id) async {
    final branchId = _activeBranchId;
    if (branchId == null) return false;

    state = state.copyWith(isLoading: true);
    try {
      await _repository.deleteBill(id, branchId);
      state = state.copyWith(
        bills: state.bills.where((b) => b.id != id).toList(),
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
final billRepositoryProvider = Provider<BillRepository>((ref) => BillRepository());

final billControllerProvider = NotifierProvider<BillController, BillState>(BillController.new);
