import XCTest
@testable import Xit

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

    let localBranch = try XCTUnwrap(repository.localBranch(named: "master"))
    let remoteBranch = try XCTUnwrap(repository.remoteBranch(named: "master",
                                                             remote: "origin"))
    
    XCTAssertEqual(localBranch.name, "refs/heads/master")
    XCTAssertEqual(localBranch.shortName, "master")
    XCTAssertEqual(localBranch.strippedName, "master")
    
    XCTAssertEqual(remoteBranch.name, "refs/remotes/origin/master")
    XCTAssertEqual(remoteBranch.shortName, "origin/master")
    XCTAssertEqual(remoteBranch.strippedName, "master")
  }
}
