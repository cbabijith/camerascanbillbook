import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../controllers/customer_controller.dart';
import '../models/customer.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/custom_widgets.dart';
import 'customer_details_view.dart';

class CustomerListView extends ConsumerStatefulWidget {
  const CustomerListView({super.key});

  @override
  ConsumerState<CustomerListView> createState() => _CustomerListViewState();
}

class _CustomerListViewState extends ConsumerState<CustomerListView> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(customerControllerProvider.notifier).fetchCustomers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddOrEditDialog([Customer? customer]) {
    final isEdit = customer != null;
    final nameCtrl = TextEditingController(text: isEdit ? customer.name : '');
    final phoneCtrl = TextEditingController(text: isEdit ? customer.phone : '');
    final emailCtrl = TextEditingController(text: isEdit ? customer.email ?? '' : '');
    final addrCtrl = TextEditingController(text: isEdit ? customer.address ?? '' : '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isEdit ? 'Edit Customer' : 'Add Customer', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShadInput(
                  label: 'Customer Name *',
                  controller: nameCtrl,
                  validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                ShadInput(
                  label: 'Phone Number *',
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                ShadInput(
                  label: 'Email (Optional)',
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                ShadInput(
                  label: 'Address (Optional)',
                  controller: addrCtrl,
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
              final phone = phoneCtrl.text.trim();
              final email = emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim();
              final address = addrCtrl.text.trim().isEmpty ? null : addrCtrl.text.trim();

              bool success;
              if (isEdit) {
                success = await ref.read(customerControllerProvider.notifier).editCustomer(
                      customer.id,
                      name: name,
                      phone: phone,
                      email: email,
                      address: address,
                    );
              } else {
                success = await ref.read(customerControllerProvider.notifier).addCustomer(
                      name: name,
                      phone: phone,
                      email: email,
                      address: address,
                    );
              }

              if (mounted) {
                Navigator.of(context).pop();
                if (!success) {
                  final err = ref.read(customerControllerProvider).errorMessage ?? 'An error occurred';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(err), backgroundColor: AppColors.danger),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isEdit ? 'Customer updated' : 'Customer added'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              }
            },
            child: Text(isEdit ? 'Save' : 'Add Customer', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _deleteCustomer(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Customer'),
        content: const Text('Are you sure you want to delete this customer? This cannot be undone.'),
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
      final success = await ref.read(customerControllerProvider.notifier).removeCustomer(id);
      if (!success && mounted) {
        final err = ref.read(customerControllerProvider).errorMessage ?? 'Failed to delete';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length > 1) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customerControllerProvider);
    final filteredList = state.customers.where((c) {
      final q = _searchQuery.toLowerCase();
      return c.name.toLowerCase().contains(q) || c.phone.contains(q);
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
                hintText: 'Search by name or phone...',
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
            child: state.isLoading && state.customers.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : filteredList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 64, color: AppColors.textMuted.withOpacity(0.5)),
                            const SizedBox(height: 12),
                            Text('No customers found', style: TextStyle(color: AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredList.length,
                        itemBuilder: (context, index) {
                          final customer = filteredList[index];
                          final initials = _getInitials(customer.name);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: AppColors.border, width: 1),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => CustomerDetailsView(customer: customer),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(14.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                  Row(
                                    children: [
                                      // Profile initials avatar
                                      Container(
                                        height: 48,
                                        width: 48,
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryLight,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Center(
                                          child: Text(
                                            initials,
                                            style: const TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      // Details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              customer.name,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                const Icon(Icons.phone_outlined, size: 12, color: AppColors.textSecondary),
                                                const SizedBox(width: 4),
                                                Text(customer.phone, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                              ],
                                            ),
                                            if (customer.email != null) ...[
                                              const SizedBox(height: 2),
                                              Row(
                                                children: [
                                                  const Icon(Icons.mail_outline, size: 12, color: AppColors.textSecondary),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      customer.email!,
                                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                            if (customer.address != null) ...[
                                              const SizedBox(height: 2),
                                              Row(
                                                children: [
                                                  const Icon(Icons.location_on_outlined, size: 12, color: AppColors.textSecondary),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      customer.address!,
                                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      // Actions
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                                            onPressed: () => _showAddOrEditDialog(customer),
                                            tooltip: 'Edit Profile',
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                                            onPressed: () => _deleteCustomer(customer.id),
                                            tooltip: 'Delete Profile',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const Divider(color: AppColors.border, height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Created by: ${customer.creatorName ?? 'System'}',
                                        style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                      ),
                                      Text(
                                        DateFormat('dd-MMM-yyyy').format(customer.createdAt),
                                        style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                      ),
                                    ],
                                  ),
                                 ],
                              ),
                            ),
                          ),
                        );
                      },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'customer_fab',
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () => _showAddOrEditDialog(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
