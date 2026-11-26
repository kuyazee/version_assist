import 'dart:io';

import 'package:test/test.dart';
import 'package:version_assist/src/version.dart';

void main() {
  test('CLI reports the version in pubspec.yaml', () {
    final line = File('pubspec.yaml').readAsLinesSync().singleWhere(
          (line) => line.startsWith('version: '),
        );
    expect(packageVersion, line.substring('version: '.length).trim());
  });
}
