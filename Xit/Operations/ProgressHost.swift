import SwiftUI
import Combine

/// Wraps a view and turns it into a host that can present a progress sheet.
struct ProgressHost<Content>: View where Content: View
{
  @ObservedObject var model: PresentingModel
  let message: String
  let publisher: AnyPublisher<RemoteProgressMessage, RepoError>
  let content: Content

  var body: some View
  {
    content.sheet(isPresented: $model.showSheet) {
      ProgressPanel(message: message,
                    publisher: publisher) {
        model.showSheet = false
      }
    }
  }
  
  init(model: PresentingModel,
       message: String,
       publisher: AnyPublisher<RemoteProgressMessage, RepoError>,
       @ViewBuilder content: () -> Content)
  {
    self.model = model
    self.message = message
    self.publisher = publisher
    self.content = content()
  }
}

class PresentingModel: ObservableObject
{
  @Published var showSheet = false
}

struct ProgressHost_Previews: PreviewProvider
{
  struct Preview: View
  {
    nonisolated(unsafe)
    static var model = PresentingModel()
    nonisolated(unsafe)
    static var publisher = Array(0...5).publisher
      .delay(for: 0.5, scheduler: DispatchQueue.main)
      .map {
        RemoteProgressMessage.download(
            PreviewProgress(totalObjects: 5, receivedObjects: UInt32($0)))
      }
      .setFailureType(to: RepoError.self)
      .eraseToAnyPublisher()

    var body: some View
    {
      ProgressHost(model: Self.model,
                   message: "Progressing...",
                   publisher: Self.publisher) {
        Button("Show", action: { Self.model.showSheet = true })
          .padding(20)
      }
    }
  }
  
  static var previews: some View
  {
    Preview()
  }
}
