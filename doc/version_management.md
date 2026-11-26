# Version numbers

Run these commands from a project with a top-level `version:` in its pubspec.
Use `--path path/to/pubspec.yaml` to choose a different file. Add `--dry-run`
to preview a change without writing the file or calling Git.

## Choose a version

| Command | Before | After |
| --- | --- | --- |
| `version_assist bump --major` | `1.2.3` | `2.0.0` |
| `version_assist bump --minor` | `1.2.3` | `1.3.0` |
| `version_assist bump --patch` | `1.2.3+7` | `1.2.4+8` |
| `version_assist bump --add-build-number` | `1.2.3` | `1.2.3+1` |
| `version_assist bump --no-build-number` | `1.2.3+7` | `1.2.3` |
| `version_assist set --version 2.1.0+42` | `1.2.3` | `2.1.0+42` |

A bare `bump` increments an existing build number. With no build number or
version flag, the version stays the same. To keep a particular suffix when
changing the base version, use `set` with the full version you want.

## Calendar versions for apps

On May 10, 2025, starting at `1.2.3`:

| Flags for `version_assist bump` | Result |
| --- | --- |
| `--date-based-version` | `25.05.10` |
| `--date-based-build-number` | `1.2.3+25051000` |
| `--date-based-version --date-based-build-number` | `25.05.10+25051000` |

Both flags use the local date. A date-based build counts from `00` to `99`
on the same day and starts at `00` on a new day. After `99` the command
returns an error and leaves the file alone.

Choose one of `--date-based-version`, `--major`, `--minor` or `--patch`.
For pub.dev releases, use semantic versions without leading zeros.

## Commit and tag

```sh
version_assist set --version 2.1.0 --auto-commit
```

This stages the pubspec, commits it along with anything already staged and
creates the local tag `2.1.0`. It does not push. Use `git diff --cached` to
inspect the index first. If you prefer separate steps, change the version
without `--auto-commit`, review it, then run `version_assist commit`.
