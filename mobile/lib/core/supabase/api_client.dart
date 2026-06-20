import 'package:supabase_flutter/supabase_flutter.dart';

/// Helper to get the global Supabase client instance.
SupabaseClient get supabase => Supabase.instance.client;
