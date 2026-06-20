import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/product_controller.dart';
import '../models/product.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/custom_widgets.dart';

class ProductListView extends ConsumerStatefulWidget {
  const ProductListView({super.key});

  @override
  ConsumerState<ProductListView> createState() => _ProductListViewState();
}

class _ProductListViewState extends ConsumerState<ProductListView> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(productControllerProvider.notifier).fetchProducts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddOrEditDialog([Product? product]) {
    final isEdit = product != null;
    final nameCtrl = TextEditingController(text: isEdit ? product.name : '');
    final brandCtrl = TextEditingController(text: isEdit ? product.brand ?? '' : '');
    final catCtrl = TextEditingController(text: isEdit ? product.category ?? '' : '');
    final skuCtrl = TextEditingController(text: isEdit ? product.sku : '');
    final priceCtrl = TextEditingController(text: isEdit ? product.sellingPrice.toString() : '');
    final mrpCtrl = TextEditingController(text: isEdit ? product.mrp?.toString() ?? '' : '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isEdit ? 'Edit Product' : 'Add Product', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShadInput(
                  label: 'Product Name *',
                  controller: nameCtrl,
                  validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                ShadInput(
                  label: 'Serial Number / SKU *',
                  controller: skuCtrl,
                  validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ShadInput(
                        label: 'Selling Price *',
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ShadInput(
                        label: 'MRP',
                        controller: mrpCtrl,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ShadInput(
                        label: 'Brand',
                        controller: brandCtrl,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ShadInput(
                        label: 'Category',
                        controller: catCtrl,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final name = nameCtrl.text.trim();
              final sku = skuCtrl.text.trim();
              final brand = brandCtrl.text.trim().isEmpty ? null : brandCtrl.text.trim();
              final category = catCtrl.text.trim().isEmpty ? null : catCtrl.text.trim();
              final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
              final mrp = mrpCtrl.text.trim().isEmpty ? null : double.tryParse(mrpCtrl.text.trim());

              bool success;
              if (isEdit) {
                success = await ref.read(productControllerProvider.notifier).editProduct(
                      product.id,
                      name: name,
                      brand: brand,
                      category: category,
                      sku: sku,
                      sellingPrice: price,
                      mrp: mrp,
                    );
              } else {
                success = await ref.read(productControllerProvider.notifier).addProduct(
                      name: name,
                      brand: brand,
                      category: category,
                      sku: sku,
                      sellingPrice: price,
                      mrp: mrp,
                    );
              }

              if (mounted) {
                Navigator.of(context).pop();
                if (!success) {
                  final err = ref.read(productControllerProvider).errorMessage ?? 'An error occurred';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(err), backgroundColor: AppColors.danger),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isEdit ? 'Product details updated' : 'Product added to catalogue'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              }
            },
            child: Text(isEdit ? 'Save' : 'Add Product', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _deleteProduct(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: const Text('Are you sure you want to delete this product from the catalogue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ref.read(productControllerProvider.notifier).removeProduct(id);
      if (!success && mounted) {
        final err = ref.read(productControllerProvider).errorMessage ?? 'Failed to delete';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productControllerProvider);
    final filteredList = state.products.where((p) {
      final q = _searchQuery.toLowerCase();
      return p.name.toLowerCase().contains(q) ||
          p.sku.toLowerCase().contains(q) ||
          (p.brand != null && p.brand!.toLowerCase().contains(q));
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, SKU, brand...',
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          Expanded(
            child: state.isLoading && state.products.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : filteredList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_bag_outlined, size: 64, color: AppColors.textMuted.withOpacity(0.5)),
                            const SizedBox(height: 12),
                            Text('No products found', style: TextStyle(color: AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredList.length,
                        itemBuilder: (context, index) {
                          final product = filteredList[index];

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: AppColors.border, width: 1),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Row(
                                children: [
                                  // Product visual avatar representation
                                  Container(
                                    height: 52,
                                    width: 52,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryLight,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.camera_alt_outlined,
                                        color: AppColors.primary,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  // Product details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.qr_code_scanner, size: 12, color: AppColors.textSecondary),
                                            const SizedBox(width: 4),
                                            Text('SN/SKU: ${product.sku}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        // Brand / Category Badges
                                        Row(
                                          children: [
                                            if (product.brand != null) ...[
                                              ShadBadge(label: product.brand!, type: BadgeType.info),
                                              const SizedBox(width: 6),
                                            ],
                                            if (product.category != null)
                                              ShadBadge(label: product.category!, type: BadgeType.primary),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Price + Actions Column
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '₹${product.sellingPrice.toStringAsFixed(2)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.success),
                                      ),
                                      if (product.mrp != null)
                                        Text(
                                          'MRP: ₹${product.mrp!.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.textMuted,
                                            decoration: TextDecoration.lineThrough,
                                          ),
                                        ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 18),
                                            onPressed: () => _showAddOrEditDialog(product),
                                            constraints: const BoxConstraints(),
                                            padding: const EdgeInsets.all(4),
                                            tooltip: 'Edit Product',
                                          ),
                                          const SizedBox(width: 6),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 18),
                                            onPressed: () => _deleteProduct(product.id),
                                            constraints: const BoxConstraints(),
                                            padding: const EdgeInsets.all(4),
                                            tooltip: 'Delete Product',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'product_fab',
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () => _showAddOrEditDialog(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
