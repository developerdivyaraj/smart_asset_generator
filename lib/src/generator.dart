// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

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
        .replaceAll('\\', '/');
    final fileName = relativePath.split('/').last;
    final varName = _toCamelCase(fileName.replaceAll(RegExp(r'\.\w+$'), ''));
    buffer.writeln("  static const String $varName = '$relativePath';");
  }

  buffer.writeln('}');

  final fileName = '${className.toSnakeCase()}.g.dart';
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

  // Confirm overwrite if any file exists
  final existingFiles = [
    File(bindingPath),
    File(controllerPath),
    File(viewPath),
  ].where((f) => f.existsSync()).toList();

  if (existingFiles.isNotEmpty) {
    stdout.write('⚠️ One or more files already exist. Overwrite? (y/n): ');
    final response = stdin.readLineSync();
    if (response?.toLowerCase() != 'y') {
      print('❌ Aborted module generation.');
      return;
    }
  }

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
  buffer.writeln("\n");
  for (final line in exportLines) {
    if (!current.contains(line)) {
      buffer.writeln(line);
    }
  }

  await exportFile.create(recursive: true);
  await exportFile.writeAsString('${buffer.toString().trim()}\n');

  print('✅ Module "$name" created at $location/$name');
  print('📦 Exports added to $exportFilePath');
}

/// ---------- CLONE GENERATOR ----------
Future<void> cloneProject({
  required String newProjectName,
  required String androidPackage,
  required String iosPackage,
  String? path,
}) async {
  final currentDir = Directory.current;
  final oldProjectName = getProjectName();
  final baseDir = path != null ? Directory(path) : currentDir.parent;

  // ✅ Validate custom path
  if (!await baseDir.exists()) {
    print('❌ Provided path does not exist: ${baseDir.path}');
    return;
  }
  if (!baseDir.statSync().type.toString().contains('directory')) {
    print('❌ Provided path is not a directory: ${baseDir.path}');
    return;
  }

  final newDir = Directory('${baseDir.path}/$newProjectName');

  if (await newDir.exists()) {
    print('❌ Directory already exists: ${newDir.path}');
    return;
  }

  // 1. Copy entire project directory
  await Process.run('cp', ['-R', currentDir.path, newDir.path]);

  // 2. Replace project name in pubspec.yaml
  final pubspecFile = File('${newDir.path}/pubspec.yaml');
  if (await pubspecFile.exists()) {
    final content = await pubspecFile.readAsString();
    final updated = content.replaceFirst('name: $oldProjectName', 'name: $newProjectName');
    await pubspecFile.writeAsString(updated);
  }

  // 3. Replace package imports and project name in all files
  final allFiles = newDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) =>
  !f.path.endsWith('.png') &&
      !f.path.endsWith('.jpg') &&
      !f.path.endsWith('.webp') &&
      !f.path.contains('/.git/') &&
      !f.path.contains('/build/'));

  // 4. Rename and update android/{oldProjectName}_android.iml
  final androidIml = File('${newDir.path}/android/${oldProjectName}_android.iml');
  final newAndroidIml = File('${newDir.path}/android/${newProjectName}_android.iml');

  if (await androidIml.exists()) {
    final content = await androidIml.readAsString();
    final updated = content.replaceAll(oldProjectName, newProjectName);
    await newAndroidIml.writeAsString(updated);
    await androidIml.delete();
  }

  for (final file in allFiles) {
    try {
      final content = await file.readAsString();
      final updated = content
          .replaceAll("package:$oldProjectName/", "package:$newProjectName/")
          .replaceAll("com.example.$oldProjectName", androidPackage)
          .replaceAll(oldProjectName, newProjectName);
      await file.writeAsString(updated);
    } catch (_) {}
  }

  // 5. Rename and update .iml file
  final oldIml = File('${newDir.path}/$oldProjectName.iml');
  final newIml = File('${newDir.path}/$newProjectName.iml');
  if (await oldIml.exists()) {
    final content = await oldIml.readAsString();
    final updated = content.replaceAll(oldProjectName, newProjectName);
    await newIml.writeAsString(updated);
    await oldIml.delete();
  }

  // 6. Update Android package name
  final androidManifest = File('${newDir.path}/android/app/src/main/AndroidManifest.xml');
  final buildGradle = File('${newDir.path}/android/app/build.gradle');
  for (final file in [androidManifest, buildGradle]) {
    if (await file.exists()) {
      var content = await file.readAsString();
      content = content.replaceAll(RegExp(r'package="[^"]+"'), 'package="$androidPackage"');
      content = content.replaceAll(RegExp(r'applicationId "[^"]+"'), 'applicationId "$androidPackage"');
      await file.writeAsString(content);
    }
  }

  // 7. Update iOS bundle identifier
  final iosPlist = File('${newDir.path}/ios/Runner/Info.plist');
  if (await iosPlist.exists()) {
    var content = await iosPlist.readAsString();
    content = content.replaceAllMapped(
      RegExp(r'<key>CFBundleIdentifier</key>\s*<string>.*</string>'),
          (_) => '<key>CFBundleIdentifier</key>\n\t<string>$iosPackage</string>',
    );
    await iosPlist.writeAsString(content);
  }

  // ✅ Done
  print('✅ Project cloned to ${newDir.path}');
  print('📦 Android package: $androidPackage');
  print('📦 iOS bundle ID: $iosPackage');
}

