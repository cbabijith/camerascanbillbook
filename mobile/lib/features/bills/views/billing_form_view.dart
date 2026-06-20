import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/bill_controller.dart';
import '../../customers/controllers/customer_controller.dart';
import '../../products/controllers/product_controller.dart';
import '../../customers/models/customer.dart';
import '../../products/models/product.dart';
import 'custom_product_dialog.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/custom_widgets.dart';

class BillingFormView extends ConsumerStatefulWidget {
  final Map<String, dynamic>? editBill;

  const BillingFormView({super.key, this.editBill});

  @override
  ConsumerState<BillingFormView> createState() => _BillingFormViewState();
}

class _BillingFormViewState extends ConsumerState<BillingFormView> {
  Customer? _selectedCustomer;
  bool _isNewCustomer = false;
  final _customerSearchController = TextEditingController();
  final _newCustomerNameController = TextEditingController();
  final _newCustomerPhoneController = TextEditingController();
  final _newCustomerEmailController = TextEditingController();
  final _newCustomerAddressController = TextEditingController();

  final _productSearchController = TextEditingController();
  final List<Map<String, dynamic>> _billItems = [];

  String _paymentStatus = 'paid';
  String _paymentMethod = 'cash';
  final _advanceAmountController = TextEditingController();
  final _discountController = TextEditingController();

  List<Customer> _customerSearchResults = [];
  List<Product> _productSearchResults = [];

