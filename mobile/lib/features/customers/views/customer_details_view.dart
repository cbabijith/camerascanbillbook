import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/customer.dart';
import '../../bills/controllers/bill_controller.dart';
import '../../bills/models/bill.dart';
import '../../bills/utils/invoice_pdf_helper.dart';
import '../../bills/views/bill_details_view.dart';
import '../../branches/controllers/branch_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/custom_widgets.dart';

class CustomerDetailsView extends ConsumerStatefulWidget {
  final Customer customer;

  const CustomerDetailsView({super.key, required this.customer});

  @override
  ConsumerState<CustomerDetailsView> createState() => _CustomerDetailsViewState();
}

class _CustomerDetailsViewState extends ConsumerState<CustomerDetailsView> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(billControllerProvider.notifier).fetchBills();
    });
  }

  String _formatINR(double amount) {
    return NumberFormat.currency(
      locale: 'en_IN',
      decimalDigits: 0,
      symbol: '₹',
    ).format(amount);
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
    final billsState = ref.watch(billControllerProvider);
    final customerBills = billsState.bills.where((b) {
      return b.customerId == widget.customer.id || b.customerPhone == widget.customer.phone;
    }).toList();

    // Calculations
    final double totalPurchases = customerBills.fold(0.0, (sum, b) => sum + b.total);
    final double outstandingBalance = customerBills.fold(0.0, (sum, b) => sum + b.dueAmount);
    final int invoiceCount = customerBills.length;

    final initials = widget.customer.name.trim().split(' ').map((e) => e[0]).join().toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Customer Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Card Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.primaryLight,
                      child: Text(
                        initials.substring(0, initials.length > 2 ? 2 : initials.length),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.customer.name,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.phone_outlined, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(widget.customer.phone, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                  if (widget.customer.email != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.mail_outline, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(widget.customer.email!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ],
                  if (widget.customer.address != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            widget.customer.address!,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Performance Cards Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: ShadCard(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      child: Column(
                        children: [
                          const Text('Total Billing', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(_formatINR(totalPurchases), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.success)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ShadCard(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      child: Column(
                        children: [
                          const Text('Outstanding', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(
                            _formatINR(outstandingBalance),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: outstandingBalance > 0 ? AppColors.danger : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ShadCard(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      child: Column(
                        children: [
                          const Text('Invoices', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('$invoiceCount', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Transaction / Invoices List Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Invoice History',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  ShadBadge(label: '$invoiceCount bills', type: BadgeType.info),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Invoice list
            billsState.isLoading
                ? const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator()))
                : customerBills.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.textMuted.withOpacity(0.4)),
                              const SizedBox(height: 8),
                              const Text('No billing history found.', style: TextStyle(color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: customerBills.length,
                        itemBuilder: (context, idx) {
                          final bill = customerBills[idx];
                          final formattedDate = DateFormat('dd MMM yyyy').format(bill.createdAt.toLocal());

                          BadgeType statusBadge = BadgeType.primary;
                          if (bill.paymentStatus == 'paid') {
                            statusBadge = BadgeType.success;
                          } else if (bill.paymentStatus == 'unpaid') {
                            statusBadge = BadgeType.danger;
                          } else if (bill.paymentStatus == 'advance' || bill.paymentStatus == 'partial') {
                            statusBadge = BadgeType.warning;
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: AppColors.border),
                            ),
                            child: ListTile(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => BillDetailsView(bill: bill),
                                  ),
                                );
                              },
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(bill.billNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  ShadBadge(label: bill.paymentStatus.toUpperCase(), type: statusBadge),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Date: $formattedDate', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('Total: ${_formatINR(bill.total)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        if (bill.dueAmount > 0)
                                          Text('Due: ${_formatINR(bill.dueAmount)}', style: const TextStyle(color: AppColors.danger, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.share_outlined, color: AppColors.primary, size: 20),
                                onPressed: () => _sharePdf(bill),
                              ),
                            ),
                          );
                        },
                      ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
