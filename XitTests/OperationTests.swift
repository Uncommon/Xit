import XCTest
@testable import Xit
@testable import XitGit
import XitGitTestSupport

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

    let remoteBranchName = try XCTUnwrap(
      RemoteBranchRefName(remote: "origin", branch: branchName))
    let operation = CheckOutRemoteOperation(repository: repository,
                                            remoteBranch: remoteBranchName)
    let model = CheckOutRemotePanel.Model()
    
    model.branchName = branchName
    model.checkOut = true
    
    try operation.perform(using: model)
    
    let currentBranch = repository.currentBranch
    
    XCTAssertEqual(currentBranch?.name, branchName)
  }
  
  func testNewBranch() throws
  {
    let operation = NewBranchOperation(repository: repository)
    let parameters = NewBranchOperation.Parameters(
          name: "branch",
          startPoint: "main",
          track: true,
          checkOut: true)
    
    try operation.perform(using: parameters)
    
    XCTAssertEqual(repository.currentBranch?.name, "branch")
  }
  
  func testNewBranchNoCheckout() throws
  {
    let operation = NewBranchOperation(repository: repository)
    let parameters = NewBranchOperation.Parameters(
          name: "branch",
          startPoint: "main",
          track: true,
          checkOut: false)
    
    try operation.perform(using: parameters)

    XCTAssertEqual(repository.currentBranch?.name, "main")
    XCTAssertNotNil(repository.localBranch(named: .init("branch")!))
  }
}
