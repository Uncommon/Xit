import SwiftUI

struct CleanableItem
{
  let path: String
  let ignored: Bool

  var icon: NSImage
  {
    if path.hasSuffix("/") {
      return .init(named: NSImage.folderName)!
    }
    else {
      return NSWorkspace.shared.icon(forFileType: path.pathExtension)
    }
  }
}

extension CleanableItem: Identifiable
{
  var id: String { path }
}

struct CleanPanel: View
{
  @Binding var cleanFolders: Bool
  @Binding var cleanIgnored: Bool
  @Binding var cleanNonIgnored: Bool
  @Binding var regex: String
  @Binding var items: [CleanableItem]

  @State var selection: Set<String> = []

  var filteredItems: [CleanableItem]
  {
    items.filter {
      $0.ignored && cleanIgnored || !$0.ignored && cleanNonIgnored
    }
  }

  var body: some View
  {
    VStack(alignment: .leading) {
      Toggle("Clean untracked directories", isOn: $cleanFolders)
      Toggle("Clean ignored files", isOn: $cleanIgnored)
      Toggle("Clean non-ignored files", isOn: $cleanNonIgnored)
      HStack {
        Text("Regex for non-ignored files:")
          .foregroundColor(cleanNonIgnored ? .primary : .secondary)
        TextField("", text: $regex)
      }.disabled(!cleanNonIgnored)

      List(filteredItems, selection: $selection) { item in
        HStack {
          Image(nsImage: item.icon)
            .resizable().frame(width: 16, height: 16)
          Text(item.path.droppingSuffix("/"))
        }
      }.border(Color(.separatorColor))
      ZStack(alignment: .leading) {
        // path must be non-nil or else the control will be a different size
        PathControl(path: selection.first ?? "")
          .opacity(selection.count == 1 ? 1 : 0)
        Text("\(selection.count) items selected").foregroundColor(.secondary)
          .opacity(selection.count > 1 ? 1 : 0)
      }

      HStack {
        Text("\(filteredItems.count) item(s) total")
        Spacer()
        Button("Cancel") {

        }.keyboardShortcut(.cancelAction)
        Button("Clean Selected") {

        }.disabled(selection.isEmpty)
        Button("Clean All") {
          // clean
        }.keyboardShortcut(.defaultAction).disabled(filteredItems.isEmpty)
      }
    }.padding()
  }
}

struct CleanPanel_Previews: PreviewProvider
{
  struct Preview: View
  {
    @State var cleanFolders = true
    @State var cleanIgnored = true
    @State var cleanNonIgnored = true
    @State var regex = ""

    @State var items: [CleanableItem] = [
      .init(path: "build.o", ignored: true),
      .init(path: "file.txt", ignored: false),
      .init(path: "folder/", ignored: true),
    ]

    var body: some View
    {
      CleanPanel(cleanFolders: $cleanFolders, cleanIgnored: $cleanIgnored,
                 cleanNonIgnored: $cleanNonIgnored, regex: $regex,
                 items: $items)
    }
  }

  static var previews: some View
  {
    Preview()
  }
}
