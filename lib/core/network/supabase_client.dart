// lib/core/network/supabase_client.dart

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static SupabaseClient? _client;

  static Future<void> initialize() async {
    // Using simple lookup since we don't know the exact env setup call order in main yet
    // but assuming dotenv.load is called in main.dart

    final url = dotenv.env['SUPABASE_URL'] ?? 'https://placeholder.supabase.co';
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? 'placeholder';

    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );

    _client = Supabase.instance.client;
  }

  static SupabaseClient get client {
    if (_client == null) {
      // Fallback if accessed before init (shouldn't happen in configured app)
      return Supabase.instance.client;
    }
    return _client!;
  }

  static User? get currentUser => client.auth.currentUser;

  static String? get currentUserId => currentUser?.id ?? (isOfflineLoggedIn ? 'test-user-id' : null);

  /// Flag to indicate if user is logged in via offline mode (bypassing Supabase session check)
  static bool isOfflineLoggedIn = false;
}
