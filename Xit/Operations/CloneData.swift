import Foundation
import Combine

class CloneData: ObservableObject
{
  @Published public var url: String = ""
  @Published public var destination: String = ""
  @Published public var name: String = ""
  @Published public var branches: [String] = []
  @Published public var selectedBranch: String = ""
  @Published public var recurse: Bool = true
  
  @Published public var inProgress: Bool = false
  
  typealias URLResult = Result<(name: String, branches: [String],
                                selectedBranch: String),
                               URLValidationError>
  typealias URLReader = (String) -> URLResult
  
  let readURL: URLReader
  private var urlObserver: AnyCancellable?

  enum CheckedValues: String, CaseIterable
  {
    case authentication, url, path
  }

  enum AuthenticationStatus
  {
    case unknown, notNeeded, failure, success
  }

  enum AuthenticationError: LocalizedError
  {
    /// Credentials were rejected by the server
    case rejected
    /// Credentials have not been supplied
    case missing
    case keychain

    var errorDescription: String?
    {
      switch self {
        case .rejected: return "Authentication failed"
        case .missing:  return "Authentication required"
        case .keychain: return "Couldn't access keychain"
      }
    }
  }

  typealias AuthenticationResult = Result<Never, CloneData.AuthenticationError>
  
  @Published var results: ProritizedResults<CheckedValues> = .init()
  @Published var authStatus: AuthenticationStatus = .unknown
  
  var errorString: String?
  {
    guard let error = results.firstError
    else { return nil }
    if let localized = error as? LocalizedError {
      return localized.errorDescription
    }
    else {
      return error.localizedDescription
    }
  }
  
  init(readURL: @escaping URLReader)
  {
    self.readURL = readURL

    self.urlObserver = $url
      .debounce(afterInvalidating: self, keyPath: \.results.url)
      .handleEvents(receiveOutput: {
        [self] _ in
        inProgress = true
        results.url = nil
        branches = []
      })
      .receive(on: DispatchQueue.global(qos: .userInitiated))
      .map {
        readURL($0)
      }
      .receive(on: DispatchQueue.main)
      .sink(receiveValue: didReadURL(result:))
  }

  func didReadURL(result: URLResult)
  {
    inProgress = false
    switch result {
      case .success((let name, let branches, let selectedBranch)):
        self.name = name
        results.name = nil
        self.branches = branches
        self.selectedBranch = selectedBranch
        results.url = result
      case .failure(.empty):
        results.url = nil
      default:
        results.url = result
    }
    if case .failure(.empty) = result {
      results.url = nil
    }
    else {
      results.url = result
    }
  }
}

enum URLValidationError: Error
{
  case invalid
  case empty
  case cantAccess
  case gitError(RepoError)
  case unexpected
}

extension URLValidationError: LocalizedError
{
  var errorDescription: String?
  {
    switch self {
      case .invalid:
        return "Invalid URL"
      case .empty:
        return ""
      case .cantAccess:
        return "Unable to access repository"
      case .gitError(let error):
        return error.localizedDescription
      case .unexpected:
        return "Unexpected error"
    }
  }
}
