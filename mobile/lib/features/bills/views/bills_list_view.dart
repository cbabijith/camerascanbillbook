import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../controllers/bill_controller.dart';
import '../models/bill.dart';
import '../utils/invoice_pdf_helper.dart';
import 'bill_details_view.dart';
import '../../branches/controllers/branch_controller.dart';
import '../../auth/controllers/auth_controller.dart';
import 'billing_form_view.dart';
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Collect Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Outstanding Due:', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('₹${bill.dueAmount.toStringAsFixed(2)}', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ShadInput(
                label: 'Amount to Collect *',
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                validator: (val) {
                  final parsed = double.tryParse(val ?? '');
                  if (parsed == null || parsed <= 0) return 'Enter a valid positive amount';
                  if (parsed > bill.dueAmount) return 'Cannot collect more than due';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: method,
                decoration: const InputDecoration(
                  labelText: 'Payment Mode',
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'upi', child: Text('UPI / Scan')),
                  DropdownMenuItem(value: 'card', child: Text('Card Payment')),
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
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Payment recorded successfully'), backgroundColor: AppColors.success),
                  );
                } else {
                  final err = ref.read(billControllerProvider).errorMessage ?? 'Failed to collect payment';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(err), backgroundColor: AppColors.danger),
                  );
                }
              }
            },
            child: const Text('Record Payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
        content: const Text('Are you sure you want to delete this invoice? This action cannot be undone.'),
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
      final success = await ref.read(billControllerProvider.notifier).removeBill(id);
      if (!success && mounted) {
        final err = ref.read(billControllerProvider).errorMessage ?? 'Failed to delete';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AppColors.danger),
        );
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
      address: branch.address,
    );
  }

  void _printPdf(Bill bill) {
    final activeBranchId = ref.read(branchControllerProvider).activeBranchId;
    final branches = ref.read(branchControllerProvider).branches;
    final branch = branches.firstWhere((b) => b.id == activeBranchId);

    InvoicePdfHelper.printInvoice(
      bill,
      branch.name,
      gstin: branch.gstin,
      phone: branch.phone,
      address: branch.address,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(billControllerProvider);
    final authState = ref.watch(authControllerProvider);
    final isAdmin = authState.profile?.isAdmin ?? false;

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
          // Sleek Header Controls
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search invoice or customer name...',
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
                const SizedBox(height: 12),
                // Premium Horizontal Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('all', 'All Bills'),
                      const SizedBox(width: 8),
                      _buildFilterChip('paid', 'Paid'),
                      const SizedBox(width: 8),
                      _buildFilterChip('due', 'Partial / Advance'),
                      const SizedBox(width: 8),
                      _buildFilterChip('unpaid', 'Unpaid'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: state.isLoading && state.bills.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.textMuted.withOpacity(0.5)),
                            const SizedBox(height: 12),
                            Text('No invoices found', style: TextStyle(color: AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final bill = filtered[index];
                          final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(bill.createdAt.toLocal());

                          BadgeType bType = BadgeType.primary;
                          Color statusColor = AppColors.primary;
                          if (bill.paymentStatus == 'paid') {
                            bType = BadgeType.success;
                            statusColor = AppColors.success;
                          } else if (bill.paymentStatus == 'unpaid') {
                            bType = BadgeType.danger;
                            statusColor = AppColors.danger;
                          } else if (bill.paymentStatus == 'advance' || bill.paymentStatus == 'partial') {
                            bType = BadgeType.warning;
                            statusColor = AppColors.warning;
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: AppColors.border, width: 1),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => BillDetailsView(bill: bill),
                                    ),
                                  );
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      left: BorderSide(color: statusColor, width: 4),
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: statusColor.withOpacity(0.08),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(Icons.receipt_outlined, size: 16, color: statusColor),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              bill.billNumber,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                                            ),
                                          ],
                                        ),
                                        ShadBadge(label: bill.paymentStatus.toUpperCase(), type: bType),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      bill.customerName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Phone: ${bill.customerPhone}',
                                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                        ),
                                        Text(
                                          formattedDate,
                                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                        ),
                                      ],
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 12.0),
                                      child: Divider(color: AppColors.border, height: 1),
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Text('Total: ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                                Text('₹${bill.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                                              ],
                                            ),
                                            if (bill.dueAmount > 0)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 2.0),
                                                child: Row(
                                                  children: [
                                                    const Text('Due: ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                                    Text('₹${bill.dueAmount.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.bold)),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            _buildActionBtn(
                                              icon: Icons.print_outlined,
                                              color: AppColors.primary,
                                              tooltip: 'Print Receipt',
                                              onTap: () => _printPdf(bill),
                                            ),
                                            const SizedBox(width: 8),
                                            _buildActionBtn(
                                              icon: Icons.share_outlined,
                                              color: AppColors.primary,
                                              tooltip: 'Share Invoice',
                                              onTap: () => _sharePdf(bill),
                                            ),
                                            if (bill.dueAmount > 0) ...[
                                              const SizedBox(width: 8),
                                              _buildActionBtn(
                                                icon: Icons.account_balance_wallet_outlined,
                                                color: AppColors.success,
                                                tooltip: 'Collect Payment',
                                                onTap: () => _showCollectPaymentDialog(bill),
                                              ),
                                            ],
                                            const SizedBox(width: 8),
                                            _buildActionBtn(
                                              icon: Icons.delete_outline,
                                              color: AppColors.danger,
                                              tooltip: 'Delete Bill',
                                              onTap: () => _deleteBill(bill.id),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      ),
          ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const BillingFormView(showAppBar: true),
                  ),
                );
                ref.read(billControllerProvider.notifier).fetchBills();
              },
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('New Invoice', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _statusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() => _statusFilter = value);
        }
      },
      selectedColor: AppColors.primaryLight,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.border,
        ),
      ),
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }
}
