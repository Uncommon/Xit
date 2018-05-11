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
        return NSImage(named: ◊"added")
      case .copied:
        return NSImage(named: ◊"copied")
      case .deleted:
        return NSImage(named: ◊"deleted")
      case .modified:
        return NSImage(named: ◊"modified")
      case .renamed:
        return NSImage(named: ◊"renamed")
      case .mixed:
        return NSImage(named: ◊"mixed")
      default:
        return nil
    }
  }
  
  var stageImage: NSImage?
  {
    switch self {
      case .added:
        return NSImage(named: ◊"add")
      case .untracked:
        return NSImage(named: ◊"add")
      case .deleted:
        return NSImage(named: ◊"delete")
      case .modified:
        return NSImage(named: ◊"modify")
      case .mixed:
        return NSImage(named: ◊"mixed")
      case .conflict:
        return NSImage(named: ◊"conflict")
      default:
        return nil
    }
  }
}
