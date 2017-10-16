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
}
