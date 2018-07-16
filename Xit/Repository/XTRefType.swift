import Foundation

enum XTRefType
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
        return .branchStroke
      case .remoteBranch:
        return .remoteBranchStroke
      case .tag:
        return .tagStroke
      default:
        return .refStroke
    }
  }
  
  var gradient: NSGradient
  {
    var start, end: NSColor
    
    switch self {
      case .branch:
        start = .branchGradientStart
        end = .branchGradientEnd
      case .activeBranch:
        start = .activeBranchGradientStart
        end = .activeBranchGradientEnd
      case .remoteBranch:
        start = .remoteGradientStart
        end = .remoteGradientEnd
      case .tag:
        start = .tagGradientStart
        end = .tagGradientEnd
      default:
        start = .refGradientStart
        end = .refGradientEnd
    }
    return NSGradient(starting: start, ending: end) ?? NSGradient()
  }
}
