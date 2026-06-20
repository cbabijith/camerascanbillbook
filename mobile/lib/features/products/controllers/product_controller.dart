import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import '../repositories/product_repository.dart';
import '../../branches/controllers/branch_controller.dart';
import '../../auth/controllers/auth_controller.dart';

class ProductState {
  final List<Product> products;
  final List<Product> searchResults;
  final bool isLoading;
  final String? errorMessage;

  ProductState({
    this.products = const [],
    this.searchResults = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  ProductState copyWith({
    List<Product>? products,
    List<Product>? searchResults,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ProductState(
      products: products ?? this.products,
      searchResults: searchResults ?? this.searchResults,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class ProductController extends Notifier<ProductState> {
  ProductRepository get _repository => ref.read(productRepositoryProvider);

  @override
  ProductState build() {
    // Watch active branch to reload products automatically on switch
    final branchState = ref.watch(branchControllerProvider);
    if (branchState.activeBranchId != null) {
      Future.microtask(() => fetchProducts());
    }

    return ProductState();
  }

  String? get _activeBranchId => ref.read(branchControllerProvider).activeBranchId;
  String? get _currentUserId => ref.read(authControllerProvider).profile?.id;

  Future<void> fetchProducts() async {
    final branchId = _activeBranchId;
    if (branchId == null) return;

    state = state.copyWith(isLoading: true);
    try {
      final list = await _repository.getProducts(branchId);
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      state = state.copyWith(products: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
    }
  }

  Future<List<Product>> search(String query) async {
    final branchId = _activeBranchId;
    if (branchId == null || query.trim().isEmpty) {
      state = state.copyWith(searchResults: const []);
      return const [];
    }

    try {
      final results = await _repository.searchProducts(branchId, query);
      state = state.copyWith(searchResults: results);
      return results;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return const [];
    }
  }

  Future<bool> addProduct({
    required String name,
    String? brand,
    String? category,
    required String sku,
    required double sellingPrice,
    double? mrp,
  }) async {
    final branchId = _activeBranchId;
    if (branchId == null) {
      state = state.copyWith(errorMessage: 'No active branch selected');
      return false;
    }

    state = state.copyWith(isLoading: true);
    try {
      final product = await _repository.createProduct(
        branchId: branchId,
        name: name,
        brand: brand,
        category: category,
        sku: sku,
        sellingPrice: sellingPrice,
        mrp: mrp,
        userId: _currentUserId,
      );
      state = state.copyWith(
        products: [...state.products, product]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
      return false;
    }
  }

  Future<bool> editProduct(
    String id, {
    required String name,
    String? brand,
    String? category,
    required String sku,
    required double sellingPrice,
    double? mrp,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final updated = await _repository.updateProduct(
        id,
        name: name,
        brand: brand,
        category: category,
        sku: sku,
        sellingPrice: sellingPrice,
        mrp: mrp,
        userId: _currentUserId,
      );
      state = state.copyWith(
        products: state.products.map((p) => p.id == id ? updated : p).toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
      return false;
    }
  }

  Future<bool> removeProduct(String id) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.deleteProduct(id);
      state = state.copyWith(
        products: state.products.where((p) => p.id != id).toList(),
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
final productRepositoryProvider = Provider<ProductRepository>((ref) => ProductRepository());

final productControllerProvider = NotifierProvider<ProductController, ProductState>(ProductController.new);
