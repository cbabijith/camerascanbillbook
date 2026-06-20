import 'package:flutter/material.dart';
import '../../../core/widgets/custom_widgets.dart';

class CustomProductDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onAdd;

  const CustomProductDialog({super.key, required this.onAdd});

  @override
  State<CustomProductDialog> createState() => _CustomProductDialogState();
}

class _CustomProductDialogState extends State<CustomProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _priceController = TextEditingController();
  final _mrpController = TextEditingController();
  final _brandController = TextEditingController();
  final _categoryController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _priceController.dispose();
    _mrpController.dispose();
    _brandController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final price = double.tryParse(_priceController.text) ?? 0.0;
    final mrp = double.tryParse(_mrpController.text);

    widget.onAdd({
      'productId': 'new',
      'name': _nameController.text.trim(),
      'sku': _skuController.text.trim(),
      'sellingPrice': price,
      'mrp': mrp,
      'brand': _brandController.text.trim().isEmpty ? null : _brandController.text.trim(),
      'category': _categoryController.text.trim().isEmpty ? null : _categoryController.text.trim(),
      'qty': 1,
    });
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Add Custom Product Inline',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ShadInput(
                label: 'Product Name *',
                hintText: 'e.g. Sony A7 IV Camera',
                controller: _nameController,
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              ShadInput(
                label: 'Serial Number *',
                hintText: 'Enter serial number/barcode',
                controller: _skuController,
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ShadInput(
                      label: 'Selling Price *',
                      hintText: '120000.00',
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ShadInput(
                      label: 'MRP (Optional)',
                      hintText: '135000.00',
                      controller: _mrpController,
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
                      label: 'Brand (Optional)',
                      hintText: 'e.g. Sony',
                      controller: _brandController,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ShadInput(
                      label: 'Category (Optional)',
                      hintText: 'e.g. Camera',
                      controller: _categoryController,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ShadButton(
                label: 'Add to Invoice',
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
