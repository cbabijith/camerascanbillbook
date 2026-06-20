import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../controllers/analytics_controller.dart';
import '../models/analytics_metrics.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/custom_widgets.dart';

class AnalyticsView extends ConsumerStatefulWidget {
  const AnalyticsView({super.key});

  @override
  ConsumerState<AnalyticsView> createState() => _AnalyticsViewState();
}

class _AnalyticsViewState extends ConsumerState<AnalyticsView> with TickerProviderStateMixin {
  TabController? _tabController;

  String _formatINR(double amount) {
    return NumberFormat.currency(
      locale: 'en_IN',
      decimalDigits: 0,
      symbol: '₹',
    ).format(amount);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(analyticsControllerProvider);

    if (state.isLoading && state.data.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Set up tabs: All Branches + each individual branch
    final branches = state.data;
    final tabCount = branches.length + 1;
    if (_tabController == null || _tabController!.length != tabCount) {
      _tabController?.dispose();
      _tabController = TabController(length: tabCount, vsync: this);
    }

    // Aggregated metrics across all branches
    final double totalSales = branches.fold(0.0, (sum, b) => sum + b.totalSales);
    final double totalReceived = branches.fold(0.0, (sum, b) => sum + b.totalReceived);
    final double totalDue = branches.fold(0.0, (sum, b) => sum + b.totalDue);
    final int totalInvoices = branches.fold(0, (sum, b) => sum + b.totalInvoices);
    final double avgBillValue = totalInvoices > 0 ? totalSales / totalInvoices : 0.0;

    // Combine payment method breakdown
    final Map<String, double> combinedMethods = {};
    for (final b in branches) {
      for (final pm in b.paymentMethodBreakdown) {
        combinedMethods[pm.method] = (combinedMethods[pm.method] ?? 0.0) + pm.amount;
      }
    }

    // Combine staff rankings
    final List<StaffRanking> combinedStaff = [];
    for (final b in branches) {
      for (final s in b.staffRanking) {
        combinedStaff.add(StaffRanking(
          name: s.name,
          billCount: s.billCount,
          totalSales: s.totalSales,
          collectedAmount: s.collectedAmount,
          branchName: b.branchName,
        ));
      }
    }
    combinedStaff.sort((a, b) => b.billCount.compareTo(a.billCount));

    // Combine overdue bills
    final List<OverdueDue> combinedOverdue = [];
    for (final b in branches) {
      combinedOverdue.addAll(b.overdueDues);
    }
    combinedOverdue.sort((a, b) => b.age.compareTo(a.age));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Range selectors
          _buildRangeSelector(context),
          
          // Modern Pill Tab selector with track background
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.border.withOpacity(0.5),
              borderRadius: BorderRadius.circular(24),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: false,
              dividerColor: Colors.transparent,
              splashFactory: NoSplash.splashFactory,
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              indicator: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
              padding: EdgeInsets.zero,
              tabs: [
                const Tab(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('All Branches'),
                  ),
                ),
                ...branches.map(
                  (b) => Tab(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(b.branchName),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // All branches view
                _buildBranchesMetricsView(
                  totalInvoices: totalInvoices,
                  totalSales: totalSales,
                  totalReceived: totalReceived,
                  totalDue: totalDue,
                  avgBillValue: avgBillValue,
                  paymentMethods: combinedMethods,
                  staff: combinedStaff,
                  overdue: combinedOverdue,
                  isAll: true,
                  branches: branches,
                ),
                
                // Individual branch views
                ...branches.map((b) {
                  final Map<String, double> pmMap = {};
                  for (final pm in b.paymentMethodBreakdown) {
                    pmMap[pm.method] = pm.amount;
                  }
                  return _buildBranchesMetricsView(
                    totalInvoices: b.totalInvoices,
                    totalSales: b.totalSales,
                    totalReceived: b.totalReceived,
                    totalDue: b.totalDue,
                    avgBillValue: b.avgBillValue,
                    paymentMethods: pmMap,
                    staff: b.staffRanking,
                    overdue: b.overdueDues,
                    isAll: false,
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRangeSelector(BuildContext context) {
    final state = ref.watch(analyticsControllerProvider);
    final ranges = {
      DateRange.today: 'Today',
      DateRange.d7: '7d',
      DateRange.d30: '30d',
      DateRange.month: 'This Month',
      DateRange.all: 'All Time',
    };

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ranges.entries.map((entry) {
                final isSelected = state.range == entry.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(entry.value),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) {
                        ref.read(analyticsControllerProvider.notifier).setRange(entry.key);
                      }
                    },
                    selectedColor: AppColors.primaryLight,
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isSelected ? AppColors.primary : AppColors.border,
                      ),
                    ),
                  ),
                );
              }).toList()..add(
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ActionChip(
                    label: const Text('Custom Range'),
                    onPressed: () => _showCustomDatePicker(context),
                    backgroundColor: state.range == DateRange.custom ? AppColors.primaryLight : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: state.range == DateRange.custom ? AppColors.primary : AppColors.border,
                      ),
                    ),
                    labelStyle: TextStyle(
                      color: state.range == DateRange.custom ? AppColors.primary : AppColors.textSecondary,
                      fontWeight: state.range == DateRange.custom ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                )
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCustomDatePicker(BuildContext context) async {
    final pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 7)),
        end: DateTime.now(),
      ),
    );
    if (pickedRange != null) {
      ref.read(analyticsControllerProvider.notifier).setRange(
            DateRange.custom,
            start: pickedRange.start,
            end: pickedRange.end,
          );
    }
  }

  Widget _buildBranchesMetricsView({
    required int totalInvoices,
    required double totalSales,
    required double totalReceived,
    required double totalDue,
    required double avgBillValue,
    required Map<String, double> paymentMethods,
    required List<StaffRanking> staff,
    required List<OverdueDue> overdue,
    required bool isAll,
    List<BranchAnalytics> branches = const [],
  }) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Stat Cards Grid
        _buildStatCardsGrid(totalInvoices, totalSales, totalReceived, totalDue, avgBillValue),
        const SizedBox(height: 16),
        
        // Payment methods + Staff leaderboard
        _buildProgressAndLeaderboardRow(paymentMethods, staff, showBranch: isAll),
        const SizedBox(height: 16),
        
        // Overdue list
        _buildOverdueSection(overdue),
        
        if (isAll && branches.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildBranchComparisonSection(branches),
        ]
      ],
    );
  }

  Widget _buildStatCardsGrid(int invoices, double sales, double received, double due, double avg) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        _buildStatCard('Invoices', '$invoices', Icons.file_copy_outlined, AppColors.primary),
        _buildStatCard('Sales', _formatINR(sales), Icons.currency_rupee, AppColors.success),
        _buildStatCard('Collected', _formatINR(received), Icons.trending_up, AppColors.info),
        _buildStatCard('Outstanding Due', _formatINR(due), Icons.wallet, AppColors.danger),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return ShadCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
              Icon(icon, size: 16, color: color),
            ],
          ),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildProgressAndLeaderboardRow(
    Map<String, double> paymentMethods,
    List<StaffRanking> staff, {
    required bool showBranch,
  }) {
    final maxAmt = paymentMethods.values.fold(0.0, (m, val) => val > m ? val : m);

    return Column(
      children: [
        ShadCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Payment Methods', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (paymentMethods.isEmpty)
                const Text('No transactions in this period', style: TextStyle(color: AppColors.textSecondary))
              else
                ...paymentMethods.entries.map((e) {
                  final double progress = maxAmt > 0 ? e.value / maxAmt : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _getPaymentMethodIcon(e.key),
                                const SizedBox(width: 8),
                                Text(e.key.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Text(_formatINR(e.value), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: progress,
                          color: AppColors.primary,
                          backgroundColor: AppColors.border,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ShadCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Staff Leaderboard', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (staff.isEmpty)
                const Text('No staff activity in this period', style: TextStyle(color: AppColors.textSecondary))
              else
                ...staff.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final s = entry.value;

                  Color rowBgColor = Colors.transparent;
                  Color rowBorderColor = Colors.transparent;

                  Color rankBgColor = const Color(0xFFE2E8F0); // zinc-200 / AppColors.border
                  Color rankTextColor = const Color(0xFF64748B); // zinc-600 / AppColors.textSecondary

                  if (idx == 0) {
                    rowBgColor = const Color(0xFFFEF3C7); // amber-50
                    rowBorderColor = const Color(0xFFFDE68A); // amber-200
                    rankBgColor = const Color(0xFFF59E0B); // amber-500
                    rankTextColor = Colors.white;
                  } else if (idx == 1) {
                    rowBgColor = const Color(0xFFF1F5F9); // slate/zinc-50 (Slate 100/50 mix)
                    rowBorderColor = const Color(0xFFE2E8F0); // Slate 200
                    rankBgColor = const Color(0xFF94A3B8); // Slate 400
                    rankTextColor = Colors.white;
                  } else if (idx == 2) {
                    rowBgColor = const Color(0xFFFFF7ED); // orange-50
                    rowBorderColor = const Color(0xFFFED7AA); // orange-200
                    rankBgColor = const Color(0xFFEA580C); // orange-600
                    rankTextColor = Colors.white;
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8.0),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: rowBgColor,
                      border: Border.all(color: rowBorderColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        // Rank circle
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: rankBgColor,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${idx + 1}',
                            style: TextStyle(
                              color: rankTextColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Staff Name
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                s.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (showBranch && s.branchName != null)
                                Text(
                                  s.branchName!,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Invoices column
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${s.billCount}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Text(
                              'invoices',
                              style: TextStyle(
                                fontSize: 9,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        // Sales column
                        Container(
                          padding: const EdgeInsets.only(left: 6),
                          margin: const EdgeInsets.only(left: 6),
                          decoration: const BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: AppColors.border,
                                width: 1,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _formatINR(s.totalSales),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Color(0xFF059669), // text-emerald-600
                                ),
                              ),
                              const Text(
                                'sales',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Collected column
                        Container(
                          padding: const EdgeInsets.only(left: 6),
                          margin: const EdgeInsets.only(left: 6),
                          decoration: const BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: AppColors.border,
                                width: 1,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _formatINR(s.collectedAmount),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Color(0xFF0D9488), // text-teal-600
                                ),
                              ),
                              const Text(
                                'collected',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverdueSection(List<OverdueDue> dues) {
    return ShadCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Outstanding Dues', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (dues.isEmpty)
            const Text('All invoices paid. No outstanding dues!', style: TextStyle(color: AppColors.textSecondary))
          else
            Container(
              constraints: const BoxConstraints(maxHeight: 250),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: dues.length,
                separatorBuilder: (c, i) => const Divider(color: AppColors.border),
                itemBuilder: (context, idx) {
                  final d = dues[idx];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${d.billNumber} • ${d.customerName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            Text(d.branchName, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(_formatINR(d.amount), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger, fontSize: 12)),
                            Text('${d.age} days overdue', style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBranchComparisonSection(List<BranchAnalytics> branches) {
    return ShadCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Branch Comparison', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...branches.map((b) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(b.branchName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ShadBadge(label: '${b.totalInvoices} bills', type: BadgeType.primary),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMiniCompare('Sales', _formatINR(b.totalSales), AppColors.success),
                      _buildMiniCompare('Received', _formatINR(b.totalReceived), AppColors.info),
                      _buildMiniCompare('Due', _formatINR(b.totalDue), AppColors.danger),
                    ],
                  ),
                  const Divider(color: AppColors.border),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMiniCompare(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
        Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _getPaymentMethodIcon(String method) {
    final normalized = method.toLowerCase().trim();
    String url;
    IconData fallbackIcon;
    Color fallbackColor;

    if (normalized == 'upi') {
      url = 'https://upload.wikimedia.org/wikipedia/commons/e/e1/UPI-Logo.png';
      fallbackIcon = Icons.qr_code;
      fallbackColor = Colors.blue;
    } else if (normalized == 'cash') {
      url = 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/9b/Money_flat_icon.svg/512px-Money_flat_icon.svg.png';
      fallbackIcon = Icons.money;
      fallbackColor = Colors.green;
    } else if (normalized == 'card') {
      url = 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/46/Debit_card_flat_icon.svg/512px-Debit_card_flat_icon.svg.png';
      fallbackIcon = Icons.credit_card;
      fallbackColor = Colors.orange;
    } else {
      url = 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/87/Bank_flat_icon.svg/512px-Bank_flat_icon.svg.png';
      fallbackIcon = Icons.account_balance;
      fallbackColor = Colors.grey;
    }

    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      child: Image.network(
        url,
        width: 20,
        height: 20,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Icon(fallbackIcon, size: 16, color: fallbackColor),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Icon(fallbackIcon, size: 16, color: fallbackColor);
        },
      ),
    );
  }
}
