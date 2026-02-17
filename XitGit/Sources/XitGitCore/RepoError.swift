import Foundation
import Clibgit2

/// Sendable replacement for `git_error`
public struct GitError: Sendable, Equatable
{
  public let message: String
  public let `class`: Int32

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

  public var isExpected: Bool
  {
    switch self {
      case .unexpected:
        return false
      default:
        return true
    }
  }
  
  // TODO: remove public when all files are migrated to the package
  public static func throwIfGitError(_ code: Int32) throws
  {
    guard code == 0
    else {
      throw RepoError(gitCode: git_error_code(code))
    }
  }
  
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
}
