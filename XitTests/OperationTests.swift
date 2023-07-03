import XCTest
@testable import Xit

final class OperationTests: XTTest
{
  func testCheckOutRemote() throws
  {
    let branchName = "branch"
    
    makeRemoteRepo()
    try execute(in: remoteRepository) {
      CommitFiles {
        Write("content", to: .file2)
      }
      CreateBranch(branchName)
    }
    try execute(in: repository) {
      AddRemote(url: URL(fileURLWithPath: remoteRepoPath))
      Fetch()
    }

    let operation = CheckOutRemoteOperation(repository: repository,
                                            remoteName: "origin",
                                            remoteBranch: branchName)
    let model = CheckOutRemotePanel.Model()
    
    model.branchName = branchName
    model.checkOut = true
    
    try operation.perform(using: model)
    
    let localBranch = try XCTUnwrap(repository.localBranch(named: branchName))
    let currentBranch = repository.currentBranch
    
    XCTAssertEqual(currentBranch, branchName)
  }
}