/// ---------- APK GENERATOR & UPLOADER ----------
/// Builds an APK and uploads it to Loadly.
Future<void> generateAndUploadApk({
  required String apiKey,
  bool isRelease = true,
  int buildInstallType = 1,
  String? buildPassword,
  String? buildUpdateDescription,
}) async {
  await generateAndUploadApkToLoadly(
    apiKey: apiKey,
    isRelease: isRelease,
    buildInstallType: buildInstallType,
    buildPassword: buildPassword,
    buildUpdateDescription: buildUpdateDescription,
  );
}

/// ---------- APK GENERATOR & UPLOADER (LOADLY) ----------
Future<LoadlyUploadResult?> generateAndUploadApkToLoadly({
  required String apiKey,
  bool isRelease = true,
  int buildInstallType = 1,
  String? buildPassword,
  String? buildUpdateDescription,
}) async {
  final buildType = isRelease ? 'release' : 'debug';
  print('🚀 Building $buildType APK...');

  final buildResult = await Process.run('flutter', ['build', 'apk', '--$buildType']);
  if (buildResult.exitCode != 0) {
    print('❌ APK build failed:\n${buildResult.stderr}');
    return null;
  }
  print('✅ APK built successfully!');

  // Locate APK
  final apkPath = 'build/app/outputs/flutter-apk/app-$buildType.apk';
  final apk = File(apkPath);
  if (!apk.existsSync()) {
    print('❌ APK not found at $apkPath.');
    return null;
  }

  // Prepare nice filename
  _Metadata metadata = _getAppMetadata();
  final timestamp = DateFormat('dd-MM-yyyy').format(DateTime.now());
  final readableName = '${metadata.name}(v${metadata.version})$timestamp.apk';
  final renamedInBuildDirPath = p.join('build/app/outputs/flutter-apk', readableName);
  final renamedInBuildDir = await apk.copy(renamedInBuildDirPath);
  print('📂 APK saved in build folder: ${renamedInBuildDir.path}');

  print('☁️ Uploading to Loadly...');
  final uploadResult = await uploadToLoadlyWithProgress(
    renamedInBuildDir,
    apiKey: apiKey,
    buildInstallType: buildInstallType,
    buildPassword: buildPassword,
    buildUpdateDescription: buildUpdateDescription,
  );

  if (uploadResult == null) {
    print('❌ Upload to Loadly failed.');
    return null;
  }

  print('✅ Uploaded to Loadly!');
  if (uploadResult.installPageUrl != null) {
    print('🔗 Install Page: ${uploadResult.installPageUrl}');
  }
  if (uploadResult.shortcutUrl != null) {
    print('🔗 Link: https://loadly.io/${uploadResult.shortcutUrl}');
  }
  if (uploadResult.buildKey != null) {
    print('🔑 Build Key: ${uploadResult.buildKey}');
  }
  return uploadResult;
}

