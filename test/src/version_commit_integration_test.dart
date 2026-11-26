@Timeout(Duration(minutes: 2))
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory root;
  late Directory repo;
  late Directory caller;
  late File pubspec;
  late File notes;

  // Keep the test independent of the machine's user identity and Git hooks.
  final env = {
    for (final role in ['AUTHOR', 'COMMITTER']) ...{
      'GIT_${role}_NAME': Platform.environment['GIT_${role}_NAME'] ?? 'Test',
      'GIT_${role}_EMAIL':
          Platform.environment['GIT_${role}_EMAIL'] ?? 'test@example.invalid',
    },
    'CI': 'true',
    'GIT_CONFIG_GLOBAL': Platform.isWindows ? 'NUL' : '/dev/null',
    'GIT_CONFIG_NOSYSTEM': '1',
  };

  Future<String> git(List<String> args) async {
    final result = await Process.run(
      'git',
      args,
      workingDirectory: repo.path,
      environment: env,
    );
    expect(
      result.exitCode,
      0,
      reason: 'git ${args.join(' ')}: ${result.stderr}',
    );
    return result.stdout as String;
  }

  Future<ProcessResult> cli(Directory cwd, List<String> args) => Process.run(
        Platform.resolvedExecutable,
        [
          '--packages=${p.absolute('.dart_tool/package_config.json')}',
          p.absolute('bin/version_assist.dart'),
          ...args,
          '--path',
          p.relative(pubspec.path, from: cwd.path),
        ],
        workingDirectory: cwd.path,
        environment: env,
      );

  setUp(() async {
    root = Directory.systemTemp.createTempSync('version_assist_git_');
    addTearDown(() => root.deleteSync(recursive: true));
    repo = Directory(p.join(root.path, 'repo'))..createSync();
    caller = Directory(p.join(root.path, 'caller'))..createSync();
    final app = Directory(p.join(repo.path, 'apps', 'demo'))
      ..createSync(recursive: true);
    pubspec = File(p.join(app.path, 'pubspec.yaml'))
      ..writeAsStringSync("version: '1.0.0' # app\n");
    notes = File(p.join(repo.path, 'NOTES'))..writeAsStringSync('original\n');
    await git(['init', '--quiet']);
    await git(['add', '.']);
    await git(['commit', '-qm', 'fixture']);
  });

  test(
      'auto-commit from outside the repository includes the new version and only staged changes',
      () async {
    pubspec.writeAsStringSync('version: 1.1.0\n');
    notes.writeAsStringSync('staged\n');
    await git(['add', '.']);
    notes.writeAsStringSync('unstaged\n');

    final result = await cli(caller, ['set', '-v', '2.0.0+7', '--auto-commit']);
    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(
      await git(['show', '2.0.0+7:apps/demo/pubspec.yaml']),
      'version: 2.0.0+7\n',
    );
    expect(await git(['show', '2.0.0+7:NOTES']), 'staged\n');
    expect(await git(['status', '--porcelain']), ' M NOTES\n');
    expect(
      await git(['rev-parse', 'HEAD']),
      await git(['rev-parse', '2.0.0+7']),
    );
  });

  test('an existing tag leaves HEAD and the index untouched', () async {
    await git(['tag', '2.0.0']);
    pubspec.writeAsStringSync('version: 2.0.0\n');
    final head = await git(['rev-parse', 'HEAD']);
    final result = await cli(repo, ['commit']);
    expect(result.exitCode, isNot(0));
    expect(result.stderr.toString(), contains('2.0.0'));
    expect(await git(['rev-parse', 'HEAD']), head);
    expect(await git(['diff', '--cached']), isEmpty);
  });
}
