import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class CsvService {
  /// Generates a CSV string from a list of rows (list of lists)
  String generateCsv(List<List<dynamic>> rows) {
    return const ListToCsvConverter().convert(rows);
  }

  /// Parses a CSV string into a list of rows
  List<List<dynamic>> parseCsv(String csvContent) {
    // Detect EOL
    String? eol;
    if (csvContent.contains('\r\n')) {
      eol = '\r\n';
    } else if (csvContent.contains('\n')) {
      eol = '\n';
    } else if (csvContent.contains('\r')) {
      eol = '\r';
    }
    
    // Use detected EOL or default
    return const CsvToListConverter().convert(csvContent, eol: eol);
  }

  /// Prompts the user to pick a CSV file and returns the content as a string.
  /// Returns null if user cancels.
  Future<List<List<dynamic>>?> pickAndParseCsv() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true, // Needed for Web, but helpful to ensure bytes are available
      );

      if (result == null || result.files.isEmpty) return null;

      final file = result.files.first;
      
      String content;
      if (file.bytes != null) {
        content = const Utf8Decoder().convert(file.bytes!);
      } else if (file.path != null) {
        final f = File(file.path!);
        content = await f.readAsString();
      } else {
        return null;
      }

      return parseCsv(content);
    } catch (e) {
      debugPrint('Error picking/parsing CSV: $e');
      rethrow;
    }
  }

  /// Saves a CSV file.
  /// On Desktop, prompts for location.
  /// On Mobile, simply saves to App Documents or Downloads (requires permission logic usually, 
  /// but for now we'll basic save).
  Future<String?> saveCsvFile(String fileName, List<List<dynamic>> rows) async {
    final csvContent = generateCsv(rows);
    
    // Desktop: Save Dialog
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      final outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save CSV Template',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsString(csvContent);
        return outputFile;
      }
      return null;
    } 
    
    // Mobile (Simplified for now - strictly responding to User's Windows Context)
    // Fallback or todo for mobile specific directory handling
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/$fileName';
    final file = File(path);
    await file.writeAsString(csvContent);
    return path;
    
  }
}
