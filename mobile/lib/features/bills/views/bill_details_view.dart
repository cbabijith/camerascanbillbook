import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/bill.dart';
import '../models/payment_collection.dart';
import '../controllers/bill_controller.dart';
import '../utils/invoice_pdf_helper.dart';
import '../../branches/controllers/branch_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/custom_widgets.dart';

class BillDetailsView extends ConsumerStatefulWidget {
  final Bill bill;

  const BillDetailsView({super.key, required this.bill});

  @override
  ConsumerState<BillDetailsView> createState() => _BillDetailsViewState();
}

class _BillDetailsViewState extends ConsumerState<BillDetailsView> {
  List<PaymentCollection>? _payments;
  bool _loadingPayments = false;
  String? _paymentError;

  @override
  void initState() {
    super.initState();
    _fetchPaymentHistory();
  }

  Future<void> _fetchPaymentHistory() async {
    setState(() {
      _loadingPayments = true;
      _paymentError = null;
    });

    try {
      final payments = await ref.read(billRepositoryProvider).getPaymentCollections(widget.bill.id);
      if (mounted) {
        setState(() {
          _payments = payments;
          _loadingPayments = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _paymentError = 'Failed to load payment history';
          _loadingPayments = false;
        });
      }
    }
  }

  void _sharePdf() {
    final activeBranchId = ref.read(branchControllerProvider).activeBranchId;
    final branches = ref.read(branchControllerProvider).branches;
    final branch = branches.firstWhere((b) => b.id == activeBranchId);

    InvoicePdfHelper.shareInvoice(
      widget.bill,
      branch.name,
      gstin: branch.gstin,
      phone: branch.phone,
      address: branch.address,
    );
  }

  void _printPdf() {
    final activeBranchId = ref.read(branchControllerProvider).activeBranchId;
    final branches = ref.read(branchControllerProvider).branches;
    final branch = branches.firstWhere((b) => b.id == activeBranchId);

    InvoicePdfHelper.printInvoice(
      widget.bill,
      branch.name,
      gstin: branch.gstin,
      phone: branch.phone,
      address: branch.address,
    );
  }

