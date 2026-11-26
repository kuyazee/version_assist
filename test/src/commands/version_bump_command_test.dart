import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:version_assist/src/command_runner.dart';

import '../fixture.dart';

class _MockLogger extends Mock implements Logger {}

class _MockProgress extends Mock implements Progress {}

void main() {
  group('version bump', () {
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

    test('preserves version without build number', () async {
      const testPubspec = '''
name: test_app
description: A test application
version: 1.0.0
''';

      fixture.pubspec.writeAsStringSync(testPubspec);

      final exitCode = await fixture.run(commandRunner, ['bump', '--major']);

      expect(exitCode, ExitCode.success.code);
      verify(() => logger.success('Successfully bumped version to 2.0.0'))
          .called(1);
    });

    test('adds build number when explicitly requested', () async {
      const testPubspec = '''
name: test_app
description: A test application
version: 1.0.0
''';

      fixture.pubspec.writeAsStringSync(testPubspec);

      final exitCode = await fixture
          .run(commandRunner, ['bump', '--major', '--add-build-number']);

      expect(exitCode, ExitCode.success.code);
      verify(() => logger.success('Successfully bumped version to 2.0.0+1'))
          .called(1);
    });

    test('removes build number when requested', () async {
      const testPubspec = '''
name: test_app
description: A test application
version: 1.0.0+1
''';

      fixture.pubspec.writeAsStringSync(testPubspec);

      final exitCode = await fixture
          .run(commandRunner, ['bump', '--major', '--no-build-number']);

      expect(exitCode, ExitCode.success.code);
      verify(() => logger.success('Successfully bumped version to 2.0.0'))
          .called(1);
    });

    test('validates conflicting build number flags', () async {
      const testPubspec = '''
name: test_app
description: A test application
version: 1.0.0+1
''';

      fixture.pubspec.writeAsStringSync(testPubspec);

      final exitCode = await fixture.run(
        commandRunner,
        ['bump', '--add-build-number', '--no-build-number'],
      );

      expect(exitCode, ExitCode.usage.code);
      verify(
        () =>
            logger.err('Cannot use --add-build-number with --no-build-number'),
      ).called(1);
    });

    test('validates date-based with no build number', () async {
      const testPubspec = '''
name: test_app
description: A test application
version: 1.0.0+1
''';

      fixture.pubspec.writeAsStringSync(testPubspec);

      final exitCode = await fixture.run(commandRunner, [
        'bump',
        '--date-based-build-number',
        '--no-build-number',
      ]);

      expect(exitCode, ExitCode.usage.code);
      verify(
        () => logger.err(
          'Cannot use --date-based-build-number with --no-build-number',
        ),
      ).called(1);
    });

    test('bumps version in dry run mode', () async {
      const testPubspec = '''
name: test_app
description: A test application
version: 1.0.0+1
''';

      fixture.pubspec.writeAsStringSync(testPubspec);

      final exitCode = await fixture.run(commandRunner, ['bump', '-d']);

      expect(exitCode, ExitCode.success.code);
      verify(
        () => logger.info('Would bump version from 1.0.0+1 to 1.0.0+2'),
      ).called(1);
    });

    test('validates multiple version flags', () async {
      const testPubspec = '''
name: test_app
description: A test application
version: 1.0.0+1
''';

      fixture.pubspec.writeAsStringSync(testPubspec);

      final exitCode =
          await fixture.run(commandRunner, ['bump', '--major', '--minor']);

      expect(exitCode, ExitCode.usage.code);
      verify(
        () => logger
            .err('Only one of --major, --minor, or --patch can be specified'),
      ).called(1);
    });

    test('preserves build number when bumping version', () async {
      const testPubspec = '''
name: test_app
description: A test application
version: 1.0.0+1
''';

      fixture.pubspec.writeAsStringSync(testPubspec);

      final exitCode = await fixture.run(commandRunner, ['bump', '--major']);

      expect(exitCode, ExitCode.success.code);
      verify(() => logger.success('Successfully bumped version to 2.0.0+2'))
          .called(1);
    });

    test('increments large numeric components without wrapping', () async {
      const value = '9223372036854775807';
      fixture.pubspec.writeAsStringSync('version: 1.0.$value+$value\n');

      expect(
        await fixture.run(commandRunner, ['bump', '--patch']),
        ExitCode.success.code,
      );
      expect(
        fixture.pubspec.readAsStringSync(),
        'version: 1.0.9223372036854775808+9223372036854775808\n',
      );
    });

    test('handles file not found', () async {
      final exitCode = await fixture.run(commandRunner, ['bump']);

      expect(exitCode, ExitCode.usage.code);
      verify(
        () => logger.err('pubspec.yaml not found at ${fixture.pubspec.path}'),
      ).called(1);
    });

    test('handles invalid version format', () async {
      const testPubspec = '''
name: test_app
description: A test application
version: invalid.version.format
''';

      fixture.pubspec.writeAsStringSync(testPubspec);

      final exitCode = await fixture.run(commandRunner, ['bump']);

      expect(exitCode, ExitCode.usage.code);
      verify(
        () => logger.err(
          'Could not find valid version pattern in pubspec.yaml',
        ),
      ).called(1);
    });

    test('generates date-based build number', () async {
      const testPubspec = '''
name: test_app
description: A test application
version: 1.0.0+230901
''';

      fixture.pubspec.writeAsStringSync(testPubspec);

      final exitCode = await fixture
          .run(commandRunner, ['bump', '--date-based-build-number']);

      expect(exitCode, ExitCode.success.code);
      verify(() => logger.success(any())).called(1);
    });

    test('increments date-based build number for same day', () async {
      final now = DateTime.now();
      final datePrefix =
          '${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final testPubspec = '''
name: test_app
description: A test application
version: 1.0.0+${datePrefix}01
''';

      fixture.pubspec.writeAsStringSync(testPubspec);

      final exitCode = await fixture
          .run(commandRunner, ['bump', '--date-based-build-number']);

      expect(exitCode, ExitCode.success.code);
      expect(
        fixture.pubspec.readAsStringSync(),
        contains('1.0.0+${datePrefix}02'),
      );
    });

    test('auto-commits version bump', () async {
      const testPubspec = '''
name: test_app
description: A test application
version: 1.0.0+1
''';

      fixture.pubspec.writeAsStringSync(testPubspec);

      final exitCode =
          await fixture.run(commandRunner, ['bump', '--auto-commit']);

      expect(exitCode, ExitCode.success.code);
      verify(() => logger.success('Successfully bumped version to 1.0.0+2'))
          .called(1);
      verify(
        () => logger
            .success('Successfully created version commit and tag for 1.0.0+2'),
      ).called(1);
    });
  });
}
