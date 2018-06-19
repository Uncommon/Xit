import Foundation

extension XTRepository
{
  enum Error: Swift.Error
  {
    case alreadyWriting
    case mergeInProgress
    case cherryPickInProgress
    case conflict  // List of conflicted files
    case localConflict
    case detachedHead
    case gitError(Int32)
    case patchMismatch
    case commitNotFound(String?)  // SHA
    case fileNotFound(String)  // Path
    case notFound
    case unexpected
    
    var message: String
    {
      switch self {
        case .alreadyWriting:
          return "A writing operation is already in progress."
        case .mergeInProgress:
          return "A merge operation is already in progress."
        case .cherryPickInProgress:
          return "A cherry-pick operation is already in progress."
        case .conflict:
          return """
          The operation could not be completed because there were
          conflicts.
          """
        case .localConflict:
          return """
          There are conflicted files in the work tree or index.
          Try checking in or stashing your changes first.
          """
        case .detachedHead:
          return "This operation cannot be performed in a detached HEAD state."
        case .gitError(let code):
          return "An internal git error (\(code)) occurred."
        case .patchMismatch:
          return """
          The patch could not be applied because it did not match
          the file content.
          """
        case .commitNotFound(let sha):
          return "The commit \(sha ?? "-") was not found."
        case .fileNotFound(let path):
          return "The file \(path) was not found."
        case .notFound:
          return "The item was not found."
        case .unexpected:
          return "An unexpected repository error occurred."
      }
    }
    
    init(gitCode: git_error_code)
    {
      switch gitCode {
        case GIT_ECONFLICT, GIT_EMERGECONFLICT:
          self = .conflict
        case GIT_ELOCKED:
          self = .alreadyWriting
        case GIT_ENOTFOUND:
          self = .notFound
        default:
          self = .gitError(gitCode.rawValue)
      }
    }
    
    init(gitNSError: NSError)
    {
      if gitNSError.domain == GTGitErrorDomain {
        self = .gitError(Int32(gitNSError.code))
      }
      else {
        self = .unexpected
      }
    }
    
    static func throwIfError(_ code: Int32) throws
    {
      guard code == 0
      else {
        throw Error(gitCode: git_error_code(code))
      }
    }
  }
}
