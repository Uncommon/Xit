//

import SwiftUI

struct PathControl: NSViewRepresentable
{
  var path: String?

  func makeNSView(context: Context) -> NSPathControl
  {
    let control = NSPathControl()

    control.setDraggingSourceOperationMask([], forLocal: true)
    control.setDraggingSourceOperationMask([], forLocal: false)
    return control
  }

  func updateNSView(_ nsView: NSPathControl, context: Context)
  {
    if let path = self.path {
      let pathComponents = path.pathComponents

      nsView.pathItems = pathComponents.dropLast().map {
        let item = NSPathControlItem()
        item.title = $0
        item.image = NSImage(named: NSImage.folderName)
        return item
      }

      if pathComponents.last != "/" {
        let lastItem = NSPathControlItem()

        lastItem.title = path.lastPathComponent
        lastItem.image = NSWorkspace.shared.icon(forFileType: path.pathExtension)
        nsView.pathItems.append(lastItem)
      }
    }
    else {
      nsView.pathItems = []
    }
  }
}

struct PathControl_Previews: PreviewProvider {
    static var previews: some View {
      Group {
        PathControl(path: "some/path/")
        PathControl(path: "some/path/file.txt")
        PathControl(path: "folder/")
      }
    }
}
