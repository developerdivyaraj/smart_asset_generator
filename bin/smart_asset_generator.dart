// ignore_for_file: avoid_print

import 'package:smart_asset_generator/smart_asset_generator.dart';

enum Command { clone, asset, barrel, module, apk, config, init }

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
    case 'config':
      return Command.config;
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
    print('  dart run smart_asset_generator barrel <directory> [BarrelFileName]');
    print('  dart run smart_asset_generator module name=home location=lib/modules [export=lib/exports.dart]');
    print('  dart run smart_asset_generator apk [release|debug] apiKey=YOUR_KEY [buildInstallType=1|2|3] [buildPassword=xxxx] [desc=Update+notes]');
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
        print('❌ Usage: dart run smart_asset_generator clone name=my_app android=com.example.myapp ios=com.example.myapp');
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
        print('❌ Missing Loadly API key.');
        print('  Add it to smart_asset_generator.yaml as loadlyApiKey or pass apiKey=YOUR_KEY');
        return;
      }

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

    case Command.config:
      if (rest.isEmpty) {
        print('❌ Missing subcommand. Usage: dart run smart_asset_generator config set loadlyApiKey=YOUR_KEY');
        return;
      }
      final sub = rest.first;
      final subArgs = rest.sublist(1);
      if (sub == 'set') {
        final subMap = {
          for (var e in subArgs)
            if (e.contains('=')) e.split('=')[0]: e.split('=')[1]
        };
        final key = subMap['loadlyApiKey'] ?? subMap['apiKey'] ?? subMap['_api_key'];
        if (key == null || key.isEmpty) {
          print('❌ Missing loadlyApiKey. Usage: dart run smart_asset_generator config set loadlyApiKey=YOUR_KEY');
          return;
        }
        await setLoadlyApiKey(key: key);
      } else {
        print('❌ Unknown config subcommand: $sub');
      }
      break;

    case Command.init:
      final overwrite = rest.any((e) => e == '--overwrite');
      await initProjectConfig(overwrite: overwrite);
      break;
  }
}
