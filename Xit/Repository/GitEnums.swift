import Foundation

extension git_checkout_strategy_t: OptionSet {}
extension git_credential_t: OptionSet {}
extension git_diff_option_t: OptionSet {}
extension git_status_t: OptionSet {}
extension git_submodule_status_t: OptionSet {}

extension DeltaStatus
{
  init(gitDelta: git_delta_t)
  {
    guard let delta = DeltaStatus(rawValue: gitDelta.rawValue)
    else {
      self = .unmodified
      return
    }
    
    self = delta
  }
  
  init(indexStatus: git_status_t)
  {
    switch indexStatus {
      case GIT_STATUS_CURRENT:
        self = .unmodified
      case let status where status.contains(GIT_STATUS_INDEX_MODIFIED):
        self = .modified
      case let status where status.contains(GIT_STATUS_INDEX_NEW):
        self = .added
      case let status where status.contains(GIT_STATUS_INDEX_DELETED):
        self = .deleted
      case let status where status.contains(GIT_STATUS_INDEX_RENAMED):
        self = .renamed
      case let status where status.contains(GIT_STATUS_INDEX_TYPECHANGE):
        self = .typeChange
      case let status where status.contains(GIT_STATUS_IGNORED):
        self = .ignored
      case let status where status.contains(GIT_STATUS_CONFLICTED):
        self = .conflict
      default:
        self = .unmodified
    }
  }
  
  init(worktreeStatus: git_status_t)
  {
    switch worktreeStatus {
      case GIT_STATUS_CURRENT:
        self = .unmodified
      case let status where status.contains(GIT_STATUS_WT_MODIFIED):
        self = .modified
      case let status where status.contains(GIT_STATUS_WT_NEW):
        self = .added
      case let status where status.contains(GIT_STATUS_WT_DELETED):
        self = .deleted
      case let status where status.contains(GIT_STATUS_WT_RENAMED):
        self = .renamed
      case let status where status.contains(GIT_STATUS_WT_TYPECHANGE):
        self = .typeChange
      case GIT_STATUS_CONFLICTED:
        self = .conflict
      default:
        self = .unmodified
    }
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
    let info: (String, NSColor)
    
    switch self {
      case .added, .untracked:
        info = ("plus.circle", .systemGreen)
      case .copied:
        info = ("circlebadge.2.fill", .systemGreen)
      case .deleted:
        info = ("minus.circle", .systemRed)
      case .modified:
        info = ("pencil.circle", .systemBlue)
      case .renamed:
        info = ("a.circle.fill", .systemTeal)
      case .mixed:
        info = ("ellipsis.circle.fill", .systemGray)
      default:
        return nil
    }
    return NSImage(systemSymbolName: info.0)!
      .withSymbolConfiguration(.init(pointSize: 11, weight: .bold))!
      .image(coloredWith: info.1)
  }
}

extension DeltaStatus // CustomStringConvertible
{
  public var description: String
  {
    switch self {
      case .unmodified: return "unmodified"
      case .added: return "added"
      case .deleted: return "deleted"
      case .modified: return "modified"
      case .renamed: return "renamed"
      case .copied: return "copied"
      case .ignored: return "ignored"
      case .untracked: return "untracked"
      case .typeChange: return "type change"
      case .conflict: return "conflict"
      case .mixed: return "mixed"
    }
  }
}
