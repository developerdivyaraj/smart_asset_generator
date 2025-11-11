import 'dart:convert';
import 'dart:io';

import 'templates/pr_checker_template.dart';

const String _gitlabCiJobSnippet = r'''
pr_checks:
  stage: mr-check
  image: python:3.10
  before_script:
    - pip install requests
  script:
    - python3 .gitlab/pr_checker.py
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
  allow_failure: false
''';

/// ---------- ASSET GENERATOR ----------
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

  final files =
      assetDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => !f.path.endsWith('.DS_Store'))
          .toList();

  for (var file in files) {
    final relativePath = file.path
        .replaceFirst('$directoryPath/', '')
        .replaceAll('\\', '/');
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

/// ---------- BARREL GENERATOR ----------
Future<void> generateBarrelFile({
  required String directoryPath,
  String barrelFileName = 'exports',
}) async {
  final dir = Directory(directoryPath);
  if (!dir.existsSync()) {
    print('❌ Directory does not exist: $directoryPath');
    return;
  }

  final dartFiles =
      dir
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (f) =>
                f.path.endsWith('.dart') &&
                !f.path.endsWith('${barrelFileName.toSnakeCase()}.dart'),
          )
          .toList();

  dartFiles.sort((a, b) => a.path.compareTo(b.path));

  final buffer = StringBuffer();
  for (var file in dartFiles) {
    final relativePath = file.path
        .replaceFirst('$directoryPath/', '')
        .replaceAll('\\', '/');
    buffer.writeln("export '$relativePath';");
  }

  final fileName = '${barrelFileName.toSnakeCase()}.dart';
  final barrelFile = File('$directoryPath/$fileName');
  await barrelFile.writeAsString(buffer.toString());

  print(
    '📦 $directoryPath/$fileName generated with ${dartFiles.length} exports.',
  );
}

/// ---------- MODULE GENERATOR ----------
Future<void> generateModuleFromArgs(List<String> args) async {
  final argsMap = {
    for (var e in args)
      if (e.contains('=')) e.split('=').first: e.split('=').last,
  };

  final name = argsMap['name'];
  final location = argsMap['location'];
  final exportPath = argsMap['export'];

  if (name == null || location == null) {
    print(
      '❌ Missing required arguments.\nUsage:\n'
      'dart run smart_asset_generator module name=home location=lib/modules [export=lib/exports.dart]',
    );
    return;
  }

  await generateModule(
    name: name,
    location: location,
    exportFilePath: exportPath ?? 'lib/exports.dart',
  );
}

Future<void> generateModule({
  required String name,
  required String location,
  required String exportFilePath,
}) async {
  final baseDir = Directory('$location/$name');
  final bindingDir = Directory('${baseDir.path}/bindings');
  final controllerDir = Directory('${baseDir.path}/controller');
  final viewDir = Directory('${baseDir.path}/view');

  await bindingDir.create(recursive: true);
  await controllerDir.create(recursive: true);
  await viewDir.create(recursive: true);

  final snake = name.toSnakeCase();
  final pascal = name.toPascalCase();

  final bindingPath = '$location/$name/bindings/${snake}_binding.dart';
  final controllerPath = '$location/$name/controller/${snake}_controller.dart';
  final viewPath = '$location/$name/view/${snake}_page.dart';

  await File(bindingPath).writeAsString(_bindingTemplate(pascal));
  await File(controllerPath).writeAsString(_controllerTemplate(pascal));
  await File(viewPath).writeAsString(_pageTemplate(pascal));

  final project = getProjectName();
  String stripLib(String path) =>
      path.startsWith('lib/') ? path.substring(4) : path;

  final exportLines = [
    "export 'package:$project/${stripLib(bindingPath)}';",
    "export 'package:$project/${stripLib(controllerPath)}';",
    "export 'package:$project/${stripLib(viewPath)}';",
  ];

  final exportFile = File(exportFilePath);
  final exists = exportFile.existsSync();
  final current = exists ? await exportFile.readAsString() : '';

  final buffer = StringBuffer(current.trim());
  for (final line in exportLines) {
    if (!current.contains(line)) {
      buffer.writeln('\n$line');
    }
  }

  await exportFile.create(recursive: true);
  await exportFile.writeAsString(buffer.toString().trim() + '\n');

  print('✅ Module "$name" created at $location/$name');
  print('📦 Exports added to $exportFilePath');
}

