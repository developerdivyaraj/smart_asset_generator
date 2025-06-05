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
  buffer.writeln('/// Auto-generated. Do not modify by hand.\nclass $className {\n  $className._();\n');

  final files = assetDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => !f.path.endsWith('.DS_Store'))
      .toList();

  for (var file in files) {
    final relativePath = file.path.replaceAll('\\', '/');
    final fileName = relativePath.split('/').last;
    final varName = _toCamelCase(fileName.replaceAll(RegExp(r'\.\w+$'), ''));

    buffer.writeln("  static const String $varName = '$relativePath';");
  }

  buffer.writeln('}');

  final outputFile = File('lib/generated/$className.dart');
  await outputFile.create(recursive: true);
  await outputFile.writeAsString(buffer.toString());

  print('✅ $className.dart generated with ${files.length} assets.');
}

String _toCamelCase(String input) {
  final parts = input.split('_');
  return parts.first + parts.skip(1).map((w) => w[0].toUpperCase() + w.substring(1)).join();
}
