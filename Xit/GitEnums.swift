import Foundation

extension DeltaStatus
{
  init(delta: GTDeltaType)
  {
    guard let change = DeltaStatus(rawValue: UInt32(delta.rawValue))
    else {
      self = .unmodified
      return
    }
    
    self = change
  }
  
  init(gitDelta: git_delta_t)
  {
    guard let delta = DeltaStatus(rawValue: gitDelta.rawValue)
    else {
      self = .unmodified
      return
    }
    
    self = delta
  }
  
  var isModified: Bool
  {
    switch self {
      case .unmodified, .untracked:
        return false
      default:
        return true
    }
  }

  var changeImage: NSImage?
  {
    switch self {
      case .added, .untracked:
        return NSImage(named: NSImage.Name(rawValue: "added"))
      case .copied:
        return NSImage(named: NSImage.Name(rawValue: "copied"))
      case .deleted:
        return NSImage(named: NSImage.Name(rawValue: "deleted"))
      case .modified:
        return NSImage(named: NSImage.Name(rawValue: "modified"))
      case .renamed:
        return NSImage(named: NSImage.Name(rawValue: "renamed"))
      case .mixed:
        return NSImage(named: NSImage.Name(rawValue: "mixed"))
      default:
        return nil
    }
  }
  
  var stageImage: NSImage?
  {
    switch self {
      case .added:
        return NSImage(named: NSImage.Name(rawValue: "add"))
      case .untracked:
        return NSImage(named: NSImage.Name(rawValue: "add"))
      case .deleted:
        return NSImage(named: NSImage.Name(rawValue: "delete"))
      case .modified:
        return NSImage(named: NSImage.Name(rawValue: "modify"))
      case .mixed:
        return NSImage(named: NSImage.Name(rawValue: "mixed"))
      case .conflict:
        return NSImage(named: NSImage.Name(rawValue: "conflict"))
      default:
        return nil
    }
  }
}
