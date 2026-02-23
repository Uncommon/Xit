import Foundation
import Combine

public enum RemoteProgressMessage
{
    case download(TransferProgress)
    case upload(PushTransferProgress)
    case sideband(String)
}

public final class RemoteProgressPublisher
{
  public let subject = PassthroughSubject<RemoteProgressMessage, RepoError>()
  private(set) var callbacks = RemoteCallbacks()
  var canceled: Bool = false
  
  public init(passwordBlock: RemoteCallbacks.PasswordBlock? = nil)
  {
    callbacks = .init(
        passwordBlock: passwordBlock,
        downloadProgress: { [weak self] in
          guard let self = self
          else { return false }
          self.subject.send(.download($0))
          return !self.canceled
        },
        uploadProgress: { [weak self] in
          guard let self = self
          else { return false }
          self.subject.send(.upload($0))
          return !self.canceled
        },
        sidebandMessage: { [weak self] in
          guard let self = self
          else { return false }
          self.subject.send(.sideband($0))
          return !self.canceled
        })
  }
  
  public func setPasswordBlock(_ block: RemoteCallbacks.PasswordBlock?)
  {
    callbacks.passwordBlock = block
  }
  
  func finished()
  {
    subject.send(completion: .finished)
  }
  
  func error(_ error: RepoError)
  {
    subject.send(completion: .failure(error))
  }
}
