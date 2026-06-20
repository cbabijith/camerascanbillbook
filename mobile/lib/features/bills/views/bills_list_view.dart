import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../controllers/bill_controller.dart';
import '../models/bill.dart';
import '../utils/invoice_pdf_helper.dart';
import '../../branches/controllers/branch_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/custom_widgets.dart';

class BillsListView extends ConsumerStatefulWidget {
  const BillsListView({super.key});

  @override
  ConsumerState<BillsListView> createState() => _BillsListViewState();
}

class _BillsListViewState extends ConsumerState<BillsListView> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'all'; // 'all', 'paid', 'unpaid', 'due'

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(billControllerProvider.notifier).fetchBills();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showCollectPaymentDialog(Bill bill) {
    final amountCtrl = TextEditingController(text: bill.dueAmount.toStringAsFixed(2));
    String method = 'cash';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Collect Payment for ${bill.billNumber}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Outstanding Due: ₹${bill.dueAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ShadInput(
                label: 'Collect Amount *',
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                validator: (val) {
                  final parsed = double.tryParse(val ?? '');
                  if (parsed == null || parsed <= 0) return 'Enter a valid positive amount';
                  if (parsed > bill.dueAmount) return 'Cannot collect more than due amount';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: method,
                decoration: const InputDecoration(labelText: 'Payment Method'),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'upi', child: Text('UPI')),
                  DropdownMenuItem(value: 'card', child: Text('Card')),
                  DropdownMenuItem(value: 'bank', child: Text('Bank Transfer')),
                ],
                onChanged: (val) => method = val!,
              ),
            ],
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
              final amount = double.parse(amountCtrl.text.trim());

              final success = await ref.read(billControllerProvider.notifier).collectPayment(
                    billId: bill.id,
                    amount: amount,
                    paymentMethod: method,
                  );

              if (mounted) {
                Navigator.of(context).pop();
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment recorded successfully'), backgroundColor: AppColors.success));
                } else {
                  final err = ref.read(billControllerProvider).errorMessage ?? 'Failed to collect payment';
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: AppColors.danger));
                }
              }
            },
            child: const Text('Record Payment', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _deleteBill(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Invoice'),
        content: const Text('Are you sure you want to delete this invoice?'),
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
      final success = await ref.read(billControllerProvider.notifier).removeBill(id);
      if (!success && mounted) {
        final err = ref.read(billControllerProvider).errorMessage ?? 'Failed to delete';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: AppColors.danger));
      }
    }
  }

  void _sharePdf(Bill bill) {
    final activeBranchId = ref.read(branchControllerProvider).activeBranchId;
    final branches = ref.read(branchControllerProvider).branches;
    final branch = branches.firstWhere((b) => b.id == activeBranchId);

    InvoicePdfHelper.shareInvoice(
      bill,
      branch.name,
      gstin: branch.gstin,
      phone: branch.phone,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(billControllerProvider);

    final filtered = state.bills.where((b) {
      final q = _searchQuery.toLowerCase();
      final matchesSearch = b.billNumber.toLowerCase().contains(q) || b.customerName.toLowerCase().contains(q);

      if (!matchesSearch) return false;
      if (_statusFilter == 'paid') return b.paymentStatus == 'paid';
      if (_statusFilter == 'unpaid') return b.paymentStatus == 'unpaid';
      if (_statusFilter == 'due') return b.paymentStatus == 'advance' || b.paymentStatus == 'partial';
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search by invoice number or customer...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Status Filter:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    DropdownButton<String>(
                      value: _statusFilter,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Bills')),
                        DropdownMenuItem(value: 'paid', child: Text('Paid Only')),
                        DropdownMenuItem(value: 'unpaid', child: Text('Unpaid Only')),
                        DropdownMenuItem(value: 'due', child: Text('Partial/Advance')),
                      ],
                      onChanged: (val) => setState(() => _statusFilter = val!),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: state.isLoading && state.bills.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const Center(child: Text('No invoices found', style: TextStyle(color: AppColors.textSecondary)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final bill = filtered[index];
                          final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(bill.createdAt);

                          BadgeType bType = BadgeType.primary;
                          if (bill.paymentStatus == 'paid') bType = BadgeType.success;
                          if (bill.paymentStatus == 'unpaid') bType = BadgeType.danger;
                          if (bill.paymentStatus == 'advance' || bill.paymentStatus == 'partial') bType = BadgeType.warning;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(bill.billNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      ShadBadge(label: bill.paymentStatus.toUpperCase(), type: bType),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text('Customer: ${bill.customerName} (${bill.customerPhone})', style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text('Date: $formattedDate', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                  const Divider(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Total: ₹${bill.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                          if (bill.dueAmount > 0)
                                            Text('Due: ₹${bill.dueAmount.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.share, color: AppColors.primary),
                                            onPressed: () => _sharePdf(bill),
                                            tooltip: 'Share/Print Invoice',
                                          ),
                                          if (bill.dueAmount > 0)
                                            IconButton(
                                              icon: const Icon(Icons.payment, color: AppColors.success),
                                              onPressed: () => _showCollectPaymentDialog(bill),
                                              tooltip: 'Collect Payment',
                                            ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: AppColors.danger),
                                            onPressed: () => _deleteBill(bill.id),
                                            tooltip: 'Delete Bill',
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
    );
  }
}
