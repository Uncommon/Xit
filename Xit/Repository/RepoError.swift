import Foundation

public enum RepoError: Swift.Error
{
  case alreadyWriting
  case authenticationFailed
  case cherryPickInProgress
  case commitNotFound(sha: String?)
  case conflict  // List of conflicted files?
  case detachedHead
  case duplicateName
  case fileNotFound(path: String)
  case gitError(Int32, git_error?)
  case invalidName(String)
  case invalidNameGiven
  case localConflict
  case mergeInProgress
  case notFound
  case patchMismatch
  case unexpected
  case workspaceDirty
  
  static func gitError(_ code: Int32) -> Self
  { .gitError(code, nil) }
  
  var isExpected: Bool
  {
    switch self {
      case .unexpected:
        return false
      default:
        return true
    }
  }

  var message: UIString
  {
    switch self {
      case .alreadyWriting:
        return .alreadyWriting
      case .authenticationFailed:
        return .authenticationFailed
      case .mergeInProgress:
        return .mergeInProgress
      case .cherryPickInProgress:
        return .cherryPickInProgress
      case .conflict:
        return .conflict
      case .duplicateName:
        return .duplicateName
      case .localConflict:
        return .localConflict
      case .detachedHead:
        return .detachedHead
      case .gitError(let code, let error):
        if let error, let message = error.message.map({ String(cString: $0) }) {
          return .gitErrorMsg(code, message)
        }
        else {
          return .gitError(code)
        }
      case .invalidName(let name):
        return .invalidName(name)
      case .invalidNameGiven:
        return .invalidNameGiven
      case .patchMismatch:
        return .patchMismatch
      case .commitNotFound(let sha):
        return .commitNotFound(sha?.firstSix())
      case .fileNotFound(let path):
        return .fileNotFound(path)
      case .notFound:
        return .notFound
      case .unexpected:
        return .unexpected
      case .workspaceDirty:
        return .workspaceDirty
    }
  }
  
  var localizedDescription: String { message.rawValue }
  
  init(gitCode: git_error_code)
  {
    switch gitCode {
      case GIT_ECONFLICT, GIT_EMERGECONFLICT:
        self = .conflict
      case GIT_EEXISTS:
        self = .duplicateName
      case GIT_ELOCKED:
        self = .alreadyWriting
      case GIT_ENOTFOUND:
        self = .notFound
      case GIT_EUNMERGED:
        self = .mergeInProgress
      case GIT_EUNCOMMITTED, GIT_EINDEXDIRTY:
        self = .workspaceDirty
      case GIT_EINVALIDSPEC:
        self = .invalidNameGiven
      case GIT_EAUTH:
        self = .authenticationFailed
      default:
        self = .gitError(gitCode.rawValue, git_error_last()?.pointee)
    }
  }
  
  func isGitError(_ code: git_error_code) -> Bool
  {
    switch self {
      case .gitError(let myCode, _):
        return myCode == code.rawValue
      default:
        return false
    }
  }
  
  static func throwIfGitError(_ code: Int32) throws
  {
    guard code == 0
    else {
      throw RepoError(gitCode: git_error_code(code))
    }
  }
}

extension RepoError: CustomStringConvertible
{
  public var description: String { message.rawValue }
}
