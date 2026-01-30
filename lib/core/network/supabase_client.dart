// lib/core/network/supabase_client.dart

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static SupabaseClient? _client;

  static Future<void> initialize() async {
    // Using simple lookup since we don't know the exact env setup call order in main yet
    // but assuming dotenv.load is called in main.dart

    String url = (dotenv.env['SUPABASE_URL'] ?? '').trim();
    String anonKey = (dotenv.env['SUPABASE_ANON_KEY'] ?? '').trim();

    if (url.isEmpty || url.contains('placeholder')) {
      // Hardcoded fallback for production if env fails - ONLY as a last resort
      // But better to throw to see the error
      debugPrint('SupabaseConfig: URL is empty or placeholder! Check your .env/Environment Variables');
    }

    debugPrint('SupabaseConfig: Initializing with URL: ${url.substring(0, url.length > 20 ? 20 : url.length)}...');

    await Supabase.initialize(
      url: url.isEmpty ? 'https://wbwsikbmnjmhqtlfocus.supabase.co' : url,
      anonKey: anonKey.isEmpty ? 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indid3Npa2JtbmptaHF0bGZvY3VzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ1OTQ0ODUsImV4cCI6MjA4MDE3MDQ4NX0.4WdKl_kwRk0GYi7Y6aOKt1MwOSuhEsf7aJ9cH64XWYs' : anonKey,
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
