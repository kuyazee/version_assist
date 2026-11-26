# Releasing version_assist

1. Check the [published versions](https://pub.dev/packages/version_assist/versions). For a patch, run `make patch_bump`. For another version, run `dart run bin/version_assist.dart set --version X.Y.Z`, then `dart run build_runner build` and `dart run bin/version_assist.dart badge`.
2. Add the version to the changelog. Check the formatter, analyzer, tests and `dart pub publish --dry-run`.
3. Commit the version, generated CLI version, README badge and changelog together as `build(version): X.Y.Z`. Push to main.
4. Create a GitHub release on that commit with a new `vX.Y.Z` tag. The CLI's own `commit` command creates an unprefixed tag, which does not trigger publishing.
5. Watch the Publish workflow and confirm the new version on pub.dev.

Before the first automated upload, enable GitHub Actions publishing in the
[package settings](https://pub.dev/packages/version_assist/admin) for
`kuyazee/version_assist`, tag pattern `v{{version}}`, on tag pushes.
