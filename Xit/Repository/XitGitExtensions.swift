import XitGit

extension RepoError
{
  var message: UIString
  {
    switch self {
      case .alreadyWriting:
        .alreadyWriting
      case .authenticationFailed:
        .authenticationFailed
      case .mergeInProgress:
        .mergeInProgress
      case .cherryPickInProgress:
        .cherryPickInProgress
      case .conflict:
        .conflict
      case .duplicateName:
        .duplicateName
      case .localConflict:
        .localConflict
      case .detachedHead:
        .detachedHead
      case .gitError(let code, let error):
        if let error, !error.message.isEmpty {
          .gitErrorMsg(code, error.message)
        }
        else {
          .gitError(code)
        }
      case .invalidName(let name):
        .invalidName(name)
      case .invalidNameGiven:
        .invalidNameGiven
      case .patchMismatch:
        .patchMismatch
      case .commitNotFound(let sha):
        .commitNotFound(sha?.shortString)
      case .fileNotFound(let path):
        .fileNotFound(path)
      case .notFound:
        .notFound
      case .unexpected:
        .unexpected
      case .workspaceDirty:
        .workspaceDirty
    }
  }
}
