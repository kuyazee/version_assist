.PHONY: patch_bump

# Prepare the next patch locally. Review the diff and add a changelog entry.
patch_bump:
	dart run bin/version_assist.dart bump --patch
	dart run build_runner build
	dart run bin/version_assist.dart badge
