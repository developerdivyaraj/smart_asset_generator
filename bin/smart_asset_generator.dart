import 'package:smart_asset_generator/smart_asset_generator.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('❌ Missing arguments.\nUsage:');
    print('  dart run smart_asset_generator asset <directory> [ClassName]');
    print('  dart run smart_asset_generator barrel <directory> [BarrelFileName]');
    print('  dart run smart_asset_generator module name=home location=lib/modules [export=lib/exports.dart]');
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

    if (newName == null || androidPackage == null || iosPackage == null) {
      print('❌ Usage: dart run smart_asset_generator clone name=my_app android=com.example.myapp ios=com.example.myapp');
      return;
    }

    await cloneProject(
      newProjectName: newName,
      androidPackage: androidPackage,
      iosPackage: iosPackage,
    );
  }
  else if (command == 'asset') {
    final directoryPath = rest.isNotEmpty ? rest[0] : null;
    final className = rest.length >= 2 ? rest[1] : 'AppAssets';

    if (directoryPath == null) {
      print('❌ Usage: dart run smart_asset_generator asset <directory> [ClassName]');
      return;
    }

    await generateAssets(
      directoryPath: directoryPath,
      className: className,
    );
  } else if (command == 'barrel') {
    final directoryPath = rest.isNotEmpty ? rest[0] : null;
    final barrelFileName = rest.length >= 2 ? rest[1] : 'exports';

    if (directoryPath == null) {
      print('❌ Usage: dart run smart_asset_generator barrel <directory> [BarrelFileName]');
      return;
    }

    await generateBarrelFile(
      directoryPath: directoryPath,
      barrelFileName: barrelFileName,
    );
  } else if (command == 'module') {
    await generateModuleFromArgs(rest);
  } else {
    print('❌ Unknown command: $command');
  }
}
