import SwiftUI
import Combine

/// Wraps a view and turns it into a host that can present a progress sheet.
struct ProgressHost<Content>: View where Content: View
{
  let presenting: Binding<Bool>
  let message: String
  let publisher: RemoteProgressPublisher
  let content: Content

  var body: some View
  {
    content.sheet(isPresented: presenting) {
      ProgressPanel(message: message,
                    publisher: publisher.subject.eraseToAnyPublisher()) {
        presenting.wrappedValue = false
      }
    }
  }
  
  init(presenting: Binding<Bool>,
       message: String, publisher: RemoteProgressPublisher,
       @ViewBuilder content: () -> Content)
  {
    self.presenting = presenting
    self.message = message
    self.publisher = publisher
    self.content = content()
  }
}

struct ProgressHost_Previews: PreviewProvider
{
  struct Preview: View
  {
    @State var presenting: Bool = false

    var body: some View
    {
      ProgressHost(presenting: $presenting,
                   message: "Progressing...",
                   publisher: .init()) {
        Button("Show", action: { presenting = true })
          .padding(20)
      }
    }
  }
  
  static var previews: some View
  {
    Preview()
  }
}
