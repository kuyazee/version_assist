import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;
import 'package:version_assist/src/git_client.dart';
import 'package:version_assist/src/manifest_version.dart';

/// {@template commit_command}
/// A command which creates a version commit and tag
/// {@endtemplate}
class CommitCommand extends Command<int> {
  /// {@macro commit_command}
  CommitCommand({
    required Logger logger,
    GitClient? gitClient,
  })  : _logger = logger,
        _gitClient = gitClient {
    argParser
      ..addOption(
        'path',
        abbr: 'p',
        help: 'Path to pubspec.yaml',
        defaultsTo: path.join('pubspec.yaml'),
      )
      ..addFlag(
        'dry-run',
        abbr: 'd',
        help: 'Show what would happen without making changes',
        negatable: false,
      );
  }

  final Logger _logger;
  final GitClient? _gitClient;

  @override
  String get description => 'Creates a version commit and tag';

  @override
  String get name => 'commit';

  /// Runs the commit command with explicit parameters
  /// This allows other commands to use the commit functionality directly
  Future<int> runWith({
    required String pubspecPath,
    bool isDryRun = false,
  }) async {
    try {
      // Read pubspec.yaml
      final pubspecFile = File(pubspecPath);
      if (!await pubspecFile.exists()) {
        _logger.err('pubspec.yaml not found at $pubspecPath');
        return ExitCode.usage.code;
      }

      final pubspecContent = await pubspecFile.readAsString();
      final version = ManifestVersion.parse(pubspecContent)?.value;

      if (version == null) {
        _logger.err('Could not find valid version in pubspec.yaml');
        return ExitCode.usage.code;
      }

      if (isDryRun) {
        _logger
          ..info('Would create commit with message:')
          ..info('build(version): Bump version to $version')
          ..info('Would create tag: $version');
        return ExitCode.success.code;
      }

      final git = _gitClient ??
          GitClient(workingDirectory: pubspecFile.absolute.parent.path);
      final existingTag = await git.listTags(version);
      if (existingTag.exitCode != 0) {
        _logger.err('Error checking git tag: ${existingTag.stderr}');
        return ExitCode.software.code;
      }
      if ((existingTag.stdout as String).trim().isNotEmpty) {
        _logger.err('Git tag $version already exists');
        return ExitCode.software.code;
      }

      // Refresh the index even if an older version of the file was staged.
      final gitAdd = await git.stageFile(pubspecFile.absolute.path);
      if (gitAdd.exitCode != 0) {
        _logger.err('Error during git add: ${gitAdd.stderr as String}');
        return ExitCode.software.code;
      }

      final commitMessage = 'build(version): Bump version to $version';
      final gitCommit = await git.commit(commitMessage);

      if (gitCommit.exitCode != 0) {
        _logger.err('Error during git commit: ${gitCommit.stderr as String}');
        return ExitCode.software.code;
      }

      final gitTag = await git.tag(version);

      if (gitTag.exitCode != 0) {
        _logger.err('Error during git tag: ${gitTag.stderr as String}');
        return ExitCode.software.code;
      }

      _logger
          .success('Successfully created version commit and tag for $version');
      return ExitCode.success.code;
    } on Exception catch (error) {
      _logger.err('$error');
      return ExitCode.software.code;
    }
  }

  @override
  Future<int> run() async {
    final args = argResults;
    if (args == null) {
      _logger.err('No arguments provided');
      return ExitCode.usage.code;
    }

    return runWith(
      pubspecPath: args['path'] as String,
      isDryRun: args['dry-run'] as bool,
    );
  }
}
