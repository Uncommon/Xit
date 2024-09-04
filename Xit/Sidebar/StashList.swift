import SwiftUI

struct StashList<R>: View where R: Stashing
{
  let repo: R

  @State private var showAlert = false
  @State private var alertAction: StashAction?
  @Environment(\.showError) private var showError

  enum StashAction
  {
    case pop, apply, drop

    var buttonTitle: UIString {
      switch self {
        case .pop: .pop
        case .apply: .apply
        case .drop: .drop
      }
    }

    var confirmText: UIString {
      switch self {
        case .pop: .confirmPopSelected
        case .apply: .confirmApplySelected
        case .drop: .confirmStashDrop
      }
    }

    var isDestructive: Bool { self == .drop }
  }

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
          Button(.pop) { confirm(.pop) }
          Button(.apply) { confirm(.apply) }
          Button(.drop) { confirm(.drop) }
        }
        .confirmationDialog(alertAction?.confirmText.rawValue ?? "", 
                            isPresented: $showAlert,
                            presenting: alertAction) {
          (action) in
          Button(action.buttonTitle,
                 role: action.isDestructive ? .destructive : nil)
          { perform(action, on: stash) }
        }
    }
      .overlay {
        if repo.stashes.isEmpty {
          ContentUnavailableView("No stashes", systemImage: "shippingbox")
    }
  }
  }

  func confirm(_ action: StashAction)
  {
    alertAction = action
    showAlert = true
  }

  func perform(_ action: StashAction, on stash: R.Stash)
  {
    guard let index = repo.findStashIndex(stash)
    else { return }

    do {
      switch action {
        case .pop:
          try repo.popStash(index: UInt(index))
        case .apply:
          try repo.applyStash(index: UInt(index))
        case .drop:
          try repo.dropStash(index: UInt(index))
      }
    }
    catch let error as NSError {
      showError(error)
    }
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
