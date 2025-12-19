// ignore_for_file: avoid_print

import 'package:smart_asset_generator/smart_asset_generator.dart';

enum Command {
  clone,
  asset,
  barrel,
  module,
  prchecker,
  apk,
  ipa,
  apps,
  config,
  init,
}

Command? parseCommand(String value) {
  switch (value.toLowerCase()) {
    case 'clone':
      return Command.clone;
    case 'asset':
      return Command.asset;
    case 'barrel':
      return Command.barrel;
    case 'module':
      return Command.module;
    case 'prchecker':
      return Command.prchecker;
    case 'apk':
      return Command.apk;
    case 'ipa':
      return Command.ipa;
    case 'apps':
      return Command.apps;
    case 'config':
      return Command.config;
    case 'init':
      return Command.init;
    default:
      return null;
  }
}

enum BuildMode { release, debug }

BuildMode parseBuildMode(Iterable<String> args) {
  return args.any((e) => e.toLowerCase() == 'debug')
      ? BuildMode.debug
      : BuildMode.release;
}

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    _printUsage();
    return;
  }

  final command = parseCommand(args.first);
  if (command == null) {
    print('❌ Unknown command: ${args.first}');
    _printUsage();
    return;
  }

  final rest = args.skip(1).toList();

  switch (command) {
    case Command.clone:
      await _handleClone(rest);
      break;
    case Command.asset:
      await _handleAsset(rest);
      break;
    case Command.barrel:
      await _handleBarrel(rest);
      break;
    case Command.module:
      await generateModuleFromArgs(rest);
      break;
    case Command.prchecker:
      await _handlePrChecker(rest);
      break;
    case Command.apk:
      await _handleApk(rest);
      break;
    case Command.ipa:
      await _handleIpa(rest);
      break;
    case Command.apps:
      await _handleApps(rest);
      break;
    case Command.config:
      await _handleConfig(rest);
      break;
    case Command.init:
      final overwrite = rest.any((e) => e == '--overwrite');
      await initProjectConfig(overwrite: overwrite);
      break;
  }
}

Future<void> _handleClone(List<String> args) async {
  final argsMap = _parseKeyValueArgs(args);
  final newName = argsMap['name'];
  final androidPackage = argsMap['android'];
  final iosPackage = argsMap['ios'];
  final path = argsMap['path'];

  if (newName == null || androidPackage == null || iosPackage == null) {
    print(
      '❌ Usage: dart run smart_asset_generator clone '
      'name=my_app android=com.example.myapp ios=com.example.myapp [path=apps]',
    );
    return;
  }

  await cloneProject(
    newProjectName: newName,
    androidPackage: androidPackage,
    iosPackage: iosPackage,
    path: path,
  );
}

Future<void> _handleAsset(List<String> args) async {
  final directoryPath = args.isNotEmpty ? args[0] : 'assets';
  final className = args.length >= 2 ? args[1] : 'Assets';
  await generateAssets(directoryPath: directoryPath, className: className);
}

Future<void> _handleBarrel(List<String> args) async {
  final directoryPath = args.isNotEmpty ? args[0] : 'lib';
  final barrelFileName = args.length >= 2 ? args[1] : 'exports';
  await generateBarrelFile(
    directoryPath: directoryPath,
    barrelFileName: barrelFileName,
  );
}

Future<void> _handlePrChecker(List<String> args) async {
  final argsMap = _parseKeyValueArgs(args);
  final directoryPath = argsMap['dir'] ?? '.gitlab';
  final fileName = argsMap['file'] ?? 'pr_checker.py';
  final projectLabel = argsMap['label'] ?? 'GetX Project';
  final gitlabToken = argsMap['token'] ?? '';
  final emailsStr = argsMap['emails'] ?? '';
  final emails = emailsStr.isEmpty ? <String>[] : emailsStr.split(',').map((e) => e.trim()).toList();
  final overwrite =
      args.contains('--overwrite') || _isTruthy(argsMap['overwrite']);

  await generateGetxPrChecker(
    directoryPath: directoryPath,
    fileName: fileName,
    projectLabel: projectLabel,
    gitlabToken: gitlabToken,
    emails: emails,
    overwrite: overwrite,
  );
}

Future<void> _handleApk(List<String> args) async {
  final mode = parseBuildMode(args);
  final argsMap = _parseKeyValueArgs(args);

  await ensureProjectConfigFile();

  String? apiKey = argsMap['apiKey'] ?? argsMap['_api_key'];
  apiKey ??= readLoadlyApiKeyFromProjectConfig();
  if (apiKey == null || apiKey.isEmpty) {
    print('❌ Missing Loadly API key.');
    print(
      '  Add it to smart_asset_generator.yaml via '
      '`dart run smart_asset_generator config set loadlyApiKey=YOUR_KEY` '
      'or pass apiKey=YOUR_KEY',
    );
    return;
  }

  final installTypeStr =
      argsMap['installType'] ?? argsMap['buildInstallType'] ?? '1';
  final buildInstallType = int.tryParse(installTypeStr) ?? 1;
  final buildPassword = argsMap['password'] ?? argsMap['buildPassword'];
  final desc = argsMap['desc'] ?? argsMap['buildUpdateDescription'];

  await generateAndUploadApk(
    apiKey: apiKey,
    isRelease: mode == BuildMode.release,
    buildInstallType: buildInstallType,
    buildPassword: buildPassword,
    buildUpdateDescription: desc,
  );
}

