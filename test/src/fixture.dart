import 'dart:io';

import 'package:mocktail/mocktail.dart';
import 'package:pub_updater/pub_updater.dart';
import 'package:version_assist/src/command_runner.dart';
import 'package:version_assist/src/git_client.dart';
import 'package:version_assist/src/version.dart';

class _MockGit extends Mock implements GitClient {}

class _MockUpdater extends Mock implements PubUpdater {}

class CommandFixture {
  CommandFixture() {
    when(() => updater.getLatestVersion(any()))
        .thenAnswer((_) async => packageVersion);
    when(() => git.listTags(any()))
        .thenAnswer((_) async => ProcessResult(0, 0, '', ''));
    when(() => git.stageFile(any()))
        .thenAnswer((_) async => ProcessResult(0, 0, '', ''));
    when(() => git.commit(any()))
        .thenAnswer((_) async => ProcessResult(0, 0, '', ''));
    when(() => git.tag(any()))
        .thenAnswer((_) async => ProcessResult(0, 0, '', ''));
  }

  final directory = Directory.systemTemp.createTempSync('version_assist_');
  final GitClient git = _MockGit();
  final PubUpdater updater = _MockUpdater();
  File get pubspec => File('${directory.path}/pubspec.yaml');
  File get readme => File('${directory.path}/README.md');

  Future<int> run(VersionAssistCommandRunner runner, List<String> args) =>
      runner.run([
        ...args,
        if (args.first == 'badge') ...[
          '--readme-path',
          readme.path,
          '--pubspec-path',
        ] else
          '--path',
        pubspec.path,
      ]);

  void dispose() => directory.deleteSync(recursive: true);
}
