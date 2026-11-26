import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:test/test.dart';
import 'package:version_assist/src/commands/version_bump_command.dart';

import '../fixture.dart';

void main() {
  late CommandFixture fixture;
  late CommandRunner<int> cli;
  final day = DateTime(2025, 5, 10);
  setUp(() {
    fixture = CommandFixture();
    addTearDown(fixture.dispose);
    cli = CommandRunner<int>('test', 'Calendar version')
      ..addCommand(VersionBumpCommand(logger: Logger(), now: () => day));
  });

  Future<int?> bump(List<String> args) =>
      cli.run(['bump', ...args, '--path', fixture.pubspec.path]);

  test('uses the local date without adding a build suffix', () async {
    fixture.pubspec.writeAsStringSync('version: 1.2.3\n');
    expect(await bump(['--date-based-version']), 0);
    expect(fixture.pubspec.readAsStringSync(), 'version: 25.05.10\n');
  });

  test('combines calendar version and daily counter across builds', () async {
    fixture.pubspec.writeAsStringSync('version: 25.05.09+25050999\n');
    const flags = ['--date-based-version', '--date-based-build-number'];
    expect(await bump(flags), 0);
    expect(fixture.pubspec.readAsStringSync(), 'version: 25.05.10+25051000\n');
    expect(await bump(flags), 0);
    expect(fixture.pubspec.readAsStringSync(), 'version: 25.05.10+25051001\n');
  });

  test('previews a calendar bump without writing the file', () async {
    const source = 'version: 1.2.3+50\n';
    fixture.pubspec.writeAsStringSync(source);
    expect(await bump(['--date-based-version', '--dry-run']), 0);
    expect(fixture.pubspec.readAsStringSync(), source);
  });

  test('rejects calendar and semantic bump flags together', () async {
    const source = 'version: 1.2.3\n';
    fixture.pubspec.writeAsStringSync(source);
    for (final flag in ['--major', '--minor', '--patch']) {
      expect(await bump(['--date-based-version', flag]), ExitCode.usage.code);
      expect(fixture.pubspec.readAsStringSync(), source);
    }
  });

  test('stops at the last daily build instead of reusing a number', () async {
    const source = 'version: 1.2.3+25051099\n';
    fixture.pubspec.writeAsStringSync(source);
    expect(await bump(['--date-based-build-number']), ExitCode.usage.code);
    expect(fixture.pubspec.readAsStringSync(), source);
  });
}
