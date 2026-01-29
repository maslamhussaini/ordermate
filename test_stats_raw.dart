import 'dart:io';
import 'package:http/http.dart' as http;

Future<void> main() async {
  // Read .env manually
  final envFile = File('.env');
  final lines = await envFile.readAsLines();
  String url = '';
  String key = '';
  
  for (var line in lines) {
    if (line.startsWith('SUPABASE_URL=')) {
      url = line.substring('SUPABASE_URL='.length).trim();
    }
    if (line.startsWith('SUPABASE_ANON_KEY=')) {
      key = line.substring('SUPABASE_ANON_KEY='.length).trim();
    }
  }

  if (url.isEmpty || key.isEmpty) {
    print('Failed to load credentials from .env');
    return;
  }
  
  print('URL: $url');
  final headers = {
    'apikey': key,
    'Authorization': 'Bearer $key',
  };

  print('\n--- Querying Account Categories (omtbl_account_categories) ---');
  try {
     final response = await http.get(
       Uri.parse('$url/rest/v1/omtbl_account_categories?select=*&limit=1'),
       headers: headers,
     );
     print('Status: ${response.statusCode}');
     print('Body: ${response.body}');
  } catch (e) {
    print('Error: $e');
  }
}
