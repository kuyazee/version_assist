import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pub_updater/pub_updater.dart';
import 'package:test/test.dart';
import 'package:version_assist/src/command_runner.dart';
import 'package:version_assist/src/commands/commands.dart';
import 'package:version_assist/src/version.dart';

class _MockLogger extends Mock implements Logger {}

class _MockProgress extends Mock implements Progress {}

class _MockPubUpdater extends Mock implements PubUpdater {}

void main() {
  const latestVersion = '10.0.0';

  group('update', () {
    late PubUpdater pubUpdater;
    late Logger logger;
    late VersionAssistCommandRunner commandRunner;

    setUp(() {
      final progress = _MockProgress();
      pubUpdater = _MockPubUpdater();
      logger = _MockLogger();
      commandRunner = VersionAssistCommandRunner(
        logger: logger,
        pubUpdater: pubUpdater,
      );

      when(
        () => pubUpdater.getLatestVersion(any()),
      ).thenAnswer((_) async => packageVersion);
      when(() => logger.progress(any())).thenReturn(progress);
    });

    test('can be instantiated without a pub updater', () {
      final command = UpdateCommand(logger: logger);
      expect(command, isNotNull);
    });

    test(
      'handles pub latest version query errors',
      () async {
        when(
          () => pubUpdater.getLatestVersion(any()),
        ).thenThrow(Exception('oops'));
        final result = await commandRunner.run(['update']);
        expect(result, equals(ExitCode.software.code));
        verify(() => logger.progress('Checking for updates')).called(1);
        verify(() => logger.err('Exception: oops'));
        verifyNever(
          () => pubUpdater.update(
            packageName: any(named: 'packageName'),
            versionConstraint: any(named: 'versionConstraint'),
          ),
        );
      },
    );

    test(
      'handles pub update errors',
      () async {
        when(
          () => pubUpdater.getLatestVersion(any()),
        ).thenAnswer((_) async => latestVersion);
        when(
          () => pubUpdater.update(
            packageName: any(named: 'packageName'),
            versionConstraint: any(named: 'versionConstraint'),
          ),
        ).thenThrow(Exception('oops'));
        final result = await commandRunner.run(['update']);
        expect(result, equals(ExitCode.software.code));
        verify(() => logger.progress('Checking for updates')).called(1);
        verify(() => logger.err('Exception: oops'));
        verify(
          () => pubUpdater.update(
            packageName: any(named: 'packageName'),
            versionConstraint: any(named: 'versionConstraint'),
          ),
        ).called(1);
      },
    );

    test(
      'updates when newer version exists',
      () async {
        when(
          () => pubUpdater.getLatestVersion(any()),
        ).thenAnswer((_) async => latestVersion);
        when(
          () => pubUpdater.update(
            packageName: any(named: 'packageName'),
            versionConstraint: any(named: 'versionConstraint'),
          ),
        ).thenAnswer(
          (_) async => ProcessResult(0, ExitCode.success.code, '', ''),
        );
        when(() => logger.progress(any())).thenReturn(_MockProgress());
        final result = await commandRunner.run(['update']);
        expect(result, equals(ExitCode.success.code));
        verify(() => logger.progress('Checking for updates')).called(1);
        verify(() => logger.progress('Updating to $latestVersion')).called(1);
        verify(
          () => pubUpdater.update(
            packageName: packageName,
            versionConstraint: latestVersion,
          ),
        ).called(1);
      },
    );

    test('keeps a local version ahead of the published one', () async {
      when(() => pubUpdater.getLatestVersion(any()))
          .thenAnswer((_) async => '0.0.1');

      expect(await commandRunner.run(['update']), ExitCode.success.code);
      verifyNever(
        () => pubUpdater.update(
          packageName: any(named: 'packageName'),
          versionConstraint: any(named: 'versionConstraint'),
        ),
      );
    });

    test('rejects malformed registry versions without installing', () async {
      when(() => pubUpdater.getLatestVersion(any()))
          .thenAnswer((_) async => 'invalid');

      expect(await commandRunner.run(['update']), ExitCode.software.code);
      verifyNever(
        () => pubUpdater.update(
          packageName: any(named: 'packageName'),
          versionConstraint: any(named: 'versionConstraint'),
        ),
      );
    });

    test(
      'does not update when already on latest version',
      () async {
        when(
          () => pubUpdater.getLatestVersion(any()),
        ).thenAnswer((_) async => packageVersion);
        when(() => logger.progress(any())).thenReturn(_MockProgress());
        final result = await commandRunner.run(['update']);
        expect(result, equals(ExitCode.success.code));
        verify(
          () => logger.info('CLI is already at the latest version.'),
        ).called(1);
        verifyNever(() => logger.progress('Updating to $latestVersion'));
        verifyNever(
          () => pubUpdater.update(
            packageName: any(named: 'packageName'),
            versionConstraint: any(named: 'versionConstraint'),
          ),
        );
      },
    );
  });
}
