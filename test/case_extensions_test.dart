import 'package:flutter_test/flutter_test.dart';
import 'package:smart_asset_generator/smart_asset_generator.dart';

void main() {
  group('Case extensions', () {
    test('toSnakeCase converts camelCase to snake_case', () {
      expect('sampleCase'.toSnakeCase(), 'sample_case');
    });

    test('toPascalCase converts snake_case to PascalCase', () {
      expect('sample_case'.toPascalCase(), 'SampleCase');
    });
  });
}

