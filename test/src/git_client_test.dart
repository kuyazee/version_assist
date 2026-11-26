import 'dart:io';

import 'package:test/test.dart';
import 'package:version_assist/src/git_client.dart';

void main() {
  test('stages a file in the specified repository', () async {
    final directory =
        await Directory.systemTemp.createTemp('version_assist_git_');
    addTearDown(() => directory.delete(recursive: true));
    final result = await Process.run(
      'git',
      ['init', '--quiet'],
      workingDirectory: directory.path,
    );
    expect(result.exitCode, 0);
    final client = GitClient(workingDirectory: directory.path);
    const filename = '-file[0].yaml';
    await File('${directory.path}/-file0.yaml').writeAsString('leave unstaged');
    await File('${directory.path}/$filename').writeAsString('version: 1.0.0\n');
    expect((await client.stageFile(filename)).exitCode, 0);
    final staged = await Process.run(
      'git',
      ['diff', '--cached', '--name-only'],
      workingDirectory: directory.path,
    );
    expect(staged.stdout, '$filename\n');
  });
}
