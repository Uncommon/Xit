import Foundation
import Combine

public enum RemoteProgressMessage
{
    case download(TransferProgress)
    case upload(PushTransferProgress)
    case sideband(String)
}

public class RemoteProgressPublisher
{
  let subject: PassthroughSubject<RemoteProgressMessage, RepoError>
  private(set) var callbacks: RemoteCallbacks
  var canceled: Bool = false
  
  init(passwordBlock: (() -> (String, String))? = nil)
  {
    subject = .init()
    callbacks = .init()
    
    callbacks = .init(
        passwordBlock: nil,
        downloadProgress: { [self] in
          subject.send(.download($0))
          return !canceled
        },
        uploadProgress: { [self] in
          subject.send(.upload($0))
          return !canceled
        },
        sidebandMessage: { [self] in
          subject.send(.sideband($0))
          return !canceled
        })
  }
  
  func setPasswordBlock(_ block: (() -> (String, String)?)?)
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
