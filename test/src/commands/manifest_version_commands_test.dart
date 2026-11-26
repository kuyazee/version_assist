import 'package:mason_logger/mason_logger.dart';
import 'package:test/test.dart';
import 'package:version_assist/src/command_runner.dart';

import '../fixture.dart';

void main() {
  late CommandFixture files;
  late VersionAssistCommandRunner runner;
  const badge = '[pub_version_badge]: https://img.shields.io/badge/pub-v';

  setUp(() {
    files = CommandFixture();
    addTearDown(files.dispose);
    runner = VersionAssistCommandRunner(
      pubUpdater: files.updater,
      gitClient: files.git,
    );
  });

  const prefix = '# version: 0.0.1\r\n'
      'config:\r\n'
      '  version: 0.0.2\r\n';
  const suffix = '   # keep this comment\r\nname: app\r\n';
  test('bump updates only the quoted top-level value', () async {
    files.pubspec.writeAsStringSync('${prefix}version:  "1.2.3+9"$suffix');

    expect(await files.run(runner, ['bump', '--patch']), ExitCode.success.code);
    expect(
      files.pubspec.readAsStringSync(),
      '${prefix}version:  "1.2.4+10"$suffix',
    );
  });

  test('set preserves single quotes, spacing, comments and line endings',
      () async {
    files.pubspec.writeAsStringSync("${prefix}version:   '1.2.3'$suffix");

    expect(
      await files.run(runner, ['set', '-v', '2.0.1+3']),
      ExitCode.success.code,
    );
    expect(
      files.pubspec.readAsStringSync(),
      "${prefix}version:   '2.0.1+3'$suffix",
    );
  });

  test('badge reads the top-level version', () async {
    files.pubspec.writeAsStringSync('${prefix}version: "3.2.1"$suffix');
    files.readme.writeAsStringSync('${badge}1.1.1-blue\r\n');
    expect(await files.run(runner, ['badge']), ExitCode.success.code);
    expect(files.readme.readAsStringSync(), '${badge}3.2.1-blue\r\n');
  });

  for (final args in [
    ['bump', '--patch'],
    ['set', '-v', '2.0.1'],
    ['commit', '--dry-run'],
    ['badge'],
  ]) {
    test('${args.first} rejects a prerelease instead of using a numeric prefix',
        () async {
      const unsupported = '${prefix}version: 1.0.0-beta.2+4\r\n';
      const reference = '${badge}4.0.0-blue\n';
      files.pubspec.writeAsStringSync(unsupported);
      files.readme.writeAsStringSync(reference);
      expect(await files.run(runner, args), ExitCode.usage.code);
      expect(files.pubspec.readAsStringSync(), unsupported);
      expect(files.readme.readAsStringSync(), reference);
    });
  }

  for (final (name, content) in [
    ('a missing top-level version', prefix),
    ('a merged version', 'default: &base {version: 0.3.1}\n<<: *base\n'),
    ('an alias', 'default: &number 1.2.3\nversion: *number\n'),
    ('a duplicate version', 'version: 1.2.3\nversion: 4.5.6\n'),
    ('an alphanumeric build', 'version: 1.2.3+4beta\n'),
    ('a multiline scalar', 'version: >-\n  1.2.3\n'),
  ]) {
    test('set leaves the document unchanged for $name', () async {
      files.pubspec.writeAsStringSync(content);
      expect(
        await files.run(runner, ['set', '-v', '3.0.0']),
        ExitCode.usage.code,
      );
      expect(files.pubspec.readAsStringSync(), content);
    });
  }

  test('badge reports a missing reference, even in dry-run mode', () async {
    files.pubspec.writeAsStringSync('version: 1.2.3\n');
    const readme = '# Example\n';
    files.readme.writeAsStringSync(readme);
    for (final args in [
      ['badge'],
      ['badge', '--dry-run'],
    ]) {
      expect(await files.run(runner, args), ExitCode.usage.code);
      expect(files.readme.readAsStringSync(), readme);
    }
  });

  test('badge leaves a current reference untouched', () async {
    files.pubspec.writeAsStringSync('version: 1.2.3\n');
    files.readme.writeAsStringSync('${badge}1.2.3-blue\n');
    files.readme.setLastModifiedSync(DateTime(2020));
    final before = files.readme.lastModifiedSync();
    expect(await files.run(runner, ['badge']), ExitCode.success.code);
    expect(files.readme.lastModifiedSync(), before);
  });
}
