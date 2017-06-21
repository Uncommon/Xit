## Building

The repository uses several submodules, so you will need to clone the repository rather than downloading the source archive. To begin, get the submodules set up with `git submodule update --init --recursive` from the root of the project. You will also need [CMake] to build libgit2, and [Homebrew] for the other libraries used by Objective Git. If you hit any snags, please file an issue.

[CMake]: http://cmake.org/
[Homebrew]: http://brew.sh

Note that Objective Git needs the `objective-git/script/bootstrap` script to be run to configure everything. If Objective Git is later updated, you may need to re-run the script.

## Finding tasks

If you're looking for a starter task, several issues have been marked "small". These should provide a relatively easy intro to the code base.

For larger tasks, there are two options:

* Plenty of other ideas and plans have been written down in the [Issues] section. Feel free to comment and contribute there.
* Just run the app and see what bugs you!

Swift is preferred for new classes. Xit was originally written in Objective-C, and has been almost completely rewritten in Swift. That way the Swift/Objective-C bridging limitations don't get in the way, and Swift's features can be used to maximum advantage.

[Issues]: https://github.com/Uncommon/Xit/issues

If you decide to start working on something, please add a note in the issue (file a new one if needed). When you're ready to share your work (final or not), please follow the usual procedure for a GitHub pull request.

## Coding style

Swift:

A SwiftLint settings file is included, and will be run every build if you have SwiftLint installed.

* Braces at the end of the line for control statements, and on their own line for functions, classes, etc.
* `else` always starts a new line, whether for `guard` or `if`.
* Use blank lines to separate groups of variable declarations (`let` or `var`), `guard` statements, and other statements.
* Otherwise, normal Swift style rules apply.

For Objective-C, the coding style used is based on the [Google Objective-C Style Guide], with the following changes:

[Google Objective-C Style Guide]: http://google-styleguide.googlecode.com/svn/trunk/objcguide.xml

* Line length is 80 columns.
* The opening brace of a function goes on its own line.
* No single-line `if` statements, like `if (x) return;` (you can't set a breakpoint on that `return`!)
* No space before `*` when it is not immediately followed by an identifier, such as `(NSString*)`.
* When wrapping function/method calls, a four-space indent may be used instead of aligning with the `:` or `(`.
* Variable declarations are separated from other statements by one blank line.
* Whitespace at the indentation level of the surrounding lines is allowed.
* Doxygen style comments are encouraged because Xcode parses them.
* Explicitly compare values with `0`, `nil`, or `NULL`. Only write `if (x)` if `x` is a Boolean value.

Some of the code was written before these rules were put in place and may still need to be updated. Feel free to correct any instances you find.
