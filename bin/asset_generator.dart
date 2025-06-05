import 'package:smart_asset_generator/asset_generator.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    print('❌ Usage: asset_generator <assets_path> [className]');
    return;
  }

  final path = args[0];
  final className = args.length > 1 ? args[1] : 'AppAssets';

  generateAssets(directoryPath: path, className: className);
}