/// ---------- PR CHECKER GENERATOR ----------
Future<void> generateGetxPrChecker({
  String directoryPath = '.gitlab',
  String fileName = 'pr_checker.py',
  String projectLabel = 'GetX Project',
  String gitlabToken = '',
  bool overwrite = false,
}) async {
  final directory = Directory(directoryPath);
  await directory.create(recursive: true);

  final file = File('${directory.path}/$fileName');

  if (file.existsSync() && !overwrite) {
    print(
      '⚠️  ${file.path} already exists. Re-run with overwrite=true to replace the file.',
    );
    return;
  }

  final tokenLiteral = gitlabToken.isEmpty ? 'None' : jsonEncode(gitlabToken);

  final content = getxPrCheckerTemplate
      .replaceAll('{{PROJECT_LABEL}}', projectLabel)
      .replaceAll('{{GITLAB_TOKEN_LITERAL}}', tokenLiteral);

  await file.writeAsString(content);
  await _ensureGitlabCiConfiguration();

  print('✅ ${file.path} ${overwrite ? 'updated' : 'created'}.');
}

/// ---------- HELPERS ----------
Future<void> _ensureGitlabCiConfiguration() async {
  final ciFile = File('.gitlab-ci.yml');

  if (ciFile.existsSync()) {
    var ciContent = await ciFile.readAsString();
    var updated = false;

    final hasMrCheckStage = RegExp(
      r'^\s*-\s*mr-check\s*$',
      multiLine: true,
    ).hasMatch(ciContent);
    if (!hasMrCheckStage) {
      final stagesRegex = RegExp(
        r'stages:\s*\n((?:\s+- .*\n)*)',
        multiLine: true,
      );
      final match = stagesRegex.firstMatch(ciContent);
      if (match != null) {
        final existingBlock = match.group(0)!;
        final insertion =
            existingBlock.endsWith('\n')
                ? '$existingBlock  - mr-check\n'
                : '$existingBlock\n  - mr-check\n';
        ciContent = ciContent.replaceFirst(existingBlock, insertion);
      } else {
        ciContent = 'stages:\n  - mr-check\n\n$ciContent';
      }
      updated = true;
    }

    final hasJob = RegExp(
      r'^\s*pr_checks:\s*$',
      multiLine: true,
    ).hasMatch(ciContent);
    if (!hasJob) {
      if (!ciContent.endsWith('\n')) {
        ciContent += '\n';
      }
      if (!ciContent.endsWith('\n\n')) {
        ciContent += '\n';
      }
      ciContent += '$_gitlabCiJobSnippet\n';
      updated = true;
    }

    if (updated) {
      await ciFile.writeAsString(ciContent);
    }
  } else {
    final ciContent = 'stages:\n  - mr-check\n\n$_gitlabCiJobSnippet\n';
    await ciFile.writeAsString(ciContent);
  }
}

String getProjectName() {
  final pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) return 'your_project';
  final lines = pubspec.readAsLinesSync();
  for (final line in lines) {
    if (line.trim().startsWith('name:')) {
      return line.split(':').last.trim();
    }
  }
  return 'your_project';
}

String _bindingTemplate(String name) {
  final project = getProjectName();
  return '''
import 'package:$project/exports.dart';

class ${name}Binding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ${name}Controller());
  }
}
''';
}

String _controllerTemplate(String name) {
  final project = getProjectName();
  return '''
import 'package:$project/exports.dart';

class ${name}Controller extends GetxController {
  @override
  void onInit() {
    printWrapped("$name Controller initialized");
    super.onInit();
  }
}
''';
}

String _pageTemplate(String name) {
  final project = getProjectName();
  return '''
import 'package:$project/exports.dart';

class ${name}Page extends GetView<${name}Controller> {
  const ${name}Page({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('$name Page')),
      body: const Center(child: Text('Welcome to $name')),
    );
  }
}
''';
}

/// ---------- CASE CONVERSIONS ----------
String _toCamelCase(String input) {
  final sanitized = input.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  final parts = sanitized.split('_');
  return parts.first.toLowerCase() +
      parts
          .skip(1)
          .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
          .join();
}

extension SnakeCaseExtension on String {
  String toSnakeCase() {
    return replaceAllMapped(
      RegExp(r'(?<=[a-z])[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}',
    ).toLowerCase();
  }

  String toPascalCase() {
    return split('_')
        .map((s) => s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : '')
        .join();
  }
}
