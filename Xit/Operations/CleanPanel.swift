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

enum CleanMode: Int, CaseIterable
{
  case all, untracked, ignored

  var shouldCleanIgnored: Bool
  {
    switch self {
      case .ignored, .all:
        return true
      case .untracked:
        return false
    }
  }

  var shouldCleanUntracked: Bool
  {
    switch self {
      case .untracked, .all:
        return true
      case .ignored:
        return false
    }
  }
}

protocol CleanPanelDelegate: AnyObject
{
  func closePanel()
  func clean(_ files: [String]) throws
  func refresh()
}

class CleanData: ObservableObject
{
  enum FilterType
  {
    case contains, wildcard, regex

    func predicate(filter: String) -> NSPredicate
    {
      switch self {
        case .contains: return .init(format: "self CONTAINS %@", filter)
        case .wildcard: return .init(format: "self LIKE %@", filter)
        // NSPreditace has MATCHES for regular expressions, but throws an
        // exception if the regex is invalid.
        case .regex: return .init {
          (string, _) in
          (string as! String).range(of: filter, options: .regularExpression) != nil
        }
      }
    }
  }

  @Published var mode: CleanMode = .untracked
  @Published var cleanFolders: Bool = false
  @Published var filter: String = ""
  @Published var filterType: FilterType = .contains
  @Published var items: [CleanableItem] = []

  var filteredItems: [CleanableItem]
  {
    let predicate: NSPredicate? =
          filter.isEmpty ? nil : filterType.predicate(filter: filter)

    return items.filter {
      (!$0.path.hasSuffix("/") || cleanFolders) &&
      ($0.ignored && mode.shouldCleanIgnored ||
       !$0.ignored && mode.shouldCleanUntracked) &&
      (predicate?.evaluate(with: $0.path.lastPathComponent) ?? true)
    }
  }
}

struct CleanPanel: View
{
  weak var delegate: CleanPanelDelegate?

  @ObservedObject var model: CleanData

  @State private var selection: Set<String> = []
  @Environment(\.window) private var window: NSWindow

  var body: some View
  {
    VStack(alignment: .leading) {
      HStack(alignment: .firstTextBaseline) {
        Text("Clean:")
        VStack(alignment: .leading) {
          Picker(selection: $model.mode, label: EmptyView()) {
            Text("   All     ").tag(CleanMode.all)
            Text(" Untracked ").tag(CleanMode.untracked)
            Text(" Ignored ").tag(CleanMode.ignored)
          }.pickerStyle(SegmentedPickerStyle()).fixedSize()
          Toggle("Directories", isOn: $model.cleanFolders)
        }
      }
      HStack {
        Picker(selection: $model.filterType, label: EmptyView()) {
          Text("Contains").tag(CleanData.FilterType.contains)
          Text("Wildcard").tag(CleanData.FilterType.wildcard)
          Text("Regex").tag(CleanData.FilterType.regex)
        }.fixedSize()
        TextField("Filter", text: $model.filter)
          .textFieldStyle(RoundedBorderTextFieldStyle())
      }

      List(model.filteredItems, selection: $selection) { item in
        HStack {
          Image(systemName: item.ignored ? "eye.slash" : "plus.circle")
            .frame(width: 16)
            .foregroundColor(item.ignored ? .secondary : .green)
          Image(nsImage: item.icon)
            .resizable().frame(width: 16, height: 16)
          Text(item.path.lastPathComponent)
            .fixedSize(horizontal: true, vertical: true)
        }
      }
        .border(Color(.separatorColor))
        .frame(minWidth: 200, minHeight: 100)
      ZStack(alignment: .leading) {
        // path must be non-nil or else the control will be a different size
        PathControl(path: selection.first ?? "")
          .opacity(selection.count == 1 ? 1 : 0)
          .fixedSize(horizontal: false, vertical: true)
        Text("\(selection.count) items selected").foregroundColor(.secondary)
          .opacity(selection.count > 1 ? 1 : 0)
      }

      HStack {
        Text("\(model.filteredItems.count) item(s) total")
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
        }.keyboardShortcut(.defaultAction).disabled(model.filteredItems.isEmpty)
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
        try delegate?.clean(model.filteredItems.map { $0.path })
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
      .init(path: "something with a really long name that should not wrap to a second line no matter how long it is",
            ignored: false),
    ])
    Preview(items: [])
  }
}
