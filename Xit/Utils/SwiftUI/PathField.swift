import SwiftUI

struct PathField: View
{
  @Binding var path: String
  @State var isDropTarget: Bool = false
  @Environment(\.window) var window: NSWindow?
  
  struct FolderDropDelegate: DropDelegate
  {
    @Binding var path: String
    @Binding var isDropTarget: Bool
    
    func dropEntered(info: DropInfo)
    {
      isDropTarget = true
    }
    
    func dropExited(info: DropInfo)
    {
      isDropTarget = false
    }

    func performDrop(info: DropInfo) -> Bool
    {
      isDropTarget = false
      
      guard let provider = info.itemProviders(for: [.fileURL]).first
      else { return false }
      
      _ = provider.loadObject(ofClass: URL.self) {
        (url, _) in
        // It seems the only way to verify that the dropped item is a directory
        // is to examine the data asynchronously, so dropped files are ignored
        // instead of rejected.
        var isDirectory: ObjCBool = false
        guard let url = url,
              FileManager.default.fileExists(atPath: url.path,
                                             isDirectory: &isDirectory),
              isDirectory.boolValue
        else { return }
        
        DispatchQueue.main.async {
          path = url.path
        }
      }
      return true
    }
  }
  
  var body: some View
  {
    HStack {
      TextField(text: $path)
        .labelsHidden()
        .border(Color(NSColor.selectedControlColor),
                width: isDropTarget ? 2 : 0)
      Button {
        chooseFolder()
      } label: {
        Image(systemName: "folder")
      }.buttonStyle(BorderlessButtonStyle())
    }.onDrop(of: [.fileURL],
             delegate: FolderDropDelegate(path: $path,
                                          isDropTarget: $isDropTarget))
  }

  @MainActor
  func chooseFolder()
  {
    guard let window = self.window
    else {
      assertionFailure("no parent window")
      return
    }
    let panel = NSOpenPanel()
    
    panel.prompt = "Choose"
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.beginSheetModal(for: window) { response in
      guard response == .OK
      else { return }
      path = panel.url?.path ?? ""
    }
  }
}

struct PathField_Previews: PreviewProvider
{
  struct Preview: View
  {
    @State var path: String = ""
    
    var body: some View
    {
      PathField(path: $path)
    }
  }
  
  static var previews: some View
  {
    Preview().padding()
  }
}
