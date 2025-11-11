import 'package:smart_asset_generator/smart_asset_generator.dart';

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
    return;
  }

  final command = args.first;
  final rest = args.sublist(1);

  if (command == 'asset') {
    final directoryPath = rest.isNotEmpty ? rest[0] : null;
    final className = rest.length >= 2 ? rest[1] : 'AppAssets';

    if (directoryPath == null) {
      print(
        '❌ Usage: dart run smart_asset_generator asset <directory> [ClassName]',
      );
      return;
    }

    await generateAssets(directoryPath: directoryPath, className: className);
  } else if (command == 'barrel') {
    final directoryPath = rest.isNotEmpty ? rest[0] : null;
    final barrelFileName = rest.length >= 2 ? rest[1] : 'exports';

    if (directoryPath == null) {
      print(
        '❌ Usage: dart run smart_asset_generator barrel <directory> [BarrelFileName]',
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