Future<void> _handleIpa(List<String> args) async {
  final argsMap = _parseKeyValueArgs(args);

  await ensureProjectConfigFile();
  String? apiKey = argsMap['apiKey'] ?? argsMap['_api_key'];
  apiKey ??= readLoadlyApiKeyFromProjectConfig();
  if (apiKey == null || apiKey.isEmpty) {
    print('❌ Missing Loadly API key.');
    print(
      '  Add it to smart_asset_generator.yaml via '
      '`dart run smart_asset_generator config set loadlyApiKey=YOUR_KEY` '
      'or pass apiKey=YOUR_KEY',
    );
    return;
  }

  final installTypeStr =
      argsMap['installType'] ?? argsMap['buildInstallType'] ?? '1';
  final buildInstallType = int.tryParse(installTypeStr) ?? 1;
  final buildPassword = argsMap['password'] ?? argsMap['buildPassword'];
  final desc = argsMap['desc'] ?? argsMap['buildUpdateDescription'];

  await generateAndUploadIpaToLoadly(
    apiKey: apiKey,
    buildInstallType: buildInstallType,
    buildPassword: buildPassword,
    buildUpdateDescription: desc,
  );
}

Future<void> _handleApps(List<String> args) async {
  final mode = parseBuildMode(args);
  final argsMap = _parseKeyValueArgs(args);

  await ensureProjectConfigFile();

  String? apiKey = argsMap['apiKey'] ?? argsMap['_api_key'];
  apiKey ??= readLoadlyApiKeyFromProjectConfig();
  if (apiKey == null || apiKey.isEmpty) {
    print('❌ Missing Loadly API key.');
    print(
      '  Add it to smart_asset_generator.yaml via '
      '`dart run smart_asset_generator config set loadlyApiKey=YOUR_KEY` '
      'or pass apiKey=YOUR_KEY',
    );
    return;
  }

  final installTypeStr =
      argsMap['installType'] ?? argsMap['buildInstallType'] ?? '1';
  final buildInstallType = int.tryParse(installTypeStr) ?? 1;
  final buildPassword = argsMap['password'] ?? argsMap['buildPassword'];
  final desc = argsMap['desc'] ?? argsMap['buildUpdateDescription'];

  final apkResult = await generateAndUploadApkToLoadly(
    apiKey: apiKey,
    isRelease: mode == BuildMode.release,
    buildInstallType: buildInstallType,
    buildPassword: buildPassword,
    buildUpdateDescription: desc,
  );

  final ipaResult = await generateAndUploadIpaToLoadly(
    apiKey: apiKey,
    buildInstallType: buildInstallType,
    buildPassword: buildPassword,
    buildUpdateDescription: desc,
  );

  if (apkResult != null && apkResult.shortcutUrl != null) {
    print('🔗 APK: https://loadly.io/${apkResult.shortcutUrl}');
  }
  if (ipaResult != null && ipaResult.shortcutUrl != null) {
    print('🔗 IPA: https://loadly.io/${ipaResult.shortcutUrl}');
  }
}

Future<void> _handleConfig(List<String> args) async {
  if (args.isEmpty || args.first != 'set') {
    print(
      '❌ Usage: dart run smart_asset_generator config set loadlyApiKey=YOUR_KEY',
    );
    return;
  }

  final argsMap = _parseKeyValueArgs(args.skip(1).toList());
  final loadlyApiKey = argsMap['loadlyApiKey'];
  if (loadlyApiKey == null || loadlyApiKey.isEmpty) {
    print(
      '❌ Missing loadlyApiKey. Example:\n'
      '  dart run smart_asset_generator config set loadlyApiKey=YOUR_KEY',
    );
    return;
  }

  await setLoadlyApiKey(key: loadlyApiKey);
}

void _printUsage() {
  print('❌ Missing arguments.\nUsage:');
  print('  dart run smart_asset_generator asset <directory> [ClassName]');
  print('  dart run smart_asset_generator barrel <directory> [BarrelFileName]');
  print(
    '  dart run smart_asset_generator module name=home location=lib/modules [export=lib/exports.dart]',
  );
  print(
    '  dart run smart_asset_generator prchecker [dir=.gitlab] [file=pr_checker.py] '
    '[label="My GetX App"] [token=YOUR_TOKEN] [emails=a@b.com,c@d.com] [overwrite=true]',
  );
  print(
    '  dart run smart_asset_generator clone '
    'name=my_app android=com.example.myapp ios=com.example.myapp [path=apps]',
  );
  print(
    '  dart run smart_asset_generator apk [release|debug] apiKey=YOUR_KEY '
    '[buildInstallType=1|2|3] [buildPassword=xxxx] [desc=Update+notes]',
  );
  print(
    '  dart run smart_asset_generator ipa apiKey=YOUR_KEY '
    '[buildInstallType=1|2|3] [buildPassword=xxxx] [desc=Update+notes]',
  );
  print(
    '  dart run smart_asset_generator apps [release|debug] apiKey=YOUR_KEY '
    '[buildInstallType=1|2|3] [buildPassword=xxxx] [desc=Update+notes]',
  );
  print('  dart run smart_asset_generator config set loadlyApiKey=YOUR_KEY');
  print('  dart run smart_asset_generator init [--overwrite]');
}

Map<String, String> _parseKeyValueArgs(List<String> args) {
  final map = <String, String>{};
  for (final arg in args) {
    final index = arg.indexOf('=');
    if (index == -1) continue;
    final key = arg.substring(0, index);
    final value = arg.substring(index + 1);
    if (key.isEmpty) continue;
    map[key] = value;
  }
  return map;
}

bool _isTruthy(String? value) {
  if (value == null) return false;
  final normalized = value.toLowerCase().trim();
  return normalized == 'true' ||
      normalized == '1' ||
      normalized == 'yes' ||
      normalized == 'y';
}
