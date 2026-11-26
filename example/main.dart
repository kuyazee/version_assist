import 'package:version_assist/src/command_runner.dart';

/// Preview the next patch without changing the current package.
Future<void> main() async {
  await VersionAssistCommandRunner().run(['bump', '--patch', '--dry-run']);
}
