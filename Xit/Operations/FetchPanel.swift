import SwiftUI

struct FetchPanel: DataModelView
{
  typealias Model = Options

  final class Options: ObservableObject, AlwaysValid
  {
    let remotes: [String]
    @Published var remote: String
    @Published var downloadTags: Bool
    @Published var pruneBranches: Bool

    init(remotes: [String], remote: String,
         downloadTags: Bool, pruneBranches: Bool)
    {
      self.remotes = remotes
      self.remote = remote
      self.downloadTags = downloadTags
      self.pruneBranches = pruneBranches
    }
  }

  @ObservedObject var model: Options

  var body: some View
  {
    VStack(alignment: .leading) {
      LabeledField(
        label: Text("Remote:"),
        content: Picker(selection: $model.remote) {
          ForEach(model.remotes, id: \.self) {
            Text($0)
          }
        } label: { EmptyView() }
          .accessibilityIdentifier(.FetchSheet.remotePopup))
      LabeledField(label: Text("Options:"), content:
        VStack(alignment: .leading) {
          Toggle("Download tags", isOn: $model.downloadTags)
            .fixedSize()
            .accessibilityIdentifier(.FetchSheet.tagsCheck)
          Toggle("Prune obsolete local branches", isOn: $model.pruneBranches)
            .fixedSize()
            .accessibilityIdentifier(.FetchSheet.pruneCheck)
        }
      )
    }.labelWidthGroup()
  }
}

struct FetchPanel_Previews: PreviewProvider
{
  static var options: FetchPanel.Options = .init(
      remotes: ["origin", "constantinople"],
      remote: "origin",
      downloadTags: false,
      pruneBranches: true)

  static var previews: some View {
    FetchPanel(model: options)
    VStack {
      FetchPanel(model: options)
      DialogButtonRow(validator: options)
        .environment(\.buttons, [
          (.cancel, {}),
          (.accept(.fetch), {}),
        ])
    }
  }
}
