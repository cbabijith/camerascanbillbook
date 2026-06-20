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
    final isEdit = branch != null;
    final nameCtrl = TextEditingController(text: isEdit ? branch.name : '');
    final addrCtrl = TextEditingController(text: isEdit ? branch.address ?? '' : '');
    final phoneCtrl = TextEditingController(text: isEdit ? branch.phone ?? '' : '');
    final gstinCtrl = TextEditingController(text: isEdit ? branch.gstin ?? '' : '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
            onPressed: () => Navigator.of(context).pop(),
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

              if (mounted) {
                Navigator.of(context).pop();
                if (!success) {
                  final err = ref.read(branchControllerProvider).errorMessage ?? 'An error occurred';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(err), backgroundColor: AppColors.danger),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
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
    final nameCtrl = TextEditingController();
    final usernameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String? selectedBranchId;
    final formKey = GlobalKey<FormState>();
    bool showPassword = false;

    showDialog(
      context: context,
      builder: (context) {
        final branches = ref.watch(branchControllerProvider).branches;
        return StatefulBuilder(
          builder: (context, setState) {
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
                        value: selectedBranchId,
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
                  onPressed: () => Navigator.of(context).pop(),
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

                    Navigator.of(context).pop();

                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(content: Text('Creating staff account...'), duration: Duration(seconds: 1)),
                    );

                    final success = await ref.read(settingsControllerProvider.notifier).createStaff(
                          email: email,
                          password: password,
                          name: name,
                          username: username,
                          branchId: branchId,
                        );

                    if (this.mounted) {
                      if (!success) {
                        final err = ref.read(settingsControllerProvider).errorMessage ?? 'Failed to create staff account';
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(content: Text(err), backgroundColor: AppColors.danger),
                        );
                      } else {
                        ScaffoldMessenger.of(this.context).showSnackBar(
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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(icon: Icon(Icons.store), text: 'Branches'),
              Tab(icon: Icon(Icons.people), text: 'Staff Management'),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBranchesTab(branchState),
          _buildStaffTab(settingsState),
        ],
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
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Shop Branches', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                icon: const Icon(Icons.add, color: Colors.white, size: 18),
                label: const Text('Add Branch', style: TextStyle(color: Colors.white)),
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
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(branch.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (branch.address != null) Text('Address: ${branch.address}'),
                            if (branch.phone != null) Text('Phone: ${branch.phone}'),
                            if (branch.gstin != null) Text('GSTIN: ${branch.gstin}'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: AppColors.primary),
                              onPressed: () => _showAddOrEditBranchDialog(branch),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: AppColors.danger),
                              onPressed: () => _deleteBranch(branch),
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

  Widget _buildStaffTab(SettingsState settingsState) {
    if (settingsState.isLoading && settingsState.staff.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Staff Accounts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                icon: const Icon(Icons.add, color: Colors.white, size: 18),
                label: const Text('Add Staff', style: TextStyle(color: Colors.white)),
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
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(member.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Username: @${member.username}'),
                            Text('Assigned Branch: ${member.branchName ?? "Loading..."}'),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: AppColors.danger),
                          onPressed: () => _deleteStaff(member),
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
