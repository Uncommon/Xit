import XCTest
@testable import Xit

final class OperationTests: XTTest
{
  func testCheckOutRemote() throws
  {
    let branchName: LocalBranchRefName = "branch"

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
      RemoteBranchRefName(remote: "origin", branch: branchName.name))
    let operation = CheckOutRemoteOperation(repository: repository,
                                            remoteBranch: remoteBranchName)
    let model = CheckOutRemotePanel.Model()
    
    model.branchName = branchName.name
    model.checkOut = true
    
    try operation.perform(using: model)
    
    let currentBranch = repository.currentBranch
    
    XCTAssertEqual(currentBranch?.name, branchName.name)
  }
  
  func testNewBranch() throws
  {
    let operation = NewBranchOperation(repository: repository)
    let parameters = NewBranchOperation.Parameters(
          name: "branch",
          startPoint: "master",
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
          startPoint: "master",
          track: true,
          checkOut: false)
    
    try operation.perform(using: parameters)

    XCTAssertEqual(repository.currentBranch?.name, "master")
    XCTAssertNotNil(repository.localBranch(named: .named("branch")!))
  }
}
