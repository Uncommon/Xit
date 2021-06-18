import SwiftUI

struct ProgressPanel: View
{
  @ObservedObject var model: ObservableProgress
  let stopAction: (() -> Void)?
  
  var body: some View
  {
    VStack(alignment: .leading) {
      if model.progress.totalObjects == 0 {
        ProgressView(model.message).progressViewStyle(LinearProgressViewStyle())
      }
      else {
        ProgressView(model.message,
                     value: Float(model.progress.receivedObjects),
                     total: Float(model.progress.totalObjects))
      }
      if let stopAction = stopAction {
        HStack {
          Spacer()
          Button("Stop", action: stopAction).keyboardShortcut(.cancelAction)
        }.padding([.top], 8)
      }
    }.padding()
  }
}

class ObservableProgress: ObservableObject
{
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
  
  @Published var progress: TransferProgress
  @Published var message: String = ""
  var canceled = false
  
  init(message: String)
  {
    self.progress = EmptyProgress()
    self.message = message
  }
  
  init(message: String, progress: TransferProgress)
  {
    self.progress = progress
    self.message = message
  }
  
  func progressCallback(_ progress: TransferProgress) -> Bool
  {
    self.progress = progress
    return !canceled
  }
  
  func messageCallback(_ message: String) -> Bool
  {
    self.message = message
    return !canceled
  }
}

struct ProgressPanel_Previews: PreviewProvider
{
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
  
  static var emptyProgress = ObservableProgress(message: "Starting...")
  static var partialProgress = ObservableProgress(
    message: "Progress...",
    progress: PreviewProgress(totalObjects: 5, receivedObjects: 10))

  static var previews: some View
  {

    Group {
      ProgressPanel(model: partialProgress,
                    stopAction: {})
      ProgressPanel(model: emptyProgress,
                    stopAction: nil)
    }
  }
}
