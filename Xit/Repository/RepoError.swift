import Foundation

/// Sendable replacement for `git_error`
public struct GitError: Sendable, Equatable
{
  let message: String
  let `class`: Int32

  init(_ error: git_error)
  {
    self.message = error.message.map { String(cString: $0) } ?? ""
    self.class = error.klass
  }
  
  public static var last: GitError?
  {
    guard let error = git_error_last()
    else { return nil }
    
    return GitError(error.pointee)
  }
}

public enum RepoError: Swift.Error, Equatable
{
  case alreadyWriting
  case authenticationFailed
  case cherryPickInProgress
  case commitNotFound(sha: SHA?)
  case conflict  // List of conflicted files?
  case detachedHead
  case duplicateName
  case fileNotFound(path: String)
  case gitError(Int32, GitError?)
  case invalidName(String)
  case invalidNameGiven
  case localConflict
  case mergeInProgress
  case notFound
  case patchMismatch
  case unexpected
  case workspaceDirty
  
  public static let genericGitError = Self.gitError(GIT_ERROR.rawValue)
  public static let bareRepo = Self.gitError(GIT_EBAREREPO.rawValue)
  
  static func gitError(_ code: Int32) -> Self
  { .gitError(code, Optional<GitError>.none) } // nil is ambiguous

  static func gitError(_ code: Int32, _ error: git_error?) -> Self
  { .gitError(code, error.map { GitError($0) }) }

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
        if let error, !error.message.isEmpty {
          return .gitErrorMsg(code, error.message)
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
        return .commitNotFound(sha?.shortString)
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
  
  public func isGitError(_ code: Int32) -> Bool
  {
    switch self {
      case .gitError(let myCode, _):
        return myCode == code
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
