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
    case url, path
  }
  
  @Published var results: ProritizedResults<CheckedValues> = .init()
  
  var errorString: String?
  { results.firstError?.localizedDescription }
  
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
      .sink {
        [self] result in
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
