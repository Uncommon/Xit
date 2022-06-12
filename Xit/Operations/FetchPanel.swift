import SwiftUI

struct FetchPanel: View
{
  class Options: ObservableObject
  {
    @Published var remote: String
    @Published var downloadTags: Bool
    @Published var pruneBranches: Bool

    init(remote: String, downloadTags: Bool, pruneBranches: Bool)
    {
      self.remote = remote
      self.downloadTags = downloadTags
      self.pruneBranches = pruneBranches
    }
  }

  let remotes: [String]
  @ObservedObject var options: Options

  var body: some View
  {
    VStack(alignment: .leading) {
      LabeledField(
        label: Text("Remote:"),
        content: Picker(selection: $options.remote) {
          ForEach(remotes, id: \.self) {
            Text($0)
          }
        } label: { EmptyView() }
          .accessibilityIdentifier(.FetchSheet.remotePopup))
      LabeledField(label: Text("Options:"), content:
        VStack(alignment: .leading) {
          Toggle("Download tags", isOn: $options.downloadTags)
            .fixedSize()
            .accessibilityIdentifier(.FetchSheet.tagsCheck)
          Toggle("Prune obsolete local branches", isOn: $options.pruneBranches)
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
      remote: "origin",
      downloadTags: false,
      pruneBranches: true)

  static var previews: some View {
    FetchPanel(
        remotes: ["origin", "constantinople"],
        options: options)
    VStack {
      FetchPanel(
          remotes: ["origin", "constantinople"],
          options: options)
      DialogButtonRow()
        .environment(\.buttons, [
          (.cancel, {}),
          (.accept(.fetch), {}),
        ])
    }
  }
}
