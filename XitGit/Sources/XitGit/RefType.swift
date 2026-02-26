import Foundation

public enum RefType
{
  case branch
  case activeBranch
  case remoteBranch
  case tag
  case remote
  case unknown

  public init(refName: String, currentBranch: String)
  {
    guard let (typeName, displayName) = refName.splitRefName()
    else {
      self = .unknown
      return
    }
    
    switch typeName {
      case "refs/heads/":
        self = displayName == currentBranch ? .activeBranch : .branch
      case "refs/remotes/":
        self = .remoteBranch
      case "refs/tags/":
        self = .tag
      default:
        self = .unknown
    }
  }
  
  public var isBranch: Bool
  {
    switch self {
      case .branch, .activeBranch, .remoteBranch:
        return true
      default:
        return false
    }
  }
}