  @override
  void initState() {
    super.initState();
    _advanceAmountController.addListener(() => setState(() {}));
    _discountController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _customerSearchController.dispose();
    _newCustomerNameController.dispose();
    _newCustomerPhoneController.dispose();
    _newCustomerEmailController.dispose();
    _newCustomerAddressController.dispose();
    _productSearchController.dispose();
    _advanceAmountController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  double get _subtotal {
    return _billItems.fold(0.0, (sum, item) {
      final double price = (item['sellingPrice'] as num).toDouble();
      final int qty = (item['qty'] as num).toInt();
      return sum + (price * qty);
    });
  }

  double get _discount {
    return double.tryParse(_discountController.text) ?? 0.0;
  }

  double get _total {
    final t = _subtotal - _discount;
    return t < 0 ? 0.0 : t;
  }

  void _onCustomerSearchChanged(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _customerSearchResults = []);
      return;
    }
    final results = await ref.read(customerControllerProvider.notifier).search(query);
    setState(() => _customerSearchResults = results);
  }

  void _onProductSearchChanged(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _productSearchResults = []);
      return;
    }
    final results = await ref.read(productControllerProvider.notifier).search(query);
    setState(() => _productSearchResults = results);
  }

  void _addProductToBill(Product p) {
    setState(() {
      final idx = _billItems.indexWhere((item) => item['productId'] == p.id);
      if (idx > -1) {
        _billItems[idx]['qty'] = (_billItems[idx]['qty'] as int) + 1;
      } else {
        _billItems.add({
          'productId': p.id,
          'name': p.name,
          'brand': p.brand,
          'category': p.category,
          'sku': p.sku,
          'sellingPrice': p.sellingPrice,
          'mrp': p.mrp,
          'qty': 1,
        });
      }
      _productSearchController.clear();
      _productSearchResults = [];
    });
  }

  void _submit() async {
    if (_billItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one product')));
      return;
    }

    if (!_isNewCustomer && _selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select or create a customer')));
      return;
    }

    if (_isNewCustomer && (_newCustomerNameController.text.isEmpty || _newCustomerPhoneController.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer name and phone are required')));
      return;
    }

    final double? advanceAmt = double.tryParse(_advanceAmountController.text);
    if (_paymentStatus == 'advance') {
      if (advanceAmt == null || advanceAmt <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid advance amount')));
        return;
      }
      if (advanceAmt >= _total) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Advance cannot exceed total amount')));
        return;
      }
    }

    final success = await ref.read(billControllerProvider.notifier).createInvoice(
          customerId: _isNewCustomer ? 'new' : _selectedCustomer!.id,
          customerName: _isNewCustomer ? _newCustomerNameController.text.trim() : _selectedCustomer!.name,
          customerPhone: _isNewCustomer ? _newCustomerPhoneController.text.trim() : _selectedCustomer!.phone,
          customerEmail: _isNewCustomer ? _newCustomerEmailController.text.trim() : _selectedCustomer!.email,
          customerAddress: _isNewCustomer ? _newCustomerAddressController.text.trim() : _selectedCustomer!.address,
          items: _billItems,
          paymentStatus: _paymentStatus,
          advanceAmount: _paymentStatus == 'advance' ? advanceAmt : null,
          discount: _discount > 0 ? _discount : null,
          paymentMethod: _paymentStatus == 'paid' || _paymentStatus == 'advance' ? _paymentMethod : null,
        );

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invoice created successfully'), backgroundColor: AppColors.success));
        setState(() {
          _selectedCustomer = null;
          _isNewCustomer = false;
          _billItems.clear();
          _discountController.clear();
          _advanceAmountController.clear();
        });
      }
    } else {
      if (mounted) {
        final err = ref.read(billControllerProvider).errorMessage ?? 'Error saving invoice';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: AppColors.danger));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCustomerSection(),
            const SizedBox(height: 16),
            _buildProductsSection(),
            const SizedBox(height: 16),
            _buildTotalsSection(),
            const SizedBox(height: 24),
            ShadButton(
              label: 'Generate Invoice & Save',
              isLoading: ref.watch(billControllerProvider).isLoading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerSection() {
    return ShadCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Customer Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          if (!_isNewCustomer && _selectedCustomer == null) ...[
            TextField(
              controller: _customerSearchController,
              onChanged: _onCustomerSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Search customer by name or phone...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            if (_customerSearchResults.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(8)),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _customerSearchResults.length,
                  itemBuilder: (c, idx) {
                    final cust = _customerSearchResults[idx];
                    return ListTile(
                      title: Text(cust.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(cust.phone),
                      onTap: () {
                        setState(() {
                          _selectedCustomer = cust;
                          _customerSearchController.clear();
                          _customerSearchResults = [];
                        });
                      },
                    );
                  },
                ),
              ),
            if (_customerSearchController.text.isNotEmpty && _customerSearchResults.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text('Add "${_customerSearchController.text}" as New Customer'),
                  onPressed: () {
                    setState(() {
                      _isNewCustomer = true;
                      final isPhone = RegExp(r'^\d+$').hasMatch(_customerSearchController.text);
                      if (isPhone) {
                        _newCustomerPhoneController.text = _customerSearchController.text;
                      } else {
                        _newCustomerNameController.text = _customerSearchController.text;
                      }
                    });
                  },
                ),
              )
          ] else if (_selectedCustomer != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_selectedCustomer!.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('Phone: ${_selectedCustomer!.phone}'),
                    if (_selectedCustomer!.email != null) Text('Email: ${_selectedCustomer!.email}'),
                  ],
                ),
                TextButton(
                  onPressed: () => setState(() => _selectedCustomer = null),
                  child: const Text('Change', style: TextStyle(color: AppColors.danger)),
                )
              ],
            )
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('New Customer Form', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.success)),
                TextButton(
                  onPressed: () => setState(() => _isNewCustomer = false),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.danger)),
                )
              ],
            ),
            const SizedBox(height: 12),
            ShadInput(label: 'Name *', controller: _newCustomerNameController),
            const SizedBox(height: 8),
            ShadInput(label: 'Phone *', controller: _newCustomerPhoneController, keyboardType: TextInputType.phone),
            const SizedBox(height: 8),
            ShadInput(label: 'Email (Optional)', controller: _newCustomerEmailController, keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 8),
            ShadInput(label: 'Address (Optional)', controller: _newCustomerAddressController),
          ]
        ],
      ),
    );
  }

  Widget _buildProductsSection() {
    return ShadCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Invoice Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Custom Item'),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (c) => CustomProductDialog(
                      onAdd: (item) {
                        setState(() {
                          _billItems.add(item);
                        });
                      },
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _productSearchController,
            onChanged: _onProductSearchChanged,
            decoration: const InputDecoration(
              hintText: 'Search product by name or SKU...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          if (_productSearchResults.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(8)),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _productSearchResults.length,
                itemBuilder: (c, idx) {
                  final p = _productSearchResults[idx];
                  return ListTile(
                    title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('SKU: ${p.sku} • Price: ₹${p.sellingPrice}'),
                    onTap: () => _addProductToBill(p),
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
          if (_billItems.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Center(child: Text('No items added yet', style: TextStyle(color: AppColors.textSecondary))),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _billItems.length,
              separatorBuilder: (c, i) => const Divider(color: AppColors.border),
              itemBuilder: (c, idx) {
                final item = _billItems[idx];
                final double price = (item['sellingPrice'] as num).toDouble();
                final int qty = (item['qty'] as num).toInt();
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Price: ₹$price • SKU: ${item['sku']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () {
                          setState(() {
                            if (qty > 1) {
                              item['qty'] = qty - 1;
                            } else {
                              _billItems.removeAt(idx);
                            }
                          });
                        },
                      ),
                      Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () {
                          setState(() {
                            item['qty'] = qty + 1;
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                        onPressed: () => setState(() => _billItems.removeAt(idx)),
                      )
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTotalsSection() {
    return ShadCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Invoice Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Payment Status:'),
              DropdownButton<String>(
                value: _paymentStatus,
                items: const [
                  DropdownMenuItem(value: 'paid', child: Text('Paid')),
                  DropdownMenuItem(value: 'unpaid', child: Text('Unpaid')),
                  DropdownMenuItem(value: 'advance', child: Text('Advance')),
                ],
                onChanged: (val) => setState(() => _paymentStatus = val!),
              )
            ],
          ),
          if (_paymentStatus == 'paid' || _paymentStatus == 'advance') ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Payment Method:'),
                DropdownButton<String>(
                  value: _paymentMethod,
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'upi', child: Text('UPI')),
                    DropdownMenuItem(value: 'card', child: Text('Card')),
                    DropdownMenuItem(value: 'bank', child: Text('Bank Transfer')),
                  ],
                  onChanged: (val) => setState(() => _paymentMethod = val!),
                )
              ],
            ),
          ],
          if (_paymentStatus == 'advance') ...[
            const SizedBox(height: 8),
            ShadInput(
              label: 'Advance Amount Paid',
              hintText: 'Enter amount paid',
              controller: _advanceAmountController,
              keyboardType: TextInputType.number,
            ),
          ],
          const SizedBox(height: 12),
          ShadInput(
            label: 'Flat Discount',
            hintText: '0.00',
            controller: _discountController,
            keyboardType: TextInputType.number,
          ),
          const Divider(height: 24, color: AppColors.border),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subtotal:'),
              Text('₹${_subtotal.toStringAsFixed(2)}'),
            ],
          ),
          if (_discount > 0) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Discount:', style: TextStyle(color: AppColors.danger)),
                Text('-₹${_discount.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.danger)),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Final Invoice Total:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('₹${_total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }
}
