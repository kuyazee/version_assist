import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:cli_completion/cli_completion.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:pub_updater/pub_updater.dart';
import 'package:version_assist/src/commands/commands.dart';
import 'package:version_assist/src/git_client.dart';
import 'package:version_assist/src/version.dart';

const executableName = 'version_assist';
const packageName = 'version_assist';
const description = 'Manage version numbers in Dart and Flutter projects.';

/// {@template version_assist_command_runner}
/// A [CommandRunner] for the CLI.
///
/// ```bash
/// $ version_assist --version
/// ```
/// {@endtemplate}
class VersionAssistCommandRunner extends CompletionCommandRunner<int> {
  /// {@macro version_assist_command_runner}
  VersionAssistCommandRunner({
    Logger? logger,
    PubUpdater? pubUpdater,
    GitClient? gitClient,
  })  : _logger = logger ?? Logger(),
        _pubUpdater = pubUpdater ?? PubUpdater(),
        super(executableName, description) {
    // Add root options and flags
    argParser
      ..addFlag(
        'version',
        abbr: 'v',
        negatable: false,
        help: 'Print the current version.',
      )
      ..addFlag(
        'verbose',
        help: 'Noisy logging, including all shell commands executed.',
      );

    // Add sub commands
    addCommand(UpdateCommand(logger: _logger, pubUpdater: _pubUpdater));
    addCommand(VersionBumpCommand(logger: _logger, gitClient: gitClient));
    addCommand(VersionSetCommand(logger: _logger, gitClient: gitClient));
    addCommand(UpdateBadgeCommand(logger: _logger));
    addCommand(CommitCommand(logger: _logger, gitClient: gitClient));
  }

  @override
  void printUsage() => _logger.info(usage);

  final Logger _logger;
  final PubUpdater _pubUpdater;
  bool _autoInstallCompletion = false;

  @override
  bool get enableAutoInstall => _autoInstallCompletion;

  @override
  Future<int> run(Iterable<String> args) async {
    try {
      final topLevelResults = parse(args);
      if (topLevelResults['verbose'] == true) {
        _logger.level = Level.verbose;
      }
      return await runCommand(topLevelResults) ?? ExitCode.success.code;
    } on FormatException catch (e, stackTrace) {
      // On format errors, show the commands error message, root usage and
      // exit with an error code
      _logger
        ..err(e.message)
        ..err('$stackTrace')
        ..info('')
        ..info(usage);
      return ExitCode.usage.code;
    } on UsageException catch (e) {
      // On usage errors, show the commands usage message and
      // exit with an error code
      _logger
        ..err(e.message)
        ..info('')
        ..info(e.usage);
      return ExitCode.usage.code;
    }
  }

  @override
  Future<int?> runCommand(ArgResults topLevelResults) async {
    // Fast track completion command
    if (topLevelResults.command?.name == 'completion') {
      await super.runCommand(topLevelResults);
      return ExitCode.success.code;
    }

    // Verbose logs
    _logger
      ..detail('Argument information:')
      ..detail('  Top level options:');
    for (final option in topLevelResults.options) {
      if (topLevelResults.wasParsed(option)) {
        _logger.detail('  - $option: ${topLevelResults[option]}');
      }
    }
    if (topLevelResults.command != null) {
      final commandResult = topLevelResults.command!;
      _logger
        ..detail('  Command: ${commandResult.name}')
        ..detail('    Command options:');
      for (final option in commandResult.options) {
        if (commandResult.wasParsed(option)) {
          _logger.detail('    - $option: ${commandResult[option]}');
        }
      }
    }

    if (topLevelResults['version'] == true) {
      _logger.info(packageVersion);
      return ExitCode.success.code;
    }

    final command = topLevelResults.command;
    final interactiveCommand = command != null &&
        command.name != 'help' &&
        topLevelResults['help'] != true &&
        command['help'] != true &&
        stdin.hasTerminal &&
        stdout.hasTerminal &&
        !(environmentOverride ?? Platform.environment).containsKey('CI');

    // The completion runner consults this flag before it dispatches the command.
    _autoInstallCompletion = interactiveCommand;
    final exitCode = await super.runCommand(topLevelResults);
    if (interactiveCommand &&
        exitCode == ExitCode.success.code &&
        command.name != UpdateCommand.commandName) {
      await _checkForUpdates();
    }

    return exitCode;
  }

  Future<void> _checkForUpdates() async {
    try {
      final latestVersion = await _pubUpdater
          .getLatestVersion(packageName)
          .timeout(const Duration(seconds: 1));
      if (Version.parse(latestVersion) > Version.parse(packageVersion)) {
        _logger
          ..info('')
          ..info(
            '''
${lightYellow.wrap('Update available!')} ${lightCyan.wrap(packageVersion)} \u2192 ${lightCyan.wrap(latestVersion)}
Run ${lightCyan.wrap('$executableName update')} to update''',
          );
      }
    } on Object {
      // A failed update lookup must not change the command's result.
    }
  }
}