/// ---------- IPA GENERATOR & UPLOADER (LOADLY) ----------
Future<LoadlyUploadResult?> generateAndUploadIpaToLoadly({
  required String apiKey,
  int buildInstallType = 1,
  String? buildPassword,
  String? buildUpdateDescription,
}) async {
  if (!Platform.isMacOS) {
    print('❌ IPA build is only supported on macOS.');
    return null;
  }

  print('🚀 Building iOS IPA (release)...');

  final buildResult = await Process.run('flutter', ['build', 'ipa','--export-method', 'ad-hoc',]);
  if (buildResult.exitCode != 0) {
    print('❌ IPA build failed:\n${buildResult.stderr}');
    return null;
  }
  print('✅ IPA built successfully!');

  // Locate IPA
  final ipaDir = Directory('build/ios/ipa');
  if (!ipaDir.existsSync()) {
    print('❌ IPA output directory not found at build/ios/ipa');
    return null;
  }
  final ipaFiles = ipaDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.toLowerCase().endsWith('.ipa'))
      .toList();
  if (ipaFiles.isEmpty) {
    print('❌ No .ipa found in build/ios/ipa');
    return null;
  }
  ipaFiles.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
  final ipa = ipaFiles.last;

  // Prepare nice filename
  _Metadata metadata = _getAppMetadata();
  final timestamp = DateFormat('dd-MM-yyyy').format(DateTime.now());
  final readableName = '${metadata.name}(v${metadata.version})$timestamp.ipa';
  final renamedPath = p.join(ipaDir.path, readableName);
  final renamedIpa = await ipa.copy(renamedPath);
  print('📂 IPA saved in build folder: ${renamedIpa.path}');

  print('☁️ Uploading to Loadly...');
  final uploadResult = await uploadToLoadlyWithProgress(
    renamedIpa,
    apiKey: apiKey,
    buildInstallType: buildInstallType,
    buildPassword: buildPassword,
    buildUpdateDescription: buildUpdateDescription,
  );

  if (uploadResult == null) {
    print('❌ Upload to Loadly failed.');
    return null;
  }

  print('✅ Uploaded to Loadly!');
  if (uploadResult.installPageUrl != null) {
    print('🔗 Install Page: ${uploadResult.installPageUrl}');
  }
  if (uploadResult.shortcutUrl != null) {
    print('🔗 Shortcut: https://loadly.io/${uploadResult.shortcutUrl}');
  }
  if (uploadResult.buildKey != null) {
    print('🔑 Build Key: ${uploadResult.buildKey}');
  }
  return uploadResult;
}

class LoadlyUploadResult {
  final String? buildKey;
  final String? installPageUrl;
  final String? shortcutUrl;

  LoadlyUploadResult({this.buildKey, this.installPageUrl, this.shortcutUrl});
}

/// ---------- PROJECT CONFIG HELPERS ----------
Future<void> ensureProjectConfigFile() async {
  final file = File('smart_asset_generator.yaml');
  if (!file.existsSync()) {
    const defaultContent = '# Smart Asset Generator configuration\n'
        '# Set your Loadly API key here. This is used for apk uploads.\n'
        'loadlyApiKey: ""\n';
    await file.writeAsString(defaultContent);
    print('📝 Created smart_asset_generator.yaml. Please add your Loadly API key.');
  }
}

String? readLoadlyApiKeyFromProjectConfig() {
  final file = File('smart_asset_generator.yaml');
  if (!file.existsSync()) return null;
  try {
    final yamlStr = file.readAsStringSync();
    final doc = loadYaml(yamlStr);
    if (doc is YamlMap) {
      final key = doc['loadlyApiKey']?.toString();
      if (key != null && key.isNotEmpty) return key;
    }
  } catch (_) {}
  return null;
}

Future<void> initProjectConfig({bool overwrite = false}) async {
  final file = File('smart_asset_generator.yaml');
  if (file.existsSync() && !overwrite) {
    print('ℹ️ smart_asset_generator.yaml already exists at ${file.path}');
    return;
  }
  await file.writeAsString(_buildProjectConfigTemplate());
  print('✅ Created smart_asset_generator.yaml with commands and empty Loadly API key.');
}

String _buildProjectConfigTemplate() {
  return '# Smart Asset Generator configuration\n'
      '# Provide your Loadly API key below or use the config command to set it.\n'
      'loadlyApiKey: ""\n'
      '\n'
      '# Helpful commands you can run:\n'
      'commands without parameters:\n'
      '  - dart run smart_asset_generator asset \n'
      '  - dart run smart_asset_generator barrel \n'
      '  - dart run smart_asset_generator module name=login location=lib/modules/auth/login \n'
      '  - dart run smart_asset_generator apk \n'
      '  - dart run smart_asset_generator ipa \n'
      '  - dart run smart_asset_generator apps \n'
      '  - dart run smart_asset_generator init\n'

      'commands with parameters:\n'
      '  - dart run smart_asset_generator asset <asset_path> [class_name]\n'
      '  - dart run smart_asset_generator barrel <directory_path> [output_file_name]\n'
      '  - dart run smart_asset_generator module name=<module_name> location=<path> [export=<barrel_file_path>]\n'
      '  - dart run smart_asset_generator clone name=<new_project_name> android=<android_package> ios=<ios_package> [path=<directory_path>]\n'
      '  - dart run smart_asset_generator apk [release|debug] [apiKey=<YOUR_API_KEY>] [buildInstallType=1|2|3] [buildPassword=<pwd>] [desc=<notes>]\n'
      '  - dart run smart_asset_generator ipa [apiKey=<YOUR_API_KEY>] [buildInstallType=1|2|3] [buildPassword=<pwd>] [desc=<notes>]'
      '  - dart run smart_asset_generator apps [release|debug] [apiKey=<YOUR_API_KEY>] [buildInstallType=1|2|3] [buildPassword=<pwd>] [desc=<notes>]'
      '  - dart run smart_asset_generator init\n';
}

