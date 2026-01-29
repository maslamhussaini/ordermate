import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  print('Loading .env...');
  await dotenv.load();
  
  final url = dotenv.env['SUPABASE_URL']!;
  final key = dotenv.env['SUPABASE_ANON_KEY']!;
  
  print('Connecting to Supabase: $url');
  
  final supabase = SupabaseClient(url, key);
  
  try {
    print('\n--- Checking Products ---');
    final products = await supabase
        .from('omtbl_products')
        .select('id, name, store_id, organization_id, is_active')
        .limit(5);
        
    print('Found ${products.length} products:');
    for (var p in products) {
      print(p);
    }
  } catch (e) {
    print('Error querying products: $e');
  }

  try {
    print('\n--- Checking Categories ---');
    // Selecting * to see available columns implicitly if it works, or fail if we try specific ones later
    final cats = await supabase
        .from('omtbl_categories')
        .select()
        .limit(1);
    print('Found ${cats.length} categories.');
    if (cats.isNotEmpty) {
      print('Category keys: ${cats.first.keys.toList()}');
    }
  } catch (e) {
    print('Error querying categories: $e');
  }
}
