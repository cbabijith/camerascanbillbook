import 'package:flutter/material.dart';
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
      views.add(const AnalyticsView());
      tabItems.add(const BottomNavigationBarItem(
        icon: Icon(Icons.bar_chart),
        label: 'Analytics',
      ));
      views.add(const SettingsView());
      tabItems.add(const BottomNavigationBarItem(
        icon: Icon(Icons.settings),
        label: 'Settings',
      ));
    } else {
      views.add(const BillingFormView());
      tabItems.add(const BottomNavigationBarItem(
        icon: Icon(Icons.receipt_long),
        label: 'New Bill',
      ));
    }

    views.addAll([
      const BillsListView(),
      const CustomerListView(),
      const ProductListView(),
    ]);

    tabItems.addAll([
      const BottomNavigationBarItem(
        icon: Icon(Icons.history),
        label: 'Invoices',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.people),
        label: 'Customers',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.shopping_bag),
        label: 'Products',
      ),
    ]);

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
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.danger),
            onPressed: _onLogout,
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: views,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        items: tabItems,
      ),
    );
  }
}
