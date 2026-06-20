import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/auth_controller.dart';
import '../../../core/widgets/custom_widgets.dart';
import '../../../core/theme/app_theme.dart';

class SetupAdminView extends ConsumerStatefulWidget {
  const SetupAdminView({super.key});

  @override
  ConsumerState<SetupAdminView> createState() => _SetupAdminViewState();
}

class _SetupAdminViewState extends ConsumerState<SetupAdminView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _branchNameController = TextEditingController();
  final _branchAddressController = TextEditingController();
  final _branchPhoneController = TextEditingController();
  final _branchGstinController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _branchNameController.dispose();
    _branchAddressController.dispose();
    _branchPhoneController.dispose();
    _branchGstinController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authControllerProvider.notifier).setupFirstAdmin(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          name: _nameController.text.trim(),
          username: _usernameController.text.trim(),
          branchName: _branchNameController.text.trim(),
          branchAddress: _branchAddressController.text.trim().isEmpty
              ? null
              : _branchAddressController.text.trim(),
          branchPhone: _branchPhoneController.text.trim().isEmpty
              ? null
              : _branchPhoneController.text.trim(),
          branchGstin: _branchGstinController.text.trim().isEmpty
              ? null
              : _branchGstinController.text.trim(),
        );

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Admin setup completed successfully. Please sign in.'),
            backgroundColor: AppColors.success,
          ),
        );
        ref.read(authControllerProvider.notifier).checkSetup();
      }
    } else {
      if (mounted) {
        final error = ref.read(authControllerProvider).errorMessage ?? 'Setup failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Initial Software Setup'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Setup Administrator & Branch',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create your master admin login and register your first shop branch.',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'ADMIN DETAILS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ShadCard(
                    child: Column(
                      children: [
                        ShadInput(
                          label: 'Full Name *',
                          hintText: 'John Doe',
                          controller: _nameController,
                          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        ShadInput(
                          label: 'Username *',
                          hintText: 'admin',
                          controller: _usernameController,
                          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        ShadInput(
                          label: 'Email Address *',
                          hintText: 'admin@camerascan.com',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        ShadInput(
                          label: 'Password *',
                          hintText: 'Minimum 6 characters',
                          controller: _passwordController,
                          obscureText: true,
                          validator: (val) => val == null || val.length < 6 ? 'Min 6 chars' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'BRANCH DETAILS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ShadCard(
                    child: Column(
                      children: [
                        ShadInput(
                          label: 'Branch Name *',
                          hintText: 'Camera Scan Main Shop',
                          controller: _branchNameController,
                          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        ShadInput(
                          label: 'Branch Address',
                          hintText: '123 Market Road, City',
                          controller: _branchAddressController,
                        ),
                        const SizedBox(height: 12),
                        ShadInput(
                          label: 'Phone Number',
                          hintText: '+91 9876543210',
                          controller: _branchPhoneController,
                        ),
                        const SizedBox(height: 12),
                        ShadInput(
                          label: 'GSTIN (Optional)',
                          hintText: '29ABCDE1234F1Z5',
                          controller: _branchGstinController,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ShadButton(
                    label: 'Complete Setup',
                    isLoading: state.isLoading,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
