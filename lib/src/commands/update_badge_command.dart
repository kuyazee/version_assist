import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;
import 'package:version_assist/src/manifest_version.dart';

/// {@template update_badge_command}
/// A command which updates version badges in README.md
/// {@endtemplate}
class UpdateBadgeCommand extends Command<int> {
  /// {@macro update_badge_command}
  UpdateBadgeCommand({
    required Logger logger,
  }) : _logger = logger {
    argParser
      ..addOption(
        'pubspec-path',
        abbr: 'p',
        help: 'Path to pubspec.yaml',
        defaultsTo: path.join('pubspec.yaml'),
      )
      ..addOption(
        'readme-path',
        abbr: 'r',
        help: 'Path to README.md',
        defaultsTo: path.join('README.md'),
      )
      ..addFlag(
        'dry-run',
        abbr: 'd',
        help: 'Show what would happen without making changes',
        negatable: false,
      );
  }

  final Logger _logger;

  @override
  String get description => 'Updates version badges in README.md';

  @override
  String get name => 'badge';

  static final _badge = RegExp(
    r'^ {0,3}\[pub_version_badge\]:[ \t]+https://img\.shields\.io/badge/pub-v'
    r'(\d+\.\d+\.\d+(?:\+\d+)?)(?=-blue\b)',
    multiLine: true,
  );

  @override
  Future<int> run() async {
    try {
      final pubspecPath = argResults?['pubspec-path'] as String;
      final readmePath = argResults?['readme-path'] as String;
      final isDryRun = argResults?['dry-run'] as bool;

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

      // Read README.md
      final readmeFile = File(readmePath);
      if (!await readmeFile.exists()) {
        _logger.err('README.md not found at $readmePath');
        return ExitCode.usage.code;
      }

      final readmeContent = await readmeFile.readAsString();
      final match = _badge.firstMatch(readmeContent);
      if (match == null) {
        _logger.err(
          'Could not find the [pub_version_badge] reference in $readmePath',
        );
        return ExitCode.usage.code;
      }
      final currentVersion = match.group(1)!;
      if (currentVersion == version) {
        _logger.info('Version badge is already v$version');
        return ExitCode.success.code;
      }

      if (isDryRun) {
        _logger.info('Would update version badge to v$version');
        return ExitCode.success.code;
      }

      // Write updated README.md
      await readmeFile.writeAsString(
        readmeContent.replaceRange(
          match.end - currentVersion.length,
          match.end,
          version,
        ),
      );
      _logger.success('Successfully updated version badge to v$version');

      return ExitCode.success.code;
    } on Exception catch (error) {
      _logger.err('$error');
      return ExitCode.software.code;
    }
  }
}
