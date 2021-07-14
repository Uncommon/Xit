import SwiftUI

struct CleanableItem
{
  let path: String
  let ignored: Bool

  var icon: NSImage
  {
    path.hasSuffix("/")
        ? .init(named: NSImage.folderName)!
        : NSWorkspace.shared.icon(forFileType: path.pathExtension)
  }
}

extension CleanableItem: Identifiable
{
  var id: String { path }
}

protocol CleanPanelDelegate: AnyObject
{
  func closePanel()
  func clean(_ files: [String]) throws
  func refresh()
}

class CleanData: ObservableObject
{
  @Published var cleanFolders: Bool = false
  @Published var cleanIgnored: Bool = false
  @Published var cleanNonIgnored: Bool = true
  @Published var regex: String = ""
  @Published var items: [CleanableItem] = []
}

struct CleanPanel: View
{
  weak var delegate: CleanPanelDelegate?

  @ObservedObject var model: CleanData

  @State private var selection: Set<String> = []
  @Environment(\.window) private var window: NSWindow

  var filteredItems: [CleanableItem]
  {
    model.items.filter {
      $0.ignored && model.cleanIgnored ||
      !$0.ignored && model.cleanNonIgnored
    }
  }

  var body: some View
  {
    VStack(alignment: .leading) {
      Toggle("Clean untracked directories", isOn: $model.cleanFolders)
      Toggle("Clean ignored files", isOn: $model.cleanIgnored)
      Toggle("Clean non-ignored files", isOn: $model.cleanNonIgnored)
      HStack {
        Text("Regex for non-ignored files:")
          .foregroundColor(model.cleanNonIgnored ? .primary : .secondary)
        TextField("", text: $model.regex)
      }.disabled(!model.cleanNonIgnored)

      List(filteredItems, selection: $selection) { item in
        HStack {
          Image(nsImage: item.icon)
            .resizable().frame(width: 16, height: 16)
          Text(item.path.droppingSuffix("/"))
            .foregroundColor(item.ignored ? .secondary : .primary)
        }
      }
        .border(Color(.separatorColor))
        .frame(minWidth: 200, minHeight: 100)
      ZStack(alignment: .leading) {
        // path must be non-nil or else the control will be a different size
        PathControl(path: selection.first ?? "")
          .opacity(selection.count == 1 ? 1 : 0)
        Text("\(selection.count) items selected").foregroundColor(.secondary)
          .opacity(selection.count > 1 ? 1 : 0)
      }

      HStack {
        Text("\(filteredItems.count) item(s) total")
          .fixedSize(horizontal: true, vertical: true)
        Button {
          delegate?.refresh()
        } label: {
          Image(systemName: "arrow.clockwise")
        }.buttonStyle(BorderlessButtonStyle())
        Spacer()
        Button("Cancel") {
          delegate?.closePanel()
        }.keyboardShortcut(.cancelAction)
        Button("Clean Selected") {
          cleanSelected()
        }.disabled(selection.isEmpty)
        Button("Clean All") {
          cleanAll()
        }.keyboardShortcut(.defaultAction).disabled(filteredItems.isEmpty)
      }
    }.padding()
  }

  func confirmClean(_ message: String, onConfirm: @escaping () -> Void)
  {
    let alert = NSAlert()

    alert.messageText = message
    alert.addButton(withTitle: "Cancel")
    alert.addButton(withTitle: "Delete")
    alert.beginSheetModal(for: window) {
      guard $0 == .OK
      else { return }

      onConfirm()
    }
  }

  func cleanSelected()
  {
    confirmClean("Are you sure you want to delete the selected files?") {
      do {
        try delegate?.clean(Array(selection))
      }
      catch {
        // show error
      }
      delegate?.refresh()
    }
  }

  func cleanAll()
  {
    confirmClean("Are you sure you want to clean all listed files?") {
      do {
        try delegate?.clean(filteredItems.map { $0.path })
        delegate?.closePanel()
      }
      catch {
        // show error
      }
    }
  }
}

struct CleanPanel_Previews: PreviewProvider
{
  class EmptyDelegate: CleanPanelDelegate
  {
    func closePanel() {}
    func clean(_ files: [String]) {}
    func refresh() {}
  }

  struct Preview: View
  {
    let model = CleanData()

    var body: some View
    {
      CleanPanel(delegate: EmptyDelegate(), model: model)
    }

    init(items: [CleanableItem])
    {
      model.items = items
    }
  }

  static var previews: some View
  {
    Preview(items: [
      .init(path: "build.o", ignored: true),
      .init(path: "file.txt", ignored: false),
      .init(path: "folder/", ignored: true),
    ])
    Preview(items: [])
  }
}