  void _deleteBill() async {
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

    if (confirm == true && mounted) {
      final success = await ref.read(billControllerProvider.notifier).removeBill(widget.bill.id);
      if (mounted) {
        if (success) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invoice deleted successfully'), backgroundColor: AppColors.success),
          );
        } else {
          final err = ref.read(billControllerProvider).errorMessage ?? 'Failed to delete';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err), backgroundColor: AppColors.danger),
          );
        }
      }
    }
  }

  void _showCollectPaymentDialog() {
    final amountCtrl = TextEditingController(text: widget.bill.dueAmount.toStringAsFixed(2));
    String method = 'cash';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
                      Text('₹${widget.bill.dueAmount.toStringAsFixed(2)}', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 15)),
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
                    if (parsed > widget.bill.dueAmount) return 'Cannot collect more than due';
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
                  onChanged: (val) => setDialogState(() => method = val!),
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

                Navigator.of(dialogCtx).pop();

                final success = await ref.read(billControllerProvider.notifier).collectPayment(
                      billId: widget.bill.id,
                      amount: amount,
                      paymentMethod: method,
                    );

                if (mounted) {
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Payment recorded successfully'), backgroundColor: AppColors.success),
                    );
                    _fetchPaymentHistory(); // Refresh payment timeline
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch bills state to display updated bill details if payment was collected
    final state = ref.watch(billControllerProvider);
    final currentBill = state.bills.firstWhere(
      (b) => b.id == widget.bill.id,
      orElse: () => widget.bill,
    );

    final activeBranchId = ref.watch(branchControllerProvider).activeBranchId;
    final branches = ref.watch(branchControllerProvider).branches;
    final branch = branches.firstWhere(
      (b) => b.id == activeBranchId,
      orElse: () => branches.first,
    );

    final formattedDate = DateFormat('dd MMM yyyy').format(currentBill.createdAt.toLocal());
    final formattedTime = DateFormat('hh:mm a').format(currentBill.createdAt.toLocal());

    BadgeType bType = BadgeType.primary;
    if (currentBill.paymentStatus == 'paid') {
      bType = BadgeType.success;
    } else if (currentBill.paymentStatus == 'unpaid') {
      bType = BadgeType.danger;
    } else if (currentBill.paymentStatus == 'advance' || currentBill.paymentStatus == 'partial') {
      bType = BadgeType.warning;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Invoice ${currentBill.billNumber}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined, color: AppColors.primary),
            tooltip: 'Print Receipt',
            onPressed: _printPdf,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: AppColors.primary),
            tooltip: 'Share PDF',
            onPressed: _sharePdf,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            tooltip: 'Delete Bill',
            onPressed: _deleteBill,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info Card (Branch & Bill metadata)
            ShadCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            branch.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                          ),
                          if (branch.phone != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2.0),
                              child: Text('Phone: ${branch.phone}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ),
                          if (branch.gstin != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2.0),
                              child: Text('GSTIN: ${branch.gstin}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontFamily: 'monospace')),
                            ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          ShadBadge(label: currentBill.paymentStatus.toUpperCase(), type: bType),
                          const SizedBox(height: 6),
                          Text(formattedDate, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          Text(formattedTime, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Customer Billed To Card
            ShadCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'BILLED TO:',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentBill.customerName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(currentBill.customerPhone, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Items List Header
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
              child: Text(
                'ITEMS',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1),
              ),
            ),

            // Items ListView
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: currentBill.items.length,
              itemBuilder: (context, idx) {
                final item = currentBill.items[idx];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                              ),
                              if (item.brand != null || item.category != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: Text(
                                    [item.brand, item.category].whereType<String>().join(' • '),
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                ),
                              if (item.sku.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: Text(
                                    'SN: ${item.sku}',
                                    style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontFamily: 'monospace'),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${item.total.toStringAsFixed(0)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                            ),
                            Text(
                              '${item.qty} x ₹${item.sellingPrice.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Summary Totals Card
            ShadCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildTotalRow('Subtotal', '₹${currentBill.subTotal.toStringAsFixed(2)}'),
                  if (currentBill.discount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: _buildTotalRow('Discount', '-₹${currentBill.discount.toStringAsFixed(2)}', color: AppColors.danger),
                    ),
                  if (currentBill.gstAmount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: _buildTotalRow('GST', '₹${currentBill.gstAmount.toStringAsFixed(2)}'),
                    ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10.0),
                    child: Divider(color: AppColors.border, height: 1),
                  ),
                  _buildTotalRow('Grand Total', '₹${currentBill.total.toStringAsFixed(2)}', isBold: true, color: AppColors.primary, size: 16),
                  if (currentBill.advanceAmount > 0) ...[
                    const SizedBox(height: 8),
                    _buildTotalRow('Advance / Paid', '₹${currentBill.advanceAmount.toStringAsFixed(2)}', color: AppColors.success),
                  ],
                  if (currentBill.dueAmount > 0) ...[
                    const SizedBox(height: 8),
                    _buildTotalRow('Remaining Due', '₹${currentBill.dueAmount.toStringAsFixed(2)}', isBold: true, color: AppColors.danger),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Payment timeline / history
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
              child: Text(
                'PAYMENT HISTORY',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1),
              ),
            ),

            if (_loadingPayments)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_paymentError != null)
              Center(
                child: Column(
                  children: [
                    Text(_paymentError!, style: const TextStyle(color: AppColors.danger)),
                    TextButton(onPressed: _fetchPaymentHistory, child: const Text('Retry')),
                  ],
                ),
              )
            else if (_payments == null || _payments!.isEmpty)
              const ShadCard(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text('No payment history recorded.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ),
              )
            else
              ShadCard(
                padding: const EdgeInsets.all(16),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _payments!.length,
                  separatorBuilder: (context, index) => const Divider(color: AppColors.border, height: 20),
                  itemBuilder: (context, idx) {
                    final payment = _payments![idx];
                    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(payment.createdAt.toLocal());
                    BadgeType payBadge = BadgeType.info;
                    if (payment.paymentType == 'final') {
                      payBadge = BadgeType.success;
                    } else if (payment.paymentType == 'advance') {
                      payBadge = BadgeType.primary;
                    } else {
                      payBadge = BadgeType.warning;
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.payment, size: 16, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '₹${payment.amount.toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(width: 8),
                                  ShadBadge(label: payment.paymentType.toUpperCase(), type: payBadge),
                                  const SizedBox(width: 4),
                                  ShadBadge(label: payment.paymentMethod.toUpperCase(), type: BadgeType.primary),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$dateStr${payment.collectorName != null ? " • By: ${payment.collectorName}" : ""}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
             const SizedBox(height: 32),
             Center(
               child: Column(
                 children: [
                   Text(
                     'Invoice generated by ${currentBill.createdByName ?? "staff member"}.',
                     style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                     textAlign: TextAlign.center,
                   ),
                   const SizedBox(height: 4),
                   const Text(
                     'Computer Generated Invoice. No Signature Required.',
                     style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                     textAlign: TextAlign.center,
                   ),
                 ],
               ),
             ),
             const SizedBox(height: 80), // bottom spacing for FAB
           ],
         ),
      ),
      floatingActionButton: (currentBill.paymentStatus != 'paid' && currentBill.dueAmount > 0)
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.success,
              icon: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white),
              label: const Text('Collect Payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: _showCollectPaymentDialog,
            )
          : null,
    );
  }

  Widget _buildTotalRow(String label, String value, {bool isBold = false, Color? color, double size = 13}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: size,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: size,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
