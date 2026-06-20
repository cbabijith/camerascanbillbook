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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(isEdit ? 'Edit Product' : 'Add Product'),
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
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
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
                }
              }
            },
            child: Text(isEdit ? 'Save Changes' : 'Add Product', style: const TextStyle(color: Colors.white)),
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
            child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search by name, SKU, brand...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          Expanded(
            child: state.isLoading && state.products.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : filteredList.isEmpty
                    ? const Center(child: Text('No products found', style: TextStyle(color: AppColors.textSecondary)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredList.length,
                        itemBuilder: (context, index) {
                          final product = filteredList[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('SN/SKU: ${product.sku}'),
                                  if (product.brand != null) Text('Brand: ${product.brand}'),
                                  if (product.category != null) Text('Category: ${product.category}'),
                                  Text('Price: ₹${product.sellingPrice.toStringAsFixed(2)}'),
                                  if (product.mrp != null) Text('MRP: ₹${product.mrp!.toStringAsFixed(2)}'),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: AppColors.primary),
                                    onPressed: () => _showAddOrEditDialog(product),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: AppColors.danger),
                                    onPressed: () => _deleteProduct(product.id),
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
        onPressed: () => _showAddOrEditDialog(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
