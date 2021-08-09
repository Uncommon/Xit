//

import SwiftUI

struct PathControl: NSViewRepresentable
{
  var path: String?

  func makeNSView(context: Context) -> NSPathControl
  {
    let control = CompressiblePathControl()

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

/// A variant of `NSPathControl` with a very small `intrinsicSize`
/// - Note: SwiftUI resists making a control smaller than its intrinsic size,
/// but a path control's content - and therefore its intrinsic size - varies.
/// This could cause the containing window to suddenly become bigger when the
/// path control is given a longer path.
class CompressiblePathControl: NSPathControl
{
  override var intrinsicContentSize: NSSize
  { .init(width: 20, height: super.intrinsicContentSize.height) }
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
