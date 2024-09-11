import SwiftUI
import Combine

class TagListViewModel<Tagger: Tagging, Publisher: RepositoryPublishing>: ObservableObject
{
  let tagger: Tagger
  let publisher: Publisher

  @Published var tags: [PathTreeNode<Tagger.Tag>] = []
  @Published var filter: String = ""

  var sink: AnyCancellable?
  var sinks: [AnyCancellable] = []

  init(tagger: Tagger, publisher: Publisher)
  {
    self.tagger = tagger
    self.publisher = publisher

    setTagHierarchy()
    sinks.append(contentsOf: [
      publisher.refsPublisher.sink {
        [weak self] in
        self?.setTagHierarchy()
      },
      $filter
        .debounce(for: 0.5, scheduler: DispatchQueue.main)
        .sink {
          [weak self] _ in
          self?.setTagHierarchy()
        }
    ])
  }

  func setTagHierarchy()
  {
    let tagList = (try? tagger.tags()) ?? []
    var tags = PathTreeNode.makeHierarchy(from: tagList)

    if !filter.isEmpty {
      tags = tags.filtered(with: filter)
    }
    self.tags = tags
  }
}

struct TagList<Tagger: Tagging, Publisher: RepositoryPublishing>: View
{
  @ObservedObject var model: TagListViewModel<Tagger, Publisher>

  @State private var selection: String? = nil

  var body: some View
  {
    VStack(spacing: 0) {
      List(model.tags, id: \.path, children: \.children, selection: $selection) {
        (tag: PathTreeNode<Tagger.Tag>) in
        let item = tag.item
        Label(
          title: { Text(tag.path.lastPathComponent) },
          icon: {
            Image(systemName: item.map { $0.isSigned ? "seal" : "tag" } ?? "folder")
              .symbolVariant(item?.type == .lightweight ? .none : .fill)
          }
        ).selectionDisabled(item == nil)
      }
        .contextMenu(forSelectionType: String.self) {
          if let _ = $0.first {
            Button(.delete, role: .destructive) {  }
          }
        }
        .overlay {
          if model.tags.isEmpty {
            ContentUnavailableView("No Tags", systemImage: "tag")
          }
        }
      FilterBar(text: $model.filter) {
        SidebarBottomButton(systemImage: "plus") {
          // new tag panel
        }
      }
    }
  }
}

#if DEBUG
struct TagListPreview: View
{
  struct Tag: EmptyTag
  {
    var name: String
    var commit: NullCommit?
    var signature: Signature?
    var targetOID: GitOID?
    var message: String?
    var type: TagType { message == nil ? .lightweight : .annotated }
    var isSigned: Bool

    init(name: String, commit: NullCommit? = nil,
         signature: Signature? = nil, targetOID: GitOID? = nil,
         message: String? = nil, isSigned: Bool = false)
    {
      self.commit = commit
      self.name = name
      self.signature = signature
      self.targetOID = targetOID
      self.message = message
      self.isSigned = isSigned
    }
  }

  class Tagger: EmptyTagging, EmptyRepositoryPublishing
  {
    var tagList: [Tag]
    let publisher = PassthroughSubject<Void, Never>()

    var refsPublisher: AnyPublisher<Void, Never>
    { publisher.eraseToAnyPublisher() }

    init(tagList: [Tag] = [])
    {
      self.tagList = tagList
    }

    func tags() -> [Tag] { tagList }
    func createTag(name: String, targetOID: GitOID, message: String?) throws {}
    func createLightweightTag(name: String, targetOID: GitOID) throws {}
    
    func deleteTag(name: String) throws
    {
      if let index = tagList.firstIndex(where: { $0.name == name }) {
        tagList.remove(at: index)
        publisher.send()
      }
    }
  }

  let tagger: Tagger

  var body: some View
  {
    TagList(model: .init(tagger: tagger, publisher: tagger))
      .listStyle(.sidebar)
  }

  init(tags: [Tag])
  {
    tagger = .init(tagList: tags)
  }
}

#Preview("Tags") {
  TagListPreview(tags: [
    .init(name: "signed", message: "signed!", isSigned: true),
    .init(name: "light"),
  ])
}

#Preview("Folder") {
  TagListPreview(tags: [
    .init(name: "v1.0", message: "signed!", isSigned: true),
    .init(name: "parent", message: ""),
    .init(name: "parent/child", message: ""),
    .init(name: "work/things", message: ""),
  ])
}

#Preview("Empty") {
  TagListPreview(tags: [])
}
#endif
