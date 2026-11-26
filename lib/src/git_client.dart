import 'dart:io';

/// Runs Git commands in a repository.
class GitClient {
  /// Creates a new [GitClient].
  const GitClient({this.workingDirectory});

  final String? workingDirectory;

  Future<ProcessResult> _run(List<String> args) =>
      Process.run('git', args, workingDirectory: workingDirectory);

  /// Lists tags matching [version].
  Future<ProcessResult> listTags(String version) =>
      _run(['tag', '--list', version]);

  /// Stages only the named file, even if its name contains a pathspec wildcard.
  Future<ProcessResult> stageFile(String filePath) =>
      _run(['--literal-pathspecs', 'add', '--', filePath]);

  /// Commits the index with the given message.
  Future<ProcessResult> commit(String message) =>
      _run(['commit', '-m', message]);

  /// Creates a local tag at HEAD.
  Future<ProcessResult> tag(String tagName) => _run(['tag', tagName]);
}
