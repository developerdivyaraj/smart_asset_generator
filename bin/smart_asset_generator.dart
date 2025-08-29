// ignore_for_file: avoid_print

import 'package:smart_asset_generator/smart_asset_generator.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('❌ Missing arguments.\nUsage:');
    print('  dart run smart_asset_generator asset <directory> [ClassName]');
    print('  dart run smart_asset_generator barrel <directory> [BarrelFileName]');
    print('  dart run smart_asset_generator module name=home location=lib/modules [export=lib/exports.dart]');
    print('  dart run smart_asset_generator apk [release|debug] apiKey=YOUR_KEY [buildInstallType=1|2|3] [buildPassword=xxxx] [desc=Update+notes]');
    return;
  }

  final command = args.first;
  final rest = args.sublist(1);

  if (command == 'clone') {
    final argsMap = {
      for (var e in args.skip(1))
        if (e.contains('=')) e.split('=').first: e.split('=').last
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
      path:path
    );
  }
  else if (command == 'asset') {
    final directoryPath = rest.isNotEmpty ? rest[0] : 'assets';
    final className = rest.length >= 2 ? rest[1] : 'Assets';

    await generateAssets(
      directoryPath: directoryPath,
      className: className,
    );
  }
  else if (command == 'barrel') {
    final directoryPath = rest.isNotEmpty ? rest[0] : 'lib';
    final barrelFileName = rest.length >= 2 ? rest[1] : 'exports';

    await generateBarrelFile(
      directoryPath: directoryPath,
      barrelFileName: barrelFileName,
    );
  } else if (command == 'module') {
    await generateModuleFromArgs(rest);
  }else if (command == 'apk') {
    // Usage:
    // dart run smart_asset_generator apk [release|debug] apiKey=YOUR_KEY [buildInstallType=1|2|3] [buildPassword=xxxx] [desc=Your+notes]
    final isRelease = rest.any((e) => e.toLowerCase() == 'debug') ? false : true;
    final argsMap = {
      for (var e in rest)
        if (e.contains('=')) e.split('=').first: e.split('=').last
    };

    final apiKey = argsMap['apiKey'] ?? argsMap['_api_key'];
    if (apiKey == null || apiKey.isEmpty) {
      print('❌ Missing apiKey.');
      print('  Usage: dart run smart_asset_generator apk [release|debug] apiKey=YOUR_KEY [buildInstallType=1|2|3] [buildPassword=xxxx] [desc=Update+notes]');
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
  } else {
    print('❌ Unknown command: $command');
  }
}
