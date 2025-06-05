import 'package:smart_asset_generator/smart_asset_generator.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('❌ Missing arguments.\nUsage:');
    print('  dart run asset_generator <directory> [ClassName]');
    print('  dart run asset_generator barrel <directory> [BarrelFileName]');
    return;
  }

  if (args[0] == 'barrel') {
    if (args.length < 2) {
      print('❌ Usage for barrel: dart run asset_generator barrel <directory> [BarrelFileName]');
      return;
    }

    final directoryPath = args[1];
    final barrelFileName = args.length >= 3 ? args[2] : 'imports';

    await generateBarrelFile(
      directoryPath: directoryPath,
      barrelFileName: barrelFileName,
    );
  } else {
    final directoryPath = args[0];
    final className = args.length >= 2 ? args[1] : 'AppAssets';

    await generateAssets(
      directoryPath: directoryPath,
      className: className,
    );
  }
}
