import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../branches/controllers/branch_controller.dart';
import '../../branches/models/branch.dart';
import '../../../core/theme/app_theme.dart';
import '../../analytics/views/analytics_view.dart';
import '../../bills/views/billing_form_view.dart';
import '../../bills/views/bills_list_view.dart';
import '../../customers/views/customer_list_view.dart';
import '../../products/views/product_list_view.dart';
import '../../settings/views/settings_view.dart';
import '../../auth/views/login_view.dart';

class DashboardLayoutView extends ConsumerStatefulWidget {
  const DashboardLayoutView({super.key});

  @override
  ConsumerState<DashboardLayoutView> createState() => _DashboardLayoutViewState();
}

class _DashboardLayoutViewState extends ConsumerState<DashboardLayoutView> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(branchControllerProvider.notifier).fetchBranches();
    });
  }

  void _onLogout() async {
    await ref.read(authControllerProvider.notifier).logout();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginView()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final branchState = ref.watch(branchControllerProvider);

    if (authState.profile == null) {
      return const LoginView();
    }

    final isAdmin = authState.profile!.isAdmin;

    // Define Views based on Role
    final List<Widget> views = [];
    final List<BottomNavigationBarItem> tabItems = [];

    if (isAdmin) {
      // 1. Analytics
      views.add(const AnalyticsView());
      tabItems.add(const BottomNavigationBarItem(
        icon: Icon(Icons.bar_chart),
        label: 'Analytics',
      ));
      
      // 2. Invoices
      views.add(const BillsListView());
      tabItems.add(const BottomNavigationBarItem(
        icon: Icon(Icons.history),
        label: 'Invoices',
      ));
      
      // 3. Products
      views.add(const ProductListView());
      tabItems.add(const BottomNavigationBarItem(
        icon: Icon(Icons.shopping_bag),
        label: 'Products',
      ));
      
      // 4. Customers
      views.add(const CustomerListView());
      tabItems.add(const BottomNavigationBarItem(
        icon: Icon(Icons.people),
        label: 'Customers',
      ));
      
      // 5. Settings
      views.add(const SettingsView());
      tabItems.add(const BottomNavigationBarItem(
        icon: Icon(Icons.settings),
        label: 'Settings',
      ));
    } else {
      // 1. New Bill
      views.add(const BillingFormView());
      tabItems.add(const BottomNavigationBarItem(
        icon: Icon(Icons.receipt_long),
        label: 'New Bill',
      ));
      
      // 2. Invoices
      views.add(const BillsListView());
      tabItems.add(const BottomNavigationBarItem(
        icon: Icon(Icons.history),
        label: 'Invoices',
      ));
      
      // 3. Products
      views.add(const ProductListView());
      tabItems.add(const BottomNavigationBarItem(
        icon: Icon(Icons.shopping_bag),
        label: 'Products',
      ));
      
      // 4. Customers
      views.add(const CustomerListView());
      tabItems.add(const BottomNavigationBarItem(
        icon: Icon(Icons.people),
        label: 'Customers',
      ));
    }

    // Active Branch details
    final activeBranch = branchState.branches.firstWhere(
      (b) => b.id == branchState.activeBranchId,
      orElse: () => branchState.branches.isNotEmpty
          ? branchState.branches.first
          : Branch(
              id: '',
              name: 'Loading...',
              createdAt: DateTime.now(),
            ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isAdmin ? 'Admin Dashboard' : 'Billing Book',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: AppColors.border, height: 1.0),
        ),
        actions: [
          // Branch selector (Only admins can change, staff view is locked)
          if (isAdmin && branchState.branches.isNotEmpty)
            DropdownButton<String>(
              value: branchState.activeBranchId,
              underline: const SizedBox(),
              icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
              items: branchState.branches.map((b) {
                return DropdownMenuItem<String>(
                  value: b.id,
                  child: Text(
                    b.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  ref.read(branchControllerProvider.notifier).setActiveBranch(val);
                }
              },
            )
          else if (!isAdmin)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Chip(
                label: Text(
                  activeBranch.name,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                backgroundColor: AppColors.primaryLight,
                labelStyle: const TextStyle(color: AppColors.primary),
                side: BorderSide.none,
              ),
            ),
          PopupMenuButton<String>(
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primaryLight,
              child: Text(
                authState.profile!.name.isNotEmpty
                    ? authState.profile!.name[0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            offset: const Offset(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.border, width: 1),
            ),
            elevation: 8,
            color: Colors.white,
            onSelected: (value) {
              if (value == 'logout') {
                _onLogout();
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authState.profile!.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      authState.profile!.username,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    if (authState.profile!.branchName != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          authState.profile!.branchName!,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    const Divider(height: 1, thickness: 1, color: AppColors.border),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: AppColors.danger, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Logout',
                      style: TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: views,
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          height: 66,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 16,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(tabItems.length, (index) {
              final isSelected = _currentIndex == index;
              final item = tabItems[index];
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _currentIndex = index);
                  },
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: TweenAnimationBuilder<Color?>(
                    duration: const Duration(milliseconds: 200),
                    tween: ColorTween(
                      begin: isSelected ? AppColors.textSecondary : AppColors.primary,
                      end: isSelected ? AppColors.primary : AppColors.textSecondary,
                    ),
                    builder: (context, color, child) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primaryLight : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              (item.icon as Icon).icon,
                              color: color,
                              size: 20,
                            ),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              child: isSelected
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(width: 6),
                                        Text(
                                          item.label ?? '',
                                          style: TextStyle(
                                            color: color,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