Future<void> setLoadlyApiKey({
  required String key,
}) async {
  final file = File('smart_asset_generator.yaml');
  if (!file.existsSync()) {
    const header = '# Smart Asset Generator configuration\n'
        '# Set your Loadly API key here. This is used for apk uploads.\n';
    await file.writeAsString('${header}loadlyApiKey: "$key"\n');
  } else {
    await _upsertYamlKey(file, 'loadlyApiKey', key);
  }
  print('✅ Saved Loadly API key to ${file.path}');
}

Future<void> _upsertYamlKey(File file, String yamlKey, String value) async {
  final exists = file.existsSync();
  String content = exists ? await file.readAsString() : '';
  if (content.trim().isEmpty) {
    await file.writeAsString('$yamlKey: "$value"\n');
    return;
  }
  final lines = content.split('\n');
  bool updated = false;
  final newLines = <String>[];
  for (final line in lines) {
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('$yamlKey:')) {
      final indentLength = line.length - trimmed.length;
      final indent = indentLength > 0 ? line.substring(0, indentLength) : '';
      newLines.add('$indent$yamlKey: "$value"');
      updated = true;
    } else {
      newLines.add(line);
    }
  }
  if (!updated) newLines.add('$yamlKey: "$value"');
  await file.writeAsString(newLines.join('\n'));
}

Future<LoadlyUploadResult?> uploadToLoadlyWithProgress(
  File file, {
  required String apiKey,
  int buildInstallType = 1,
  String? buildPassword,
  String? buildUpdateDescription,
}) async {
  final uri = Uri.parse('https://api.loadly.io/apiv2/app/upload');

  final request = http.MultipartRequest('POST', uri);
  request.fields['_api_key'] = apiKey;
  request.fields['buildInstallType'] = buildInstallType.toString();
  if (buildPassword != null && buildPassword.isNotEmpty) {
    request.fields['buildPassword'] = buildPassword;
  }
  if (buildUpdateDescription != null && buildUpdateDescription.isNotEmpty) {
    request.fields['buildUpdateDescription'] = buildUpdateDescription;
  }

  final totalBytes = file.lengthSync();
  var uploadedBytes = 0;

  final stream = file.openRead().transform<List<int>>(
    StreamTransformer.fromHandlers(
      handleData: (data, sink) {
        uploadedBytes += data.length;
        final progress = (uploadedBytes / totalBytes * 100).toStringAsFixed(1);
        stdout.write('\r⬆️ Uploading... $progress%');
        sink.add(data);
      },
      handleError: (error, stackTrace, sink) {
        sink.addError(error, stackTrace);
      },
      handleDone: (sink) {
        sink.close();
      },
    ),
  );

  final multipartFile = http.MultipartFile(
    'file',
    stream,
    totalBytes,
    filename: p.basename(file.path),
  );

  request.files.add(multipartFile);

  try {
    final response = await request.send().timeout(const Duration(minutes: 10));
    stdout.writeln();

    final respStr = await response.stream.bytesToString();
    if (response.statusCode != 200) {
      print('❌ Loadly upload failed with status: ${response.statusCode}\n$respStr');
      return null;
    }

    final data = jsonDecode(respStr);
    // Attempt to extract common fields
    dynamic payload = data['data'] ?? data;
    final buildKey = payload['buildKey']?.toString();
    final installPageUrl = payload['buildURL']?.toString() ?? payload['downloadURL']?.toString();
    final shortcutUrl = payload['buildShortcutUrl']?.toString();
    return LoadlyUploadResult(
      buildKey: buildKey,
      installPageUrl: installPageUrl,
      shortcutUrl: shortcutUrl,
    );
  } on TimeoutException {
    stdout.writeln();
    print('❌ Loadly upload timed out.');
    return null;
  } catch (e) {
    stdout.writeln();
    print('❌ Loadly upload error: $e');
    return null;
  }
}


class _Metadata {
  final String name;
  final String version;
  _Metadata(this.name, this.version);
}

_Metadata _getAppMetadata() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final yaml = loadYaml(pubspec);
  final name = yaml['name'] ?? 'app';
  final version = yaml['version'] ?? '1.0.0';
  return _Metadata(name, version);
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
import 'package:$project/$project.dart';

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
import 'package:$project/$project.dart';

class ${name}Controller extends GetxController {
  @override
  void onInit() {
    print("$name Controller initialized");
    super.onInit();
  }
}
''';
}

String _pageTemplate(String name) {
  final project = getProjectName();
  return '''
import 'package:$project/$project.dart';

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
