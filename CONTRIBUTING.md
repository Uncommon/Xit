## Building

The repository has a submodule, so you will need to clone the repository rather than downloading the source archive. To begin, get the submodule set up with `git submodule update --init --recursive` from the root of the project.

Xit uses libgit2 (currently version 1.3.0) for most Git operations, which it expects to find in /usr/local. You can install it there with [Homebrew]: `brew install libgit2`.

[Homebrew]: http://brew.sh

If you are building on an Apple Silicon computer (eg one with an M1 or M2 processor), you should have the build set to "My Mac" rather than "My Mac (Rosetta)" or "Any Mac". The Rosetta (Intel) build will only work if you also have the Intel versions of the Homebrew-installed libraries, and the libgit2 build script currently doesn't support a universal (Any Mac) build. 

**IMPORTANT:** If you do not have an Apple ID with a developer account for code signing Mac apps, the build  will fail with a code signing error. To work around this, you can delete the "Code Signing Identity" build setting of the "Application" target to work around the issue.

**Alternatively**, if you do have a developer account, you can create the file "Xcode-config/DEVELOPMENT_TEAM.xcconfig" with the following build setting as its content:
> DEVELOPMENT_TEAM = [Your TeamID]

For a more detailed description of this, you can have a look at the comments within the file "Xcode-config/Shared.xcconfig". 

## Finding tasks

If you're looking for a starter task, several issues have been marked "good first issue". These should provide a relatively easy intro to the code base.

For larger tasks, there are two options:

* Plenty of other ideas and plans have been written down in the [Issues] section. Feel free to comment and contribute there.
* Just run the app and see what bugs you!

[Issues]: https://github.com/Uncommon/Xit/issues

If you decide to start working on something, please add a note in the issue (file a new one if needed). When you're ready to share your work (final or not), please follow the usual procedure for a GitHub pull request.

## Coding style

Swift:

A SwiftLint settings file is included, and will be run every build if you have SwiftLint installed.

* Braces at the end of the line for control statements, and on their own line for functions, classes, etc.
* `else` always starts a new line, whether for `guard` or `if`.
* Use blank lines to separate groups of variable declarations (`let` or `var`) or `guard` statements from other statements.
* Wrap to about 80 characters, indenting wrapped code by two levels.
* Indentation level is two spaces.
* Trailing whitespace on blank lines should match the indentation of surrounding lines.
* Otherwise, normal Swift style rules apply.
