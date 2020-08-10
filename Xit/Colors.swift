import Foundation

extension NSColor
{
  enum RefTokenStroke
  {
    case branch, remoteBranch, tag, generic, shine
  }
  
  static func refTokenStroke(_ type: RefTokenStroke) -> NSColor
  {
    switch type {
      case .branch:
        return NSColor(named: "branchStroke")!
      case .remoteBranch:
        return NSColor(named: "remoteBranchStroke")!
      case .tag:
        return NSColor(named: "tagStroke")!
      case .generic:
        return NSColor(named: "refStroke")!
      case .shine:
        return NSColor(named: "refShine")!
    }
  }
  
  enum RefTokenText
  {
    case active, activeEmboss, normal, normalEmboss
  }
  
  static func refTokenText(_ type: RefTokenText) -> NSColor
  {
    switch type {
      case .active:
        return NSColor(named: "refActiveText")!
      case .activeEmboss:
        return NSColor(named: "refActiveTextEmboss")!
      case .normal:
        return NSColor(named: "refText")!
      case .normalEmboss:
        return NSColor(named: "refTextEmboss")!
    }
  }
  
  enum RefGradient
  {
    case branch, activeBranch, remote, tag, general
  }
  
  static func refGradientStart(_ type: RefGradient) -> NSColor
  {
    switch type {
      case .branch:
        return NSColor(named: "branchGradientStart")!
      case .activeBranch:
        return NSColor(named: "activeBranchGradientStart")!
      case .remote:
        return NSColor(named: "remoteGradientStart")!
      case .tag:
        return NSColor(named: "tagGradientStart")!
      case .general:
        return NSColor(named: "refGradientStart")!
    }
  }
  
  static func refGradientEnd(_ type: RefGradient) -> NSColor
  {
    switch type {
      case .branch:
        return NSColor(named: "branchGradientEnd")!
      case .activeBranch:
        return NSColor(named: "activeBranchGradientEnd")!
      case .remote:
        return NSColor(named: "remoteGradientEnd")!
      case .tag:
        return NSColor(named: "tagGradientEnd")!
      case .general:
        return NSColor(named: "refGradientEnd")!
    }
  }
}
