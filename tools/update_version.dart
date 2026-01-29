// ignore_for_file: avoid_print
import 'dart:io';

void main(List<String> args) async {
  final buildInfoFile = File('lib/build_info.dart');
  final pubspecFile = File('pubspec.yaml');

  if (!buildInfoFile.existsSync() || !pubspecFile.existsSync()) {
    print('Error: lib/build_info.dart or pubspec.yaml not found.');
    exit(1);
  }

  // 1. Read & Update pubspec.yaml
  String pubspecContent = await pubspecFile.readAsString();
  final versionRegex = RegExp(r'version: (\d+)\.(\d+)\.(\d+)\+(\d+)');
  final match = versionRegex.firstMatch(pubspecContent);

  String newVersion = '1.0.0';
  String versionString = '1.0.0';

  if (match != null) {
    int major = int.parse(match.group(1)!);
    int minor = int.parse(match.group(2)!);
    int patch = int.parse(match.group(3)!);
    int build = int.parse(match.group(4)!);

    // Increment build number (always)
    build++;

    // Determine type of increment based on args
    if (args.contains('major')) {
      // New feature or screen (2.0, 3.0)
      major++;
      minor = 0;
      patch = 0;
      print('Performing MAJOR version increment.');
    } else if (args.contains('minor')) {
      // Bugs free / Fixes (1.1, 1.2)
      minor++;
      patch = 0;
      print('Performing MINOR version increment.');
    } else {
      // Default: Patch increment (Safest default, or use 'patch' arg)
      patch++;
      print('Performing PATCH version increment (default). Use "major" or "minor" args for other updates.');
    }

    newVersion = '$major.$minor.$patch+$build';
    versionString = '$major.$minor.$patch';
    
    pubspecContent = pubspecContent.replaceFirst(versionRegex, 'version: $newVersion');
    await pubspecFile.writeAsString(pubspecContent);
    print('Updated pubspec.yaml version to $newVersion');
  } else {
    print('Warning: Could not find version in pubspec.yaml');
  }

  // 2. Update lib/build_info.dart
  String content = await buildInfoFile.readAsString();
  final now = DateTime.now();
  final formattedDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

  // Update buildTime
  final buildTimeRegex = RegExp(r"const String buildTime = '([^']*)';");
  if (buildTimeRegex.hasMatch(content)) {
    content = content.replaceFirst(buildTimeRegex, "const String buildTime = '$formattedDate';");
  }

  // Update appVersion
  final appVersionRegex = RegExp(r"const String appVersion = '([^']*)';");
  if (appVersionRegex.hasMatch(content)) {
    content = content.replaceFirst(appVersionRegex, "const String appVersion = '$versionString';");
    print('Updated build_info.dart appVersion to $versionString');
  }

  await buildInfoFile.writeAsString(content);
  print('Successfully updated lib/build_info.dart with buildTime $formattedDate');
}

