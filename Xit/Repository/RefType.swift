import Foundation

enum RefType
{
  case branch
  case activeBranch
  case remoteBranch
  case tag
  case remote
  case unknown

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
