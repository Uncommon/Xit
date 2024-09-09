import SwiftUI
import Combine

class ObservableTagModel<Tagger: Tagging, Publisher: RepositoryPublishing>: ObservableObject
{
  let tagger: Tagger
  let publisher: Publisher

  @Published var tags: [TreeItem<Tagger.Tag>] = []

  var sink: AnyCancellable?

  init(tagger: Tagger, publisher: Publisher)
  {
    self.tagger = tagger
    self.publisher = publisher

    setTagHierarchy()
    sink = publisher.refsPublisher.sink {
      [weak self] in
      self?.setTagHierarchy()
    }
  }

  func setTagHierarchy()
  {
    let tagList = (try? tagger.tags()) ?? []

    self.tags = TreeItem.makeHierarchy(from: tagList)
  }
}

struct TagList<Tagger: Tagging, Publisher: RepositoryPublishing>: View
{
  let model: ObservableTagModel<Tagger, Publisher>

  @State private var selection: String? = nil

  var body: some View
  {
    VStack(spacing: 0) {
      List(model.tags, id: \.path, children: \.children, selection: $selection) {
        (tag: TreeItem<Tagger.Tag>) in
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
      HStack(spacing: 0) {
        Button {
          // new tag panel
        } label: {
          Image(systemName: "plus")
        }.buttonStyle(.plain).padding(.horizontal, 3)
        FilterField(text: .constant(""), prompt: Text(.filter)) {
          FilterIndicator()
        }.padding(2)
      }.padding(.horizontal, 4)
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
