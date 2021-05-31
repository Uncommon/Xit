import SwiftUI

struct PathField: View
{
  @Binding var path: String
  
  var body: some View
  {
    HStack {
      TextField("", text: $path)
      Button {
        chooseFolder()
      } label: {
        Image(systemName: "folder")
      }.buttonStyle(BorderlessButtonStyle())
    }
  }
  
  func findParentWindow() -> NSWindow?
  {
    let window = NSApp.mainWindow
    
    if let sheet = window?.sheets.first {
      return sheet
    }
    return window
  }
  
  func chooseFolder()
  {
    guard let window = findParentWindow()
    else { return }
    let panel = NSOpenPanel()
    
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
    Preview()
  }
}
