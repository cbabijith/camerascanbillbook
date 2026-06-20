import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../branches/controllers/branch_controller.dart';
import '../../branches/models/branch.dart';
import '../controllers/settings_controller.dart';
import '../../auth/models/profile.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/custom_widgets.dart';

class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> with TickerProviderStateMixin {
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() {
      ref.read(branchControllerProvider.notifier).fetchBranches();
      ref.read(settingsControllerProvider.notifier).fetchStaff();
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _showAddOrEditBranchDialog([Branch? branch]) {
    final parentContext = context;
    final isEdit = branch != null;
    final nameCtrl = TextEditingController(text: isEdit ? branch.name : '');
    final addrCtrl = TextEditingController(text: isEdit ? branch.address ?? '' : '');
    final phoneCtrl = TextEditingController(text: isEdit ? branch.phone ?? '' : '');
    final gstinCtrl = TextEditingController(text: isEdit ? branch.gstin ?? '' : '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(isEdit ? 'Edit Branch' : 'Add Shop Branch'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShadInput(
                  label: 'Branch Name *',
                  controller: nameCtrl,
                  validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                ShadInput(
                  label: 'Address',
                  controller: addrCtrl,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ShadInput(
                        label: 'Phone Number',
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ShadInput(
                        label: 'GSTIN (Optional)',
                        controller: gstinCtrl,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final name = nameCtrl.text.trim();
              final address = addrCtrl.text.trim().isEmpty ? null : addrCtrl.text.trim();
              final phone = phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim();
              final gstin = gstinCtrl.text.trim().isEmpty ? null : gstinCtrl.text.trim();

              bool success;
              if (isEdit) {
                success = await ref.read(branchControllerProvider.notifier).updateBranch(
                      branch.id,
                      name: name,
                      address: address,
                      phone: phone,
                      gstin: gstin,
                    );
              } else {
                success = await ref.read(branchControllerProvider.notifier).createBranch(
                      name: name,
                      address: address,
                      phone: phone,
                      gstin: gstin,
                    );
              }

              if (parentContext.mounted) {
                Navigator.of(dialogContext).pop();
                if (!success) {
                  final err = ref.read(branchControllerProvider).errorMessage ?? 'An error occurred';
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(content: Text(err), backgroundColor: AppColors.danger),
                  );
                } else {
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(
                      content: Text(isEdit ? 'Branch updated successfully' : 'Branch created successfully'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              }
            },
            child: Text(isEdit ? 'Save Changes' : 'Create Branch', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _deleteBranch(Branch branch) async {
    final branchState = ref.read(branchControllerProvider);
    if (branchState.branches.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least one branch must remain in the system.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Branch'),
        content: const Text('Warning: Deleting a branch will delete all related products, customers, and invoices! Proceed?'),
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

    if (confirm == true && mounted) {
      final success = await ref.read(branchControllerProvider.notifier).deleteBranch(branch.id);
      if (mounted) {
        if (!success) {
          final err = ref.read(branchControllerProvider).errorMessage ?? 'Failed to delete branch';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err), backgroundColor: AppColors.danger),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Branch deleted successfully'), backgroundColor: AppColors.success),
          );
        }
      }
    }
  }

  void _showAddStaffDialog() {
    final parentContext = context;
    final nameCtrl = TextEditingController();
    final usernameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String? selectedBranchId;
    final formKey = GlobalKey<FormState>();
    bool showPassword = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        final branches = ref.watch(branchControllerProvider).branches;
        return StatefulBuilder(
          builder: (stateContext, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text('Create Staff Account'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ShadInput(
                        label: 'Display Name *',
                        controller: nameCtrl,
                        validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      ShadInput(
                        label: 'Username *',
                        controller: usernameCtrl,
                        validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      ShadInput(
                        label: 'Auth Email Address *',
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      ShadInput(
                        label: 'Password *',
                        controller: passCtrl,
                        obscureText: !showPassword,
                        validator: (val) => val == null || val.length < 6 ? 'Min 6 characters' : null,
                        suffixIcon: IconButton(
                          icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => showPassword = !showPassword),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Assigned Branch *',
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        initialValue: selectedBranchId,
                        validator: (val) => val == null ? 'Required' : null,
                        items: branches.map((b) {
                          return DropdownMenuItem<String>(
                            value: b.id,
                            child: Text(b.name),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => selectedBranchId = val),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: () async {
                    if (!formKey.currentState!.validate() || selectedBranchId == null) return;

                    final name = nameCtrl.text.trim();
                    final username = usernameCtrl.text.trim();
                    final email = emailCtrl.text.trim();
                    final password = passCtrl.text;
                    final branchId = selectedBranchId!;

                    Navigator.of(dialogContext).pop();

                    if (parentContext.mounted) {
                      ScaffoldMessenger.of(parentContext).showSnackBar(
                        const SnackBar(content: Text('Creating staff account...'), duration: Duration(seconds: 1)),
                      );
                    }

                    final success = await ref.read(settingsControllerProvider.notifier).createStaff(
                          email: email,
                          password: password,
                          name: name,
                          username: username,
                          branchId: branchId,
                        );

                    if (parentContext.mounted) {
                      if (!success) {
                        final err = ref.read(settingsControllerProvider).errorMessage ?? 'Failed to create staff account';
                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          SnackBar(content: Text(err), backgroundColor: AppColors.danger),
                        );
                      } else {
                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          const SnackBar(content: Text('Staff account created successfully'), backgroundColor: AppColors.success),
                        );
                      }
                    }
                  },
                  child: const Text('Create Account', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteStaff(Profile member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Staff Account'),
        content: Text('Are you sure you want to delete ${member.name}? They will lose access to the system.'),
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

    if (confirm == true && mounted) {
      final success = await ref.read(settingsControllerProvider.notifier).deleteStaff(member.id);
      if (mounted) {
        if (!success) {
          final err = ref.read(settingsControllerProvider).errorMessage ?? 'Failed to delete staff account';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err), backgroundColor: AppColors.danger),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Staff account deleted successfully'), backgroundColor: AppColors.success),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final branchState = ref.watch(branchControllerProvider);
    final settingsState = ref.watch(settingsControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Modern Pill Tab selector with track background
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.border.withValues(alpha: 0.5),
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
                      color: AppColors.primary.withValues(alpha: 0.15),
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
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.store, size: 16),
                        SizedBox(width: 6),
                        Text('Branches'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people, size: 16),
                        SizedBox(width: 6),
                        Text('Staff Accounts'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildBranchesTab(branchState),
                  _buildStaffTab(settingsState),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBranchesTab(BranchState branchState) {
    if (branchState.isLoading && branchState.branches.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Shop Branches', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                icon: const Icon(Icons.add, color: Colors.white, size: 18),
                label: const Text('Add Branch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: () => _showAddOrEditBranchDialog(),
              ),
            ],
          ),
        ),
        Expanded(
          child: branchState.branches.isEmpty
              ? const Center(child: Text('No branches found', style: TextStyle(color: AppColors.textSecondary)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: branchState.branches.length,
                  itemBuilder: (context, index) {
                    final branch = branchState.branches[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ShadCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.store, color: AppColors.primary, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    branch.name,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, color: AppColors.textSecondary, size: 20),
                                  onPressed: () => _showAddOrEditBranchDialog(branch),
                                  tooltip: 'Edit Branch',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                                  onPressed: () => _deleteBranch(branch),
                                  tooltip: 'Delete Branch',
                                ),
                              ],
                            ),
                            if (branch.address != null || branch.phone != null || branch.gstin != null) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Divider(color: AppColors.border, height: 1),
                              ),
                              if (branch.address != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.location_on_outlined, color: AppColors.textSecondary, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          branch.address!,
                                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (branch.phone != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.phone_outlined, color: AppColors.textSecondary, size: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                        branch.phone!,
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                              if (branch.gstin != null)
                                Row(
                                  children: [
                                    const Icon(Icons.receipt_outlined, color: AppColors.textSecondary, size: 16),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'GSTIN: ',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                                    ),
                                    ShadBadge(
                                      label: branch.gstin!,
                                      type: BadgeType.info,
                                    ),
                                  ],
                                ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStaffTab(SettingsState settingsState) {
    if (settingsState.isLoading && settingsState.staff.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Staff Accounts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                icon: const Icon(Icons.add, color: Colors.white, size: 18),
                label: const Text('Add Staff', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: _showAddStaffDialog,
              ),
            ],
          ),
        ),
        Expanded(
          child: settingsState.staff.isEmpty
              ? const Center(child: Text('No staff accounts found', style: TextStyle(color: AppColors.textSecondary)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: settingsState.staff.length,
                  itemBuilder: (context, index) {
                    final member = settingsState.staff[index];
                    final initials = member.name.trim().isNotEmpty
                        ? member.name.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
                        : 'S';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ShadCard(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.primaryLight,
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    member.name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '@${member.username}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.store, size: 12, color: AppColors.textMuted),
                                      const SizedBox(width: 4),
                                      Text(
                                        member.branchName ?? 'Loading...',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                              onPressed: () => _deleteStaff(member),
                              tooltip: 'Delete Staff Account',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
