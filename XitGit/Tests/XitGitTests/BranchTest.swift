import XCTest
@testable import XitGit
import XitGitTestSupport

class BranchTest: XTTest
{
  func testBranchNames() throws
  {
    let remoteName = "origin"
    
    remoteRepoPath = repoPath.deletingLastPathComponent
                             .appending(pathComponent: "remotetestrepo")
    try? FileManager.default.removeItem(atPath: remoteRepoPath)

    // Remote must have the same content so the fetch will succeed
    try FileManager.default.copyItem(atPath: repoPath, toPath: remoteRepoPath)
    try repository.addRemote(named: remoteName,
                               url: URL(fileURLWithPath: remoteRepoPath))
    
    let remote = try XCTUnwrap(repository.remote(named: "origin"), "can't get remote")
    let options = FetchOptions(downloadTags: false,
                               pruneBranches: false,
                               callbacks: RemoteCallbacks(passwordBlock: nil,
                                                          downloadProgress: nil,
                                                          uploadProgress: nil))
    
    try repository.fetch(remote: remote, options: options)

    let localBranch = try XCTUnwrap(repository.localBranch(named: .init("main")!))
    let remoteBranch = try XCTUnwrap(repository.remoteBranch(named: "main",
                                                             remote: "origin"))
    
    XCTAssertEqual(localBranch.referenceName.fullPath, "refs/heads/main")
    XCTAssertEqual(localBranch.referenceName.name, "main")
    XCTAssertEqual(localBranch.referenceName.localName, "main")

    XCTAssertEqual(remoteBranch.referenceName.fullPath, "refs/remotes/origin/main")
    XCTAssertEqual(remoteBranch.referenceName.name, "origin/main")
    XCTAssertEqual(remoteBranch.referenceName.localName, "main")
  }
}
