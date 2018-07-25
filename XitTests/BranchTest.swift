import XCTest
@testable import Xit

class BranchTest: XTTest
{
  func testBranchNames()
  {
    let remoteName = "origin"
    
    remoteRepoPath = repoPath.deletingLastPathComponent
                             .appending(pathComponent: "remotetestrepo")
    try? FileManager.default.removeItem(atPath: remoteRepoPath)

    // Remote must have the same content so the fetch will succeed
    XCTAssertNoThrow(
      try FileManager.default.copyItem(atPath: repoPath, toPath: remoteRepoPath))
    XCTAssertNoThrow(
      try repository.addRemote(named: remoteName,
                               url: URL(fileURLWithPath: remoteRepoPath)))
    
    guard let remote = repository.remote(named: "origin")
    else {
      XCTFail("can't get remote")
      return
    }
    let options = XTRepository.FetchOptions(downloadTags: false,
                                            pruneBranches: false,
                                            passwordBlock: { nil },
                                            progressBlock: { _ in true })
    
    XCTAssertNoThrow(try repository.fetch(remote: remote, options: options))

    guard let localBranch = repository.localBranch(named: "master")
    else {
      XCTFail("can't get local branch")
      return
    }
    guard let remoteBranch = repository.remoteBranch(named: "master",
                                                     remote: "origin")
    else {
      XCTFail("can't get remote branch")
      return
    }
    
    XCTAssertEqual(localBranch.name, "refs/heads/master")
    XCTAssertEqual(localBranch.shortName, "master")
    XCTAssertEqual(localBranch.strippedName, "master")
    
    XCTAssertEqual(remoteBranch.name, "refs/remotes/origin/master")
    XCTAssertEqual(remoteBranch.shortName, "origin/master")
    XCTAssertEqual(remoteBranch.strippedName, "master")
  }
}
