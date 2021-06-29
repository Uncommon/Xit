import SwiftUI
import Combine

struct ProgressPanel: View
{
  @State var message: String = ""
  let publisher: AnyPublisher<RemoteProgressMessage, RepoError>
  let stopAction: (() -> Void)?
  
  @State private var progress: TransferProgress = EmptyProgress()

  var body: some View
  {
    VStack(alignment: .leading) {
      if progress.totalObjects == 0 {
        ProgressView(message).progressViewStyle(LinearProgressViewStyle())
      }
      else {
        ProgressView(message,
                     value: (Float(progress.receivedObjects) +
                             Float(progress.indexedObjects)) / 2,
                     total: Float(progress.totalObjects))
      }
      if let stopAction = stopAction {
        HStack {
          Spacer()
          Button("Stop", action: stopAction).keyboardShortcut(.cancelAction)
        }.padding([.top], 8)
      }
    }.padding()
      .onReceive(publisher
        // Must catch because onReceive requires Failure == Never
        .catch({ _ in
          // Stop when there's an error. Some other subscriber will
          // display the error.
          Empty<RemoteProgressMessage, Never>(completeImmediately: true)
        })
        .handleEvents(receiveCompletion: { _ in
          stopAction?()
        }, receiveCancel: {
          stopAction?()
        })) {
        if case let .download(progress) = $0 {
          self.progress = progress
        }
      }
    
  }
  init(message: String, publisher: AnyPublisher<RemoteProgressMessage, RepoError>, stopAction: (() -> Void)? = nil)
  {
    self.publisher = publisher
    self.stopAction = stopAction
    self.message = message
  }
}

struct EmptyProgress: TransferProgress
{
  var totalObjects: UInt32 { 0 }
  var indexedObjects: UInt32 { 0 }
  var receivedObjects: UInt32 { 0 }
  var localObjects: UInt32 { 0 }
  var totalDeltas: UInt32 { 0 }
  var indexedDeltas: UInt32 { 0 }
  var receivedBytes: Int { 0 }
}

struct PreviewProgress: TransferProgress
{
  var totalObjects: UInt32
  var indexedObjects: UInt32 { 0 }
  var receivedObjects: UInt32
  var localObjects: UInt32 { 0 }
  var totalDeltas: UInt32 { 0 }
  var indexedDeltas: UInt32 { 0 }
  var receivedBytes: Int { 0 }
}

struct ProgressPanel_Previews: PreviewProvider
{
  static let sequence = Timer.publish(every: 1, on: .main, in: .default)
    .autoconnect()
    .map {
      (date: Date) -> RemoteProgressMessage in
      let percent = date.timeIntervalSince1970
        .truncatingRemainder(dividingBy: 100)
      return .download(
        PreviewProgress(totalObjects: 100, receivedObjects: UInt32(percent)))
    }
    .setFailureType(to: RepoError.self)
    .eraseToAnyPublisher()

  static var previews: some View
  {
    let result1: Result<RemoteProgressMessage, RepoError> = .success(.download(EmptyProgress()))

    Group {
      ProgressPanel(message: "Progressing",
                    publisher: result1.publisher.eraseToAnyPublisher(),
                    stopAction: {})
      ProgressPanel(message: "Starting...",
                    publisher: sequence,
                    stopAction: nil)
    }
  }
}
