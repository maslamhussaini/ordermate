// ignore_for_file: avoid_print
import 'package:ordermate/core/database/database_helper.dart';

void main() async {
  final db = await DatabaseHelper.instance.database;

  print('--- Products Store Distribution ---');
  final productsDist = await db.rawQuery(
      'SELECT store_id, COUNT(*) as count FROM local_products GROUP BY store_id');
  for (var row in productsDist) {
    print('Store ID: ${row['store_id']} | Count: ${row['count']}');
  }

  print('\n--- Business Partners Store Distribution ---');
  final partnersDist = await db.rawQuery(
      'SELECT store_id, COUNT(*) as count FROM local_businesspartners GROUP BY store_id');
  for (var row in partnersDist) {
    print('Store ID: ${row['store_id']} | Count: ${row['count']}');
  }

  print('\n--- Stores List ---');
  final stores = await db.query('local_stores');
  for (var s in stores) {
    print('Store: ${s['id']} - ${s['name']}');
  }
}
