import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:version_assist/src/command_runner.dart';

import '../fixture.dart';

class _MockLogger extends Mock implements Logger {}

class _MockProgress extends Mock implements Progress {}

void main() {
  group('update badge', () {
    late CommandFixture fixture;
    late Logger logger;
    late Progress progress;
    late VersionAssistCommandRunner commandRunner;

    setUpAll(() {
      registerFallbackValue('');
      registerFallbackValue(<String>[]);
    });

    setUp(() {
      fixture = CommandFixture();
      addTearDown(fixture.dispose);
      logger = _MockLogger();
      progress = _MockProgress();
      commandRunner = VersionAssistCommandRunner(
        logger: logger,
        pubUpdater: fixture.updater,
        gitClient: fixture.git,
      );

      // Set up default mock behavior for logger
      when(() => logger.progress(any())).thenReturn(progress);
      when(() => logger.detail(any())).thenReturn(null);
      when(() => logger.err(any())).thenReturn(null);
      when(() => logger.info(any())).thenReturn(null);
      when(() => logger.success(any())).thenReturn(null);
      when(() => progress.complete(any())).thenReturn(null);
      when(() => progress.fail(any())).thenReturn(null);
    });

    test('updates version badge', () async {
      const testPubspec = '''
name: test_app
description: A test application
version: 1.0.0+1
''';

      const testReadme = '''
# Test App
[![pub package][pub_version_badge]][pub_package_link]

[pub_version_badge]: https://img.shields.io/badge/pub-v0.9.0-blue
[pub_package_link]: https://pub.dev/packages/test_app
''';

      fixture.pubspec.writeAsStringSync(testPubspec);

      fixture.readme.writeAsStringSync(testReadme);

      final exitCode = await fixture.run(commandRunner, ['badge']);

      expect(exitCode, ExitCode.success.code);
      expect(fixture.readme.readAsStringSync(), contains('pub-v1.0.0+1-blue'));
      verify(
        () => logger.success('Successfully updated version badge to v1.0.0+1'),
      ).called(1);
    });

    test('handles missing pubspec.yaml', () async {
      final exitCode = await fixture.run(commandRunner, ['badge']);

      expect(exitCode, ExitCode.usage.code);
      verify(
        () => logger.err('pubspec.yaml not found at ${fixture.pubspec.path}'),
      ).called(1);
    });

    test('handles missing README.md', () async {
      const testPubspec = '''
name: test_app
description: A test application
version: 1.0.0+1
''';

      fixture.pubspec.writeAsStringSync(testPubspec);

      final exitCode = await fixture.run(commandRunner, ['badge']);

      expect(exitCode, ExitCode.usage.code);
      verify(() => logger.err('README.md not found at ${fixture.readme.path}'))
          .called(1);
    });

    test('handles invalid version in pubspec.yaml', () async {
      const testPubspec = '''
name: test_app
description: A test application
version: invalid.version
''';

      fixture.pubspec.writeAsStringSync(testPubspec);

      final exitCode = await fixture.run(commandRunner, ['badge']);

      expect(exitCode, ExitCode.usage.code);
      verify(() => logger.err('Could not find valid version in pubspec.yaml'))
          .called(1);
    });

    test('shows changes in dry run mode', () async {
      const testPubspec = '''
name: test_app
description: A test application
version: 1.0.0+1
''';

      const testReadme = '''
# Test App
[![pub package][pub_version_badge]][pub_package_link]

[pub_version_badge]: https://img.shields.io/badge/pub-v0.9.0-blue
[pub_package_link]: https://pub.dev/packages/test_app
''';

      fixture.pubspec.writeAsStringSync(testPubspec);

      fixture.readme.writeAsStringSync(testReadme);

      final exitCode = await fixture.run(commandRunner, ['badge', '--dry-run']);

      expect(exitCode, ExitCode.success.code);
      verify(() => logger.info('Would update version badge to v1.0.0+1'))
          .called(1);
    });
  });
}
