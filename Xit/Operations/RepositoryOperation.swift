import Foundation

/// Encapsulates a higher-level repository action.
protocol RepositoryOperation
{
  associatedtype Repository
  associatedtype Parameters
  
  var repository: Repository { get }
  
  func perform(using parameters: Parameters) throws
}

/// Creates a local copy of a remate branch, and optionally checks it out.
struct CheckOutRemoteOperation: RepositoryOperation
{
  let repository: any Workspace & Branching
  let remoteBranch: RemoteBranchRefName
  
  func perform(using parameters: CheckOutRemotePanel.Model) throws
  {
    if let branchName = LocalBranchRefName.named(parameters.branchName),
       let branch = try repository.createBranch(named: branchName,
                                                target: remoteBranch) {
      branch.trackingBranchName = remoteBranch
      if parameters.checkOut {
        try repository.checkOut(branch: branchName)
      }
    }
    else {
      throw RepoError.unexpected // could not resolve target
    }
  }
}

/// Creates a new local branch, and optionally checks it out.
struct NewBranchOperation: RepositoryOperation
{
  let repository: any Branching & Workspace
  
  struct Parameters
  {
    let name: String
    let startPoint: String
    let track: Bool
    let checkOut: Bool
  }
  
  func perform(using parameters: Parameters) throws
  {
    guard let branchName = LocalBranchRefName.named(parameters.name),
          let target = LocalBranchRefName.named(parameters.startPoint),
          let branch = try repository.createBranch(named: branchName,
                                                   target: target)
    else { throw RepoError.unexpected }
    
    if parameters.track {
      branch.trackingBranchName = LocalBranchRefName.named(parameters.startPoint)
    }
    if parameters.checkOut {
      try repository.checkOut(branch: branchName)
    }
  }
}
