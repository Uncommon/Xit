import Testing
@testable import XitGit

@Suite("XitGit basic")
struct XitGitBasicTests {
    @Test("Sanity test builds and runs")
    func sanity() async throws {
        // This test intentionally does very little; it ensures the package links.
        #expect(RepoError.genericGitError.isExpected)
    }
}
