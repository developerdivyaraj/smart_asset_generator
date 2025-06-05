import 'dart:io';

Future<void> generateAssets({
  required String directoryPath,
  String className = 'AppAssets',
}) async {
  final assetDir = Directory(directoryPath);

  if (!assetDir.existsSync()) {
    print('❌ Directory does not exist: $directoryPath');
    return;
  }

  final buffer = StringBuffer();
  buffer.writeln('/// Auto-generated. Do not modify by hand.');
  buffer.writeln('class $className {\n  $className._();\n');

  final files = assetDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => !f.path.endsWith('.DS_Store'))
      .toList();

  for (var file in files) {
    final relativePath = file.path.replaceFirst('$directoryPath/', '').replaceAll('\\', '/');
    final fileName = relativePath.split('/').last;
    final varName = _toCamelCase(fileName.replaceAll(RegExp(r'\.\w+$'), ''));

    buffer.writeln("  static const String $varName = '$relativePath';");
  }

  buffer.writeln('}');

  final fileName = '${className.toSnakeCase()}.dart';
  final outputFile = File('lib/generated/$fileName');
  await outputFile.create(recursive: true);
  await outputFile.writeAsString(buffer.toString());

  print('✅ lib/generated/$fileName generated with ${files.length} assets.');
}

Future<void> generateBarrelFile({
  required String directoryPath,
  String barrelFileName = 'index',
}) async {
  final dir = Directory(directoryPath);

  if (!dir.existsSync()) {
    print('❌ Directory does not exist: $directoryPath');
    return;
  }

  final dartFiles = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) =>
  f.path.endsWith('.dart') &&
      !f.path.endsWith('${barrelFileName.toSnakeCase()}.dart'))
      .toList();

  dartFiles.sort((a, b) => a.path.compareTo(b.path));

  final buffer = StringBuffer();

  for (var file in dartFiles) {
    final relativePath = file.path.replaceFirst('$directoryPath/', '').replaceAll('\\', '/');
    buffer.writeln("export '$relativePath';");
  }

  final fileName = '${barrelFileName.toSnakeCase()}.dart';
  final barrelFile = File('$directoryPath/$fileName');
  await barrelFile.writeAsString(buffer.toString());

  print('📦 $directoryPath/$fileName generated with ${dartFiles.length} exports.');
}

String _toCamelCase(String input) {
  final sanitized = input.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  final parts = sanitized.split('_');
  return parts.first.toLowerCase() +
      parts.skip(1).map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1)).join();
}

extension SnakeCaseExtension on String {
  String toSnakeCase() {
    return replaceAllMapped(
      RegExp(r'(?<=[a-z])[A-Z]'),
          (match) => '_${match.group(0)!.toLowerCase()}',
    ).toLowerCase();
  }
}
