import SwiftUI
import UniformTypeIdentifiers

struct CleanableItem
{
  let path: String
  let ignored: Bool

  var icon: NSImage
  {
    let type = UTType(filenameExtension: path.pathExtension) ?? .item

    return path.hasSuffix("/")
        ? .init(named: NSImage.folderName)!
        : NSWorkspace.shared.icon(for: type)
  }
}

extension CleanableItem: Identifiable
{
  var id: String { path }
}

extension CleanableItem: Equatable
{
  static func == (lhs: CleanableItem, rhs: CleanableItem) -> Bool
  { lhs.path == rhs.path }
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

@MainActor
protocol CleanPanelDelegate: AnyObject
{
  func closePanel()
  /// Should throw `CleanPanel.CleanError`
  func clean(_ files: [String]) throws
  func show(_ files: [String])
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
  { didSet { refilter() } }
  @Published var folderMode: CleanFolderMode = .ignore
  { didSet { refilter() } }
  @Published var filter: String = ""
  { didSet { refilter() } }
  @Published var filterType: FilterType = .contains
  { didSet { refilter() } }
  @Published var items: [CleanableItem] = []
  { didSet { refilter() } }

  @Published private(set) var filteredItems: [CleanableItem] = []

  private func refilter()
  {
    let predicate: NSPredicate? =
          filter.isEmpty ? nil : filterType.predicate(filter: filter)

    filteredItems = items.filter {
      (!$0.path.hasSuffix("/") || folderMode == .clean) &&
      ($0.ignored && mode.shouldCleanIgnored ||
       !$0.ignored && mode.shouldCleanUntracked) &&
      (predicate?.evaluate(with: $0.path.lastPathComponent) ?? true)
    }
  }
}

struct CleanPanel: View
{
  weak var delegate: (any CleanPanelDelegate)?
  let fileURLForPath: (String) -> URL

  struct CleanError: Error, Identifiable
  {
    let path: String
    let orginal: Error

    var id: String { path }
  }

  @ObservedObject var model: CleanData

  @State private var selection: Set<String> = []
  @State private var cleanSelectedAlertShown = false
  @State private var cleanAllAlertShown = false
  @State private var cleanError: CleanError?

  init(delegate: (any CleanPanelDelegate)?, model: CleanData,
       fileURLForPath: @escaping (String) -> URL = { URL(fileURLWithPath: $0) })
  {
    self.delegate = delegate
    self.fileURLForPath = fileURLForPath
    self._model = ObservedObject(wrappedValue: model)
  }

  var body: some View
  {
    VStack(alignment: .leading) {
      HStack {
        Spacer()
        Form {
          Picker("Files:", selection: $model.mode) {
            Text(.untrackedOnly).tag(CleanMode.untracked)
            Text(.ignoredOnly).tag(CleanMode.ignored)
            Text(.all).tag(CleanMode.all)
          }.fixedSize()
           .accessibilityIdentifier(.Clean.Controls.fileMode)
          Picker("Folders:", selection: $model.folderMode) {
            Text(.ignore).tag(CleanFolderMode.ignore)
            Text(.cleanEntireFolder).tag(CleanFolderMode.clean)
            Text(.listContents).tag(CleanFolderMode.recurse)
          }.fixedSize()
           .accessibilityIdentifier(.Clean.Controls.folderMode)
        }
        Spacer()
      }.padding(.bottom, 10)

      HStack {
        Picker(selection: $model.filterType, label: EmptyView()) {
          Text(.contains).tag(CleanData.FilterType.contains)
          Text(.wildcard).tag(CleanData.FilterType.wildcard)
          Text(.regex).tag(CleanData.FilterType.regex)
        }.fixedSize()
          .accessibilityIdentifier(.Clean.Controls.filterType)
        TextField(.filter, text: $model.filter)
          .textFieldStyle(RoundedBorderTextFieldStyle())
          .accessibilityIdentifier(.Clean.Controls.filterField)
      }

      CleanList(data: model, selection: $selection, delegate: delegate,
                fileURLForPath: fileURLForPath)
        .frame(minWidth: 200, minHeight: 100)

      ZStack(alignment: .leading) {
        // path must be non-nil or else the control will be a different size
        PathControl(path: selection.first ?? "")
          .opacity(selection.count == 1 ? 1 : 0)
          .frame(maxWidth: .infinity)
        Text(.itemSelected(selection.count)).foregroundColor(.secondary)
          .opacity(selection.count > 1 ? 1 : 0)
          .accessibilityIdentifier(.Clean.Text.selected)
        Text(.noSelection).foregroundColor(.secondary)
          .opacity(selection.isEmpty ? 1 : 0)
      }.fixedSize(horizontal: false, vertical: true)

      Spacer(minLength: 20)

      HStack {
        Text(.itemsTotal(model.filteredItems.count))
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

        Button(.cancel) {
          delegate?.closePanel()
        }.keyboardShortcut(.cancelAction)
          .accessibilityIdentifier(.Clean.Button.cancel)
          // This isn't related to the Cancel button, but putting it higher up
          // in the view hierarchy makes the confirmation alerts not show.
          .alert(item: $cleanError) { (error) in
            Alert(title: Text("An error occurred while deleting files."),
                  message: Text("""
                      \(error.path)

                      \(error.orginal.localizedDescription)
                      """))
          }
        Button(.cleanSelected) {
          cleanSelectedAlertShown = true
        }.keyboardShortcut(.delete)
          .disabled(selection.isEmpty)
          .alert(isPresented: $cleanSelectedAlertShown) {
            confirmCleanAlert(.confirmCleanSelected, onConfirm: cleanSelected)
          }
          .accessibilityIdentifier(.Clean.Button.cleanSelected)
        Button(.cleanAll) {
          cleanAllAlertShown = true
        }.keyboardShortcut(.defaultAction)
          .disabled(model.filteredItems.isEmpty)
          .alert(isPresented: $cleanAllAlertShown) {
            confirmCleanAlert(.confirmCleanAll, onConfirm: cleanAll)
          }
          .accessibilityIdentifier(.Clean.Button.cleanAll)
      }
    }.frame(minWidth: 400).padding(20)
      .onChange(of: model.filteredItems) {
        (newValue, _) in
        selection.formIntersection(newValue.map { $0.path })
      }
   }

  func confirmCleanAlert(_ message: UIString,
                         onConfirm: @escaping @MainActor () -> Void)
    -> Alert
  {
    // TODO: `Alert` is deprecated
    let button = Alert.Button.destructive(Text(.delete)) {
      Task { @MainActor in onConfirm() }
    }

    return Alert(title: Text(message),
                 primaryButton: button,
                 secondaryButton: .cancel())
  }

  func cleanSelected()
  {
    do {
      try delegate?.clean(Array(selection))
    }
    catch let error as CleanError {
      cleanError = error
    }
    catch {}
    delegate?.refresh()
  }

  func cleanAll()
  {
    do {
      try delegate?.clean(model.filteredItems.map { $0.path })
    }
    catch let error as CleanError {
      cleanError = error
    }
    catch {}
    delegate?.refresh()
  }
}

struct CleanPanel_Previews: PreviewProvider
{
  struct Preview: View
  {
    let model = CleanData()

    var body: some View
    {
      CleanPanel(delegate: nil, model: model)
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
