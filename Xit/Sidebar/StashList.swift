import SwiftUI
import Combine

class StashListViewModel<Stasher, Publisher>: ObservableObject
  where Stasher: Stashing, Publisher: RepositoryPublishing
{
  let stasher: Stasher
  let publisher: Publisher

  @Published var stashes: [Stasher.Stash]
  @Published var filter: String = ""

  var sinks: [AnyCancellable] = []

  init(stasher: Stasher, publisher: Publisher)
  {
    self.stasher = stasher
    self.publisher = publisher
    self.stashes = Array(stasher.stashes)

    sinks.append(contentsOf: [
      publisher.stashPublisher.sinkOnMainQueue {
        [weak self] in
        guard let self
        else { return }
        applyFilter(filter)
      },
      $filter
        .debounce(for: 0.5, scheduler: DispatchQueue.main)
        .sink {
          [weak self] in
          self?.applyFilter($0)
        },
    ])
  }

  func applyFilter(_ filterString: String)
  {
    stashes = stasher.stashes.filter {
      filterString.isEmpty ||
      $0.message?.lowercased().contains(filterString.lowercased()) ?? false
    }
  }
}

struct StashList<Stasher, Publisher>: View
  where Stasher: Stashing, Publisher: RepositoryPublishing
{
  @StateObject var model: StashListViewModel<Stasher, Publisher>

  @State private var showAlert = false
  @State private var alertAction: StashAction?
  @Environment(\.showError) private var showError

  let selection: Binding<GitOID?>

  enum StashAction
  {
    case pop(Int), apply(Int), drop(Int)

    var buttonTitle: UIString
    {
      switch self {
        case .pop: .pop
        case .apply: .apply
        case .drop: .drop
      }
    }

    var confirmText: UIString
    {
      switch self {
        case .pop: .confirmPopSelected
        case .apply: .confirmApplySelected
        case .drop: .confirmStashDrop
      }
    }

    var index: Int
    {
      switch self {
        case .pop(let index), .apply(let index), .drop(let index):
          index
      }
    }

    var isDestructive: Bool
    {
      switch self {
        case .drop:
          true
        default:
          false
      }
    }
  }

  var body: some View
  {
    VStack(spacing: 0) {
      List(model.stashes, id: \.id, selection: selection) {
        (stash: Stasher.Stash) in
        HStack {
          // Label() placed the text too low relative to the icon
          Image(systemName: "tray")
            .foregroundStyle(.tint)
          Text(stash.mainCommit?.messageSummary ?? "WIP")
          Spacer()
          WorkspaceStatusBadge(unstagedCount: stash.workspaceChanges().count,
                              stagedCount: stash.indexChanges().count)
        }
      }
        .contextMenu(forSelectionType: GitOID.self) {
          if let stash = $0.first,
             let index = model.stasher.findStashIndex(stash) {
            Button(.pop) { confirm(.pop(index)) }
            Button(.apply) { confirm(.apply(index)) }
            Button(.drop) { confirm(.drop(index)) }
          }
        }
        .confirmationDialog(alertAction?.confirmText.rawValue ?? "",
                            isPresented: $showAlert,
                            presenting: alertAction) {
          (action) in
          Button(action.buttonTitle,
                 role: action.isDestructive ? .destructive : nil)
          { perform(action) }
        }
        .overlay {
          if model.stasher.stashes.isEmpty {
            ContentUnavailableView("No Stashes", systemImage: "tray")
          }
        }
      FilterBar(text: $model.filter) {
        SidebarActionButton {
          Button("Stash current changes") {}
          Divider()
          Button("Pop top stash") {}
          Button("Apply top stash") {}
          Button("Drop top stash") {}
        }
      }
    }
  }

  init(stasher: Stasher, publisher: Publisher, selection: Binding<GitOID?>)
  {
    self._model = .init(wrappedValue: .init(stasher: stasher,
                                            publisher: publisher))
    self.selection = selection
  }

  func confirm(_ action: StashAction)
  {
    alertAction = action
    showAlert = true
  }

  func perform(_ action: StashAction)
  {
    do {
      switch action {
        case .pop:
          try model.stasher.popStash(index: UInt(action.index))
        case .apply:
          try model.stasher.applyStash(index: UInt(action.index))
        case .drop:
          try model.stasher.dropStash(index: UInt(action.index))
      }
    }
    catch let error as NSError {
      showError(error)
    }
  }
}

#if DEBUG
struct StashListPreview: View
{
  let stashes: [Stash]
  @State var selection: GitOID?

  class Stash: EmptyStash
  {
    var mainCommit: FakeCommit?
    var indexCommit: FakeCommit?
    var untrackedCommit: FakeCommit?
    var message: String? { mainCommit?.messageSummary }

    var index: [FileChange]
    var workspace: [FileChange]

    init(message: String, oid: GitOID,
         stagedCount: Int = 0, unstagedCount: Int = 0)
    {
      self.mainCommit = .init(parentOIDs: [], message: message, id: oid)

      self.index = (0..<stagedCount).map {
        .init(path: "\($0)", change: .modified)
      }
      self.workspace = (0..<unstagedCount).map {
        .init(path: "\($0)", change: .modified)
      }
    }

    static func makeList(_ messages: [String]) -> [Stash]
    {
      messages.enumerated().map {
        (index, message) in
        Stash(message: message, oid: .init(string: "\(index+1)"))
      }
    }

    // These are supposed to be unnecessary because of the EmptyStash
    // default implementations, but there are still issues with the compiler
    // and/or the @Faked macro.
    func indexChanges() -> [FileChange] { index }
    func workspaceChanges() -> [FileChange] { workspace }
    func stagedDiffForFile(_ path: String) -> PatchMaker.PatchResult? { nil }
    func unstagedDiffForFile(_ path: String) -> PatchMaker.PatchResult? { nil }
  }

  class PreviewStashing: EmptyStashing, EmptyRepositoryPublishing
  {
    var stashArray: [Stash]
    var stashes: AnyRandomAccessCollection<Stash> { .init(stashArray) }
    let publisher = PassthroughSubject<Void, Never>()

    init(stashes: [Stash])
    { self.stashArray = stashes }
    convenience init(_ messages: [String])
    { self.init(stashes: Stash.makeList(messages)) }
    func stash(index: UInt, message: String?) -> Stash
    { .init(message: message ?? "", oid: .zero()) }

    var stashPublisher: AnyPublisher<Void, Never>
    { publisher.eraseToAnyPublisher() }

    func popStash(index: UInt) throws
    {
      try dropStash(index: index)
    }

    func dropStash(index: UInt) throws
    {
      stashArray.remove(at: Int(index))
      publisher.send()
    }
  }

  var body: some View
  {
    let repo = StashListPreview.PreviewStashing(stashes: stashes)
    StashList(stasher: repo, publisher: repo, selection: $selection)
      .listStyle(.sidebar)
  }
}

#Preview("With items") {
  StashListPreview(stashes: [
    .init(message: "WIP first", oid: .init(stringLiteral: "1"),
          stagedCount: 1, unstagedCount: 2),
    .init(message: "WIP second", oid: .init(stringLiteral: "2"),
          stagedCount: 2, unstagedCount: 3),
    .init(message: "WIP third", oid: .init(stringLiteral: "3"),
          stagedCount: 3, unstagedCount: 0),
  ])
}

#Preview("Empty") {
  StashListPreview(stashes: [])
}
#endif
