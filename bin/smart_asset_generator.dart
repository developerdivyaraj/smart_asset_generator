// ignore_for_file: avoid_print

import 'package:smart_asset_generator/smart_asset_generator.dart';

enum Command { clone, asset, barrel, module, apk, ipa, apps, init }

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
    case 'apk':
      return Command.apk;
    case 'ipa':
      return Command.ipa;
    case 'apps':
      return Command.apps;
    case 'init':
      return Command.init;
    default:
      return null;
  }
}

enum BuildMode { release, debug }

BuildMode parseBuildMode(List<String> rest) {
  return rest.any((e) => e.toLowerCase() == 'debug') ? BuildMode.debug : BuildMode.release;
}

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('❌ Missing arguments.\nUsage:');
    print('  dart run smart_asset_generator asset <directory> [ClassName]');
    print(
      '  dart run smart_asset_generator barrel <directory> [BarrelFileName]',
    );
    print(
      '  dart run smart_asset_generator module name=home location=lib/modules [export=lib/exports.dart]',
    );
    print(
      '  dart run smart_asset_generator prchecker [dir=.gitlab] [file=pr_checker.py] [label="My GetX App"] [token=YOUR_TOKEN] [overwrite=true]',
    );
    print('  dart run smart_asset_generator apk [release|debug] apiKey=YOUR_KEY [buildInstallType=1|2|3] [buildPassword=xxxx] [desc=Update+notes]');
    print('  dart run smart_asset_generator ipa apiKey=YOUR_KEY [buildInstallType=1|2|3] [buildPassword=xxxx] [desc=Update+notes]');
    print('  dart run smart_asset_generator apps [release|debug] apiKey=YOUR_KEY [buildInstallType=1|2|3] [buildPassword=xxxx] [desc=Update+notes]');
    print('  dart run smart_asset_generator config set loadlyApiKey=YOUR_KEY');
    print('  dart run smart_asset_generator init');
    return;
  }

  final commandRaw = args.first;
  final rest = args.sublist(1);
  final command = parseCommand(commandRaw);

  if (command == null) {
    print('❌ Unknown command: $commandRaw');
    return;
  }

  switch (command) {
    case Command.clone:
      final argsMap = {
        for (var e in args.skip(1))
          if (e.contains('=')) e.split('=')[0]: e.split('=')[1]
      };

      final newName = argsMap['name'];
      final androidPackage = argsMap['android'];
      final iosPackage = argsMap['ios'];
      final path = argsMap['path'];

      if (newName == null || androidPackage == null || iosPackage == null) {
        print(
        '❌ Usage: dart run smart_asset_generator clone name=my_app android=com.example.myapp ios=com.example.myapp',
      );
        return;
      }

      await cloneProject(
          newProjectName: newName,
          androidPackage: androidPackage,
          iosPackage: iosPackage,
          path: path);
      break;

    case Command.asset:
      final directoryPath = rest.isNotEmpty ? rest[0] : 'assets';
      final className = rest.length >= 2 ? rest[1] : 'Assets';
      await generateAssets(directoryPath: directoryPath, className: className);
      break;

    case Command.barrel:
      final directoryPath = rest.isNotEmpty ? rest[0] : 'lib';
      final barrelFileName = rest.length >= 2 ? rest[1] : 'exports';
      await generateBarrelFile(directoryPath: directoryPath, barrelFileName: barrelFileName);
      break;

    case Command.module:
      await generateModuleFromArgs(rest);
      break;
    await generateAssets(directoryPath: directoryPath, className: className);
  } else if (command == 'barrel') {
    final directoryPath = rest.isNotEmpty ? rest[0] : null;
    final barrelFileName = rest.length >= 2 ? rest[1] : 'exports';

    case Command.apk:
      // Usage:
      // dart run smart_asset_generator apk [release|debug] apiKey=YOUR_KEY [buildInstallType=1|2|3] [buildPassword=xxxx] [desc=Your+notes]
      final mode = parseBuildMode(rest);
      final isRelease = mode == BuildMode.release;
      final argsMap = {
        for (var e in rest)
          if (e.contains('=')) e.split('=')[0]: e.split('=')[1]
      };

      await ensureProjectConfigFile();

      String? apiKey = argsMap['apiKey'] ?? argsMap['_api_key'];
      apiKey ??= readLoadlyApiKeyFromProjectConfig();
      if (apiKey == null || apiKey.isEmpty) {
        print(
        '❌ Missing Loadly API key.');
        print('  Add it to smart_asset_generator.yaml as loadlyApiKey or pass apiKey=YOUR_KEY',
      );
        return;
      }

    await generateBarrelFile(
      directoryPath: directoryPath,
      barrelFileName: barrelFileName,
    );
  } else if (command == 'module') {
    await generateModuleFromArgs(rest);
  } else if (command == 'prchecker') {
    final argsMap = _parseKeyValueArgs(rest);
    final directoryPath = argsMap['dir'] ?? '.gitlab';
    final fileName = argsMap['file'] ?? 'pr_checker.py';
    final projectLabel = argsMap['label'] ?? 'GetX Project';
    final gitlabToken = argsMap['token'] ?? '';
    final overwrite =
        rest.contains('--overwrite') || _isTruthy(argsMap['overwrite']);

    await generateGetxPrChecker(
      directoryPath: directoryPath,
      fileName: fileName,
      projectLabel: projectLabel,
      gitlabToken: gitlabToken,
      overwrite: overwrite,
    );
  } else {
    print('❌ Unknown command: $command');
      final installTypeStr = argsMap['installType'] ?? argsMap['buildInstallType'] ?? '1';
      final buildInstallType = int.tryParse(installTypeStr) ?? 1;
      final buildPassword = argsMap['password'] ?? argsMap['buildPassword'];
      final desc = argsMap['desc'] ?? argsMap['buildUpdateDescription'];

      await generateAndUploadApkToLoadly(
        apiKey: apiKey,
        isRelease: isRelease,
        buildInstallType: buildInstallType,
        buildPassword: buildPassword,
        buildUpdateDescription: desc,
      );
      break;

    case Command.ipa:
      // Usage:
      // dart run smart_asset_generator ipa apiKey=YOUR_KEY [buildInstallType=1|2|3] [buildPassword=xxxx] [desc=Your+notes]
      final argsMapIpa = {
        for (var e in rest)
          if (e.contains('=')) e.split('=')[0]: e.split('=')[1]
      };
      await ensureProjectConfigFile();
      String? apiKeyIpa = argsMapIpa['apiKey'] ?? argsMapIpa['_api_key'];
      apiKeyIpa ??= readLoadlyApiKeyFromProjectConfig();
      if (apiKeyIpa == null || apiKeyIpa.isEmpty) {
        print('❌ Missing Loadly API key.');
        print('  Add it to smart_asset_generator.yaml as loadlyApiKey or pass apiKey=YOUR_KEY');
        return;
      }
      final installTypeStrIpa = argsMapIpa['installType'] ?? argsMapIpa['buildInstallType'] ?? '1';
      final buildInstallTypeIpa = int.tryParse(installTypeStrIpa) ?? 1;
      final buildPasswordIpa = argsMapIpa['password'] ?? argsMapIpa['buildPassword'];
      final descIpa = argsMapIpa['desc'] ?? argsMapIpa['buildUpdateDescription'];

      await generateAndUploadIpaToLoadly(
        apiKey: apiKeyIpa,
        buildInstallType: buildInstallTypeIpa,
        buildPassword: buildPasswordIpa,
        buildUpdateDescription: descIpa,
      );
      break;

    case Command.apps:
      // Usage:
      // dart run smart_asset_generator apps [release|debug] apiKey=YOUR_KEY [buildInstallType=1|2|3] [buildPassword=xxxx] [desc=Your+notes]
      final modeBoth = parseBuildMode(rest);
      final isReleaseBoth = modeBoth == BuildMode.release;
      final argsMapBoth = {
        for (var e in rest)
          if (e.contains('=')) e.split('=')[0]: e.split('=')[1]
      };
      await ensureProjectConfigFile();
      String? apiKeyBoth = argsMapBoth['apiKey'] ?? argsMapBoth['_api_key'];
      apiKeyBoth ??= readLoadlyApiKeyFromProjectConfig();
      if (apiKeyBoth == null || apiKeyBoth.isEmpty) {
        print('❌ Missing Loadly API key.');
        print('  Add it to smart_asset_generator.yaml as loadlyApiKey or pass apiKey=YOUR_KEY');
        return;
      }
      final installTypeStrBoth = argsMapBoth['installType'] ?? argsMapBoth['buildInstallType'] ?? '1';
      final buildInstallTypeBoth = int.tryParse(installTypeStrBoth) ?? 1;
      final buildPasswordBoth = argsMapBoth['password'] ?? argsMapBoth['buildPassword'];
      final descBoth = argsMapBoth['desc'] ?? argsMapBoth['buildUpdateDescription'];

      // APK
      LoadlyUploadResult? apkResult = await generateAndUploadApkToLoadly(
        apiKey: apiKeyBoth,
        isRelease: isReleaseBoth,
        buildInstallType: buildInstallTypeBoth,
        buildPassword: buildPasswordBoth,
        buildUpdateDescription: descBoth,
      );
      // IPA (macOS only)
      LoadlyUploadResult? ipaResult = await generateAndUploadIpaToLoadly(
        apiKey: apiKeyBoth,
        buildInstallType: buildInstallTypeBoth,
        buildPassword: buildPasswordBoth,
        buildUpdateDescription: descBoth,
      );

      if(apkResult!=null)print('🔗 APK: https://loadly.io/${apkResult.shortcutUrl}');
      if(ipaResult!=null)print('🔗 IPA: https://loadly.io/${ipaResult.shortcutUrl}');
      break;


    case Command.init:
      final overwrite = rest.any((e) => e == '--overwrite');
      await initProjectConfig(overwrite: overwrite);
      break;
  }
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
