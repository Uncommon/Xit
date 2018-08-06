import Foundation

enum RefType
{
  case branch
  case activeBranch
  case remoteBranch
  case tag
  case remote
  case unknown

  init(refName: String, currentBranch: String)
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
  
  var isBranch: Bool
  {
    switch self {
      case .branch, .activeBranch, .remoteBranch:
        return true
      default:
        return false
    }
  }
  
  var strokeColor: NSColor
  {
    switch self {
      case .branch, .activeBranch:
        return .refTokenStroke(.branch)
      case .remoteBranch:
        return .refTokenStroke(.remoteBranch)
      case .tag:
        return .refTokenStroke(.tag)
      default:
        return .refTokenStroke(.generic)
    }
  }
  
  var gradient: NSGradient
  {
    let type: NSColor.RefGradient
    
    switch self {
      case .branch:
        type = .branch
      case .activeBranch:
        type = .activeBranch
      case .remoteBranch:
        type = .remote
      case .tag:
        type = .tag
      default:
        type = .general
    }
    return NSGradient(starting: NSColor.refGradientStart(type),
                      ending: NSColor.refGradientEnd(type)) ?? NSGradient()
  }
}
