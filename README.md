# version_assist

Update the version in a Dart or Flutter project's `pubspec.yaml` from the command line.

[![pub.dev][pub_version_badge]](https://pub.dev/packages/version_assist)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## Quick start

In a project with a `version:` in its `pubspec.yaml`, install the CLI and preview the next patch:

```sh
dart pub global activate version_assist
dart pub global run version_assist:version_assist bump --patch --dry-run
```

For a project at `1.2.3`, the preview shows `1.2.4` and leaves the file alone.
Remove `--dry-run` to write the new version. If your [pub cache's bin directory](https://dart.dev/tools/pub/cmd/pub-global#running-a-script-from-your-path)
is on your PATH, you can use the shorter `version_assist` command below.

## Usage

| Command | Result |
| --- | --- |
| `version_assist bump --minor` | Change `1.2.3` to `1.3.0`. Use `--major` or `--patch` for the other increments. |
| `version_assist bump --add-build-number` | Change `1.2.3` to `1.2.3+1`. An existing numeric build increases by one. |
| `version_assist bump --date-based-build-number` | Use today's date and a daily counter for the build number. |
| `version_assist bump --no-build-number` | Drop the build suffix. |
| `version_assist set --version 2.0.0+7` | Write that exact version. |
| `version_assist badge` | Update the `[pub_version_badge]` reference in the README. See the end of [this file's source](https://github.com/kuyazee/version_assist/blob/main/README.md) for the badge format. |
| `version_assist commit` | Stage the pubspec, commit the index and create a local tag such as `2.0.0+7`. |
| `version_assist update` | Update the globally installed CLI. |

Use `--path` with `bump`, `set` or `commit` to target another pubspec.
For `badge`, use `--pubspec-path` and `--readme-path`.
Each of these commands accepts `--dry-run`.

## Use a date as the app version

To use the local date for both the app version and the build number, run:

```sh
version_assist bump --date-based-version --date-based-build-number
```

On May 10, 2025, the first build would be `25.05.10+25051000`. Run it
again that day for `25.05.10+25051001`. Use `--date-based-version` on its
own if you only want the app version to follow the calendar. For packages
you publish to pub.dev, stick to semantic versions without leading zeros.

## Platform support and limits

The CLI runs on the Dart VM with Dart 3.5 or later in the 3.x series.
Flutter isn't required. Versions use `major.minor.patch` with an optional
numeric `+build` suffix. Prerelease labels are unsupported.

Git must be installed for `commit` or `--auto-commit`. Both include files
you've already staged and create a tag without a leading `v`. Check
`git diff --cached` first. Neither command pushes to a remote.

## Contributing

```sh
git clone https://github.com/kuyazee/version_assist.git
cd version_assist
dart pub get
dart format --output=none --set-exit-if-changed bin lib test example
dart analyze --fatal-infos
dart test
```

See the [testing guide](doc/testing.md) for coverage and the [release guide](doc/releasing.md) for package updates.

## Licence

[MIT](LICENSE)

[pub_version_badge]: https://img.shields.io/badge/pub-v1.4.0-blue
