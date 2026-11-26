import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:cli_completion/cli_completion.dart';
import 'package:cli_completion/installer.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pub_updater/pub_updater.dart';
import 'package:test/test.dart';
import 'package:version_assist/src/command_runner.dart';
import 'package:version_assist/src/version.dart';

class _MockLogger extends Mock implements Logger {}

class _MockProgress extends Mock implements Progress {}

class _MockPubUpdater extends Mock implements PubUpdater {}

class _MockStdin extends Mock implements Stdin {}

class _MockStdout extends Mock implements Stdout {}

class _MockInstallation extends Mock implements CompletionInstallation {}

class _TestRunner extends VersionAssistCommandRunner {
  _TestRunner({required super.logger, required super.pubUpdater});

  @override
  final completionInstallation = _MockInstallation();
}

const latestVersion = '10.0.0';

void main() {
  group('VersionAssistCommandRunner', () {
    late PubUpdater pubUpdater;
    late Logger logger;
    late _TestRunner commandRunner;

    setUp(() {
      pubUpdater = _MockPubUpdater();

      when(
        () => pubUpdater.getLatestVersion(any()),
      ).thenAnswer((_) async => packageVersion);

      logger = _MockLogger();

      commandRunner = _TestRunner(
        logger: logger,
        pubUpdater: pubUpdater,
      )..environmentOverride = {};
    });

    Future<int> runWithTerminal(
      List<String> args, {
      bool hasInputTerminal = true,
      bool hasOutputTerminal = true,
    }) {
      final input = _MockStdin();
      final output = _MockStdout();
      when(() => input.hasTerminal).thenReturn(hasInputTerminal);
      when(() => output.supportsAnsiEscapes).thenReturn(false);
      when(() => output.hasTerminal).thenReturn(hasOutputTerminal);
      return IOOverrides.runZoned(
        () => commandRunner.run(args),
        stdin: () => input,
        stdout: () => output,
      );
    }

    void verifyNoAutomaticSetup() {
      final installation = commandRunner.completionInstallation;
      verifyNever(() => installation.install(executableName));
      verifyNever(() => pubUpdater.getLatestVersion(any()));
    }

    test('shows newer releases after an interactive command', () async {
      when(() => pubUpdater.getLatestVersion(any()))
          .thenAnswer((_) async => latestVersion);

      final result = await runWithTerminal(['commit', '--dry-run']);
      expect(result, ExitCode.success.code);
      final notice = contains('$packageVersion → $latestVersion');
      verify(() => logger.info(any(that: notice))).called(1);
      verify(() => commandRunner.completionInstallation.install(executableName))
          .called(1);
    });

    test('does not suggest downgrading a local version', () async {
      when(() => pubUpdater.getLatestVersion(any()))
          .thenAnswer((_) async => '0.0.1');

      final result = await runWithTerminal(['commit', '--dry-run']);
      expect(result, ExitCode.success.code);
      verify(() => pubUpdater.getLatestVersion(packageName)).called(1);
      verifyNever(() => logger.info(any(that: contains('Update available!'))));
    });

    test('a stalled lookup does not block an interactive command', () async {
      final request = Completer<String>();
      when(() => pubUpdater.getLatestVersion(any()))
          .thenAnswer((_) => request.future);
      addTearDown(() => request.complete(packageVersion));

      final result = await runWithTerminal(['commit', '--dry-run'])
          .timeout(const Duration(seconds: 5));
      expect(result, ExitCode.success.code);
      verify(() => pubUpdater.getLatestVersion(packageName)).called(1);
    });

    for (final args in [
      <String>[],
      ['--version'],
      ['--help'],
      ['help', 'commit'],
      ['commit', '--help'],
      ['--help', 'commit'],
      ['completion'],
    ]) {
      final invocation = args.isEmpty ? 'no arguments' : args.join(' ');
      test('no automatic setup or update lookup for $invocation', () async {
        expect(await runWithTerminal(args), ExitCode.success.code);
        verifyNoAutomaticSetup();
      });
    }

    test('skips automatic lookups when input or output is redirected',
        () async {
      expect(
        await runWithTerminal(['commit', '--dry-run'], hasInputTerminal: false),
        ExitCode.success.code,
      );
      expect(
        await runWithTerminal(
          ['commit', '--dry-run'],
          hasOutputTerminal: false,
        ),
        ExitCode.success.code,
      );
      verifyNoAutomaticSetup();
    });

    test('skips automatic lookups on CI even with a terminal', () async {
      commandRunner.environmentOverride = {'CI': 'true'};
      expect(
        await runWithTerminal(['commit', '--dry-run']),
        ExitCode.success.code,
      );
      verifyNoAutomaticSetup();
    });

    test('installs completion when requested without a terminal', () async {
      final result = await runWithTerminal(
        ['install-completion-files'],
        hasOutputTerminal: false,
      );
      expect(result, ExitCode.success.code);
      final installation = commandRunner.completionInstallation;
      verify(() => installation.install(executableName, force: true)).called(1);
    });

    test('explicit update looks up the published version once', () async {
      when(() => logger.progress(any())).thenReturn(_MockProgress());

      final result = await runWithTerminal(['update']);
      expect(result, ExitCode.success.code);
      verify(() => pubUpdater.getLatestVersion(packageName)).called(1);
    });

    test('can be instantiated without an explicit analytics/logger instance',
        () {
      final commandRunner = VersionAssistCommandRunner();
      expect(commandRunner, isNotNull);
      expect(commandRunner, isA<CompletionCommandRunner<int>>());
    });

    test('handles FormatException', () async {
      const exception = FormatException('oops!');
      var isFirstInvocation = true;
      when(() => logger.info(any())).thenAnswer((_) {
        if (isFirstInvocation) {
          isFirstInvocation = false;
          throw exception;
        }
      });
      final result = await commandRunner.run(['--version']);
      expect(result, equals(ExitCode.usage.code));
      verify(() => logger.err(exception.message)).called(1);
      verify(() => logger.info(commandRunner.usage)).called(1);
    });

    test('handles UsageException', () async {
      final exception = UsageException('oops!', 'exception usage');
      var isFirstInvocation = true;
      when(() => logger.info(any())).thenAnswer((_) {
        if (isFirstInvocation) {
          isFirstInvocation = false;
          throw exception;
        }
      });
      final result = await commandRunner.run(['--version']);
      expect(result, equals(ExitCode.usage.code));
      verify(() => logger.err(exception.message)).called(1);
      verify(() => logger.info('exception usage')).called(1);
    });

    group('--version', () {
      test('outputs current version', () async {
        final result = await commandRunner.run(['--version']);
        expect(result, equals(ExitCode.success.code));
        verify(() => logger.info(packageVersion)).called(1);
      });
    });

    group('--verbose', () {
      test('enables verbose logging', () async {
        final result = await commandRunner.run(['--verbose']);
        expect(result, equals(ExitCode.success.code));

        verify(() => logger.detail('Argument information:')).called(1);
        verify(() => logger.detail('  Top level options:')).called(1);
        verify(() => logger.detail('  - verbose: true')).called(1);
        verifyNever(() => logger.detail('    Command options:'));
      });

      test('enables verbose logging for sub commands', () async {
        final result = await commandRunner.run([
          '--verbose',
          'commit',
          '--dry-run',
        ]);
        expect(result, equals(ExitCode.success.code));

        verify(() => logger.detail('Argument information:')).called(1);
        verify(() => logger.detail('  Top level options:')).called(1);
        verify(() => logger.detail('  - verbose: true')).called(1);
        verify(() => logger.detail('  Command: commit')).called(1);
        verify(() => logger.detail('    Command options:')).called(1);
        verify(() => logger.detail('    - dry-run: true')).called(1);
      });
    });
  });
}
