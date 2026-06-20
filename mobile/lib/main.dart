import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/supabase/config.dart';
import 'features/auth/views/login_view.dart';

import 'features/auth/controllers/auth_controller.dart';
import 'features/dashboard/views/dashboard_layout_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return MaterialApp(
      title: 'Camera Scan Bill Book',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: authState.isLoading && authState.profile == null
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : (authState.profile != null
              ? const DashboardLayoutView()
              : const LoginView()),
    );
  }
}
