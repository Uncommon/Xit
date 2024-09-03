import SwiftUI

struct StashList<R>: View where R: Stashing
{
  let repo: R

  var body: some View {
    List(repo.stashes) { (stash: R.Stash) in
      HStack {
        // using Label() placed the text too low relative to the icon
        Image(systemName: "shippingbox")
          .foregroundStyle(.tint)
        Text(stash.mainCommit?.messageSummary ?? "WIP")
        Spacer()
        // TODO: calculate the actual counts
        WorkspaceStatusView(unstagedCount: 1, stagedCount: 2)
      }
        .listRowSeparator(.hidden)
        .contextMenu {
          Button(.pop) { pop(stash) }
          Button(.apply) { apply(stash) }
          Button(.drop) { drop(stash) }
        }
    }
  }

  func pop(_ stash: R.Stash)
  {
  }

  func apply(_ stash: R.Stash)
  {
  }

  func drop(_ stash: R.Stash)
  {
  }
}

struct StashListPreview: View
{
  class Stash: EmptyStash
  {
    var mainCommit: FakeCommit?
    var indexCommit: FakeCommit?
    var untrackedCommit: FakeCommit?
    var message: String?

    init(message: String, oid: GitOID)
    {
      mainCommit = .init(parentOIDs: [], message: message, id: oid)
    }

    static func makeList(_ messages: [String]) -> [Stash]
    {
      messages.enumerated().map {
        (index, message) in
        Stash(message: message, oid: .init(string: "\(index+1)"))
      }
    }

    func indexChanges() -> [FileChange] { [] }
    func workspaceChanges() -> [FileChange] { [] }
    func stagedDiffForFile(_ path: String) -> PatchMaker.PatchResult? { nil }
    func unstagedDiffForFile(_ path: String) -> PatchMaker.PatchResult? { nil }
  }

  class PreviewStashing: EmptyStashing
  {
    var stashArray: [Stash]
    var stashes: AnyRandomAccessCollection<Stash> { .init(stashArray) }

    init(stashes: [Stash])
    { self.stashArray = stashes }
    convenience init(_ messages: [String])
    { self.init(stashes: Stash.makeList(messages)) }
    func stash(index: UInt, message: String?) -> Stash
    { .init(message: message ?? "", oid: .zero()) }
  }

  var body: some View {
    StashList(repo: StashListPreview.PreviewStashing(stashes: [
      .init(message: "WIP some stuff", oid: .init(stringLiteral: "1")),
      .init(message: "WIP more work", oid: .init(stringLiteral: "2")),
      .init(message: "WIP things", oid: .init(stringLiteral: "3")),
    ]))
  }
}

#Preview {
  StashListPreview()
}
