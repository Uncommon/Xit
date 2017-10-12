import Foundation

extension DeltaStatus
{
  init(delta: GTDeltaType)
  {
    guard let change = DeltaStatus(rawValue: UInt(delta.rawValue))
    else {
      self = .unmodified
      return
    }
    
    self = change
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
