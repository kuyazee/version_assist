import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;
import 'package:version_assist/src/commands/commit_command.dart';
import 'package:version_assist/src/git_client.dart';
import 'package:version_assist/src/manifest_version.dart';

/// {@template version_bump_command}
/// A command which updates the version in pubspec.yaml
/// {@endtemplate}
class VersionBumpCommand extends Command<int> {
  /// {@macro version_bump_command}
  VersionBumpCommand({
    required Logger logger,
    GitClient? gitClient,
    DateTime Function() now = DateTime.now,
  })  : _now = now,
        _logger = logger,
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
      )
      ..addFlag(
        'date-based-version',
        help: 'Set the app version to the local date (yy.MM.dd)',
        negatable: false,
      )
      ..addFlag(
        'date-based-build-number',
        abbr: 'b',
        help: 'Use date-based build number format (yymmddbn)',
        negatable: false,
      )
      ..addFlag(
        'add-build-number',
        help: 'Add or update build number',
        negatable: false,
      )
      ..addFlag(
        'no-build-number',
        help: 'Remove build number from version',
        negatable: false,
      )
      ..addFlag(
        'major',
        help: 'Bump major version (x.0.0)',
        negatable: false,
      )
      ..addFlag(
        'minor',
        help: 'Bump minor version (0.x.0)',
        negatable: false,
      )
      ..addFlag(
        'patch',
        help: 'Bump patch version (0.0.x)',
        negatable: false,
      )
      ..addFlag(
        'auto-commit',
        help: 'Automatically commit and tag the version bump',
      );
  }

  final DateTime Function() _now;
  final Logger _logger;
  final GitClient? _gitClient;

  @override
  String get description => 'Updates the version in pubspec.yaml';

  @override
  String get name => 'bump';

  String _calendarVersion(DateTime date) {
    String digits(int value) => value.toString().padLeft(2, '0');
    return '${digits(date.year % 100)}.${digits(date.month)}.${digits(date.day)}';
  }

  String? _dailyBuild(String? current, String datePrefix) {
    if (current == null ||
        current.length != 8 ||
        !current.startsWith(datePrefix)) {
      return '${datePrefix}00';
    }
    final next = int.parse(current.substring(6)) + 1;
    if (next > 99) return null;
    return '$datePrefix${next.toString().padLeft(2, '0')}';
  }

  /// Bumps the version number based on semver rules
  String _bumpVersion(
    String version, {
    bool major = false,
    bool minor = false,
    bool patch = false,
  }) {
    final parts = version.split('.');
    if (parts.length != 3) {
      throw FormatException('Invalid version format: $version');
    }

    var majorVersion = BigInt.parse(parts[0]);
    var minorVersion = BigInt.parse(parts[1]);
    var patchVersion = BigInt.parse(parts[2]);

    if (major) {
      majorVersion += BigInt.one;
      minorVersion = BigInt.zero;
      patchVersion = BigInt.zero;
    } else if (minor) {
      minorVersion += BigInt.one;
      patchVersion = BigInt.zero;
    } else if (patch) {
      patchVersion += BigInt.one;
    }

    return '$majorVersion.$minorVersion.$patchVersion';
  }

  @override
  Future<int> run() async {
    try {
      final pubspecPath = argResults?['path'] as String;
      final isDryRun = argResults?['dry-run'] as bool;
      final calendarVersion = argResults?['date-based-version'] as bool;
      final isDateBased = argResults?['date-based-build-number'] as bool;
      final isMajor = argResults?['major'] as bool;
      final isMinor = argResults?['minor'] as bool;
      final isPatch = argResults?['patch'] as bool;
      final addBuildNumber = argResults?['add-build-number'] as bool;
      final noBuildNumber = argResults?['no-build-number'] as bool;
      final autoCommit = argResults?['auto-commit'] as bool;

      // Validate version bump flags
      final versionFlagCount =
          [isMajor, isMinor, isPatch].where((f) => f).length;
      if (versionFlagCount > 1) {
        _logger
            .err('Only one of --major, --minor, or --patch can be specified');
        return ExitCode.usage.code;
      }

      if (calendarVersion && versionFlagCount > 0) {
        _logger.err(
          'Use --date-based-version without --major, --minor or --patch',
        );
        return ExitCode.usage.code;
      }

      // Validate build number flags
      if (isDateBased && noBuildNumber) {
        _logger.err(
          'Cannot use --date-based-build-number with --no-build-number',
        );
        return ExitCode.usage.code;
      }

      if (addBuildNumber && noBuildNumber) {
        _logger.err(
          'Cannot use --add-build-number with --no-build-number',
        );
        return ExitCode.usage.code;
      }

      // Read the current pubspec file
      final file = File(pubspecPath);
      if (!await file.exists()) {
        _logger.err('pubspec.yaml not found at $pubspecPath');
        return ExitCode.usage.code;
      }

      final content = await file.readAsString();

      final manifestVersion = ManifestVersion.parse(content);
      if (manifestVersion == null) {
        _logger.err('Could not find valid version pattern in pubspec.yaml');
        return ExitCode.usage.code;
      }

      final parts = manifestVersion.value.split('+');
      final baseVersion = parts.first;
      final currentBuildNumber = parts.length == 2 ? parts.last : null;
      final hasBuildNumber = currentBuildNumber != null;

      // Use one local date for both halves if a build spans midnight.
      final today = _calendarVersion(_now());
      var newBaseVersion = baseVersion;
      if (calendarVersion) {
        newBaseVersion = today;
      } else if (versionFlagCount > 0) {
        newBaseVersion = _bumpVersion(
          baseVersion,
          major: isMajor,
          minor: isMinor,
          patch: isPatch,
        );
      }

      // Determine if we should include a build number in the new version
      final includeBuildNumber = !noBuildNumber &&
          (hasBuildNumber || // Keep existing build number
              isDateBased || // Add date-based build number
              addBuildNumber // Explicitly add build number
          );

      String newVersion;
      if (includeBuildNumber) {
        final newBuildNumber = isDateBased
            ? _dailyBuild(currentBuildNumber, today.replaceAll('.', ''))
            : hasBuildNumber
                ? (BigInt.parse(currentBuildNumber) + BigInt.one).toString()
                : '1';
        if (newBuildNumber == null) {
          _logger.err('Daily build limit reached: the counter ends at 99.');
          return ExitCode.usage.code;
        }
        newVersion = '$newBaseVersion+$newBuildNumber';
      } else {
        newVersion = newBaseVersion;
      }

      // Replace the version in the content
      final newContent = manifestVersion.replaceIn(content, newVersion);

      if (isDryRun) {
        final currentVersion =
            hasBuildNumber ? '$baseVersion+$currentBuildNumber' : baseVersion;
        _logger.info(
          'Would bump version from $currentVersion to $newVersion',
        );
        return ExitCode.success.code;
      }

      // Write back to file
      await file.writeAsString(newContent);
      _logger.success('Successfully bumped version to $newVersion');

      // Handle auto-commit if enabled
      if (autoCommit) {
        final commitCommand = CommitCommand(
          logger: _logger,
          gitClient: _gitClient,
        );
        final commitResult = await commitCommand.runWith(
          pubspecPath: pubspecPath,
          isDryRun: isDryRun,
        );
        if (commitResult != ExitCode.success.code) {
          return commitResult;
        }
      }

      return ExitCode.success.code;
    } on Exception catch (error) {
      _logger.err('$error');
      return ExitCode.software.code;
    }
  }
}
