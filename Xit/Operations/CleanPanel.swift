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

enum CleanFolderMode
{
  case clean, recurse, ignore
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
  @Published var folderMode: CleanFolderMode = .ignore
  @Published var filter: String = ""
  @Published var filterType: FilterType = .contains
  @Published var items: [CleanableItem] = []

  var filteredItems: [CleanableItem]
  {
    let predicate: NSPredicate? =
          filter.isEmpty ? nil : filterType.predicate(filter: filter)

    return items.filter {
      (!$0.path.hasSuffix("/") || folderMode == .clean) &&
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
      HStack {
        Spacer()
        VStack(alignment: .leading) {
          LabeledField("Files:",
            Picker(selection: $model.mode, label: EmptyView()) {
              Text("Untracked only").tag(CleanMode.untracked)
              Text("Ignored only").tag(CleanMode.ignored)
              Text("All").tag(CleanMode.all)
            }.fixedSize()
              .accessibilityIdentifier(.Clean.Controls.fileMode))
          LabeledField("Folders:",
            Picker(selection: $model.folderMode, label: EmptyView()) {
              Text("Ignore").tag(CleanFolderMode.ignore)
              Text("Clean entire folder").tag(CleanFolderMode.clean)
              Text("List contents").tag(CleanFolderMode.recurse)
            }.fixedSize())
             .accessibilityIdentifier(.Clean.Controls.folderMode)
        }
        Spacer()
      }.padding(.bottom, 10)

      HStack {
        Picker(selection: $model.filterType, label: EmptyView()) {
          Text("Contains").tag(CleanData.FilterType.contains)
          Text("Wildcard").tag(CleanData.FilterType.wildcard)
          Text("Regex").tag(CleanData.FilterType.regex)
        }.fixedSize()
          .accessibilityIdentifier(.Clean.Controls.filterType)
        TextField("Filter", text: $model.filter)
          .textFieldStyle(RoundedBorderTextFieldStyle())
          .accessibilityIdentifier(.Clean.Controls.filterField)
      }

      List(model.filteredItems, selection: $selection) { item in
        HStack {
          Image(nsImage: item.icon)
            .resizable().frame(width: 16, height: 16)
          Text(item.path.lastPathComponent)
            .lineLimit(1)
            .truncationMode(.tail)
            .accessibilityIdentifier(.Clean.List.fileName)
          Spacer()
          Image(systemName: item.ignored ? "eye.slash" : "plus.circle")
            .frame(width: 16)
            // If the user drags to select multiple items, this doesn't update
            // until the drag is finished.
            .foregroundColor(selection.contains(item.path)
                             ? .primary
                             : item.ignored ? .secondary : .green)
        }
      }
        .border(Color(.separatorColor))
        .frame(minWidth: 200, minHeight: 100)
        .accessibilityIdentifier(.Clean.Controls.fileList)
      ZStack(alignment: .leading) {
        // path must be non-nil or else the control will be a different size
        PathControl(path: selection.first ?? "")
          .opacity(selection.count == 1 ? 1 : 0)
          .frame(maxWidth: .infinity)
        Text("\(selection.count) items selected").foregroundColor(.secondary)
          .opacity(selection.count > 1 ? 1 : 0)
          .accessibilityIdentifier(.Clean.Text.selected)
        Text("No selection").foregroundColor(.secondary)
          .opacity(selection.isEmpty ? 1 : 0)
      }.fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 20)

      HStack {
        Text("\(model.filteredItems.count) item(s) total")
          .lineLimit(1)
          .truncationMode(.tail)
          .accessibilityIdentifier(.Clean.Text.total)
        Button {
          delegate?.refresh()
        } label: {
          Image(systemName: "arrow.clockwise")
        }.buttonStyle(BorderlessButtonStyle())
          .accessibilityIdentifier(.Clean.Button.refresh)
        Spacer()
        Button("Cancel") {
          delegate?.closePanel()
        }.keyboardShortcut(.cancelAction)
          .accessibilityIdentifier(.Clean.Button.cancel)
        Button("Clean Selected") {
          cleanSelected()
        }.keyboardShortcut(.delete)
          .disabled(selection.isEmpty)
          .accessibilityIdentifier(.Clean.Button.cleanSelected)
        Button("Clean All") {
          cleanAll()
        }.keyboardShortcut(.defaultAction)
          .disabled(model.filteredItems.isEmpty)
          .accessibilityIdentifier(.Clean.Button.cleanAll)
      }
    }.labelWidthGroup().frame(minWidth: 400).padding(20)
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
    // swiftlint:disable line_length
    Preview(items: [
      .init(path: "build.o", ignored: true),
      .init(path: "very/loooooong/path/for/just/a/single little/file.txt", ignored: false),
      .init(path: "folder/", ignored: true),
      .init(path: "something with a really long name that should not wrap to a second line no matter how long it is",
            ignored: false),
    ])
    Preview(items: [])
  }
}
