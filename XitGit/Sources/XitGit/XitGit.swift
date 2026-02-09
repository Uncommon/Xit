import Clibgit2

public struct XitGit {
    public private(set) var text = "Hello, World!"

    public init() {
        // Just checking if we can access a symbol from git2
        // git_libgit2_init() is a function in git2.h
        // but it might not be available if not linked?
        // At compile time, we just need headers.
        // git_libgit2_init()
    }
}
