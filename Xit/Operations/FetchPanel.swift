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
  let accept: () -> Void
  let cancel: () -> Void

  var body: some View {
    VStack(alignment: .leading) {
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

      HStack {
        Spacer()
        Button("Cancel", action: cancel)
          .keyboardShortcut(.cancelAction)
          .accessibilityIdentifier(.Button.cancel)
        Button("Fetch", action: accept)
          .keyboardShortcut(.defaultAction)
          .accessibilityIdentifier(.Button.accept)
      }
    }.padding(20)
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
        options: options,
        accept: {},
        cancel: {})
  }
}
