// lib/core/network/supabase_client.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static SupabaseClient? _client;

  static const String _prodUrl = 'https://wbwsikbmnjmhqtlfocus.supabase.co';
  static const String _prodKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indid3Npa2JtbmptaHF0bGZvY3VzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ1OTQ0ODUsImV4cCI6MjA4MDE3MDQ4NX0.4WdKl_kwRk0GYi7Y6aOKt1MwOSuhEsf7aJ9cH64XWYs';

  static Future<void> initialize() async {
    String url = (dotenv.env['SUPABASE_URL'] ?? '').trim();
    String anonKey = (dotenv.env['SUPABASE_ANON_KEY'] ?? '').trim();

    // If environment variables are missing OR they contain the "placeholder" text
    if (url.isEmpty || url.contains('placeholder')) {
      debugPrint('SupabaseConfig: Using hardcoded production URL (Environment Variable missing)');
      url = _prodUrl;
    }
    
    if (anonKey.isEmpty || anonKey.contains('placeholder')) {
      debugPrint('SupabaseConfig: Using hardcoded production Key (Environment Variable missing)');
      anonKey = _prodKey;
    }

    debugPrint('SupabaseConfig: Initializing Supabase client...');

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
