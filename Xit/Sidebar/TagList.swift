import SwiftUI
import Combine


struct TagList<Tagger: Tagging, Publisher: RepositoryPublishing>: View
{
  @ObservedObject var model: TagListViewModel<Tagger, Publisher>

  var selection: Binding<String?>
  var expandedItems: Binding<Set<String>>

  var body: some View
  {
    VStack(spacing: 0) {
      List(selection: selection) {
        RecursiveDisclosureGroup(model.tags,
                                 expandedItems: expandedItems) {
          (tag: PathTreeNode<Tagger.Tag>) in
          let item = tag.item
          HStack {
            Label(
              title: { ExpansionText(tag.path.lastPathComponent) },
              icon: {
                Image(systemName: item.map {
                  $0.isSigned ? "seal" : "tag"
                } ?? "folder")
                  .symbolVariant(item?.type == .lightweight ? .none : .fill)
              }
            )
            if let commit = item?.commit {
              Spacer()
              Text(commit.commitDate.formatted(.sidebar))
                .foregroundStyle(.secondary)
            }
          }.selectionDisabled(item == nil)
        }
      }
        .contextMenu(forSelectionType: String.self) {
          if $0.first != nil {
            Button(.delete, role: .destructive) { }
          }
        }
        .overlay {
          if model.tags.isEmpty {
            model.contentUnavailableView("No Tags", systemImage: "tag")
          }
        }
      FilterBar(text: $model.filter) {
        // TODO: sort by date or name
        SidebarBottomButton(systemImage: "plus") {
          // new tag panel
        }
      }
    }
  }

  init(model: TagListViewModel<Tagger, Publisher>,
       selection: Binding<String?>,
       expandedItems: Binding<Set<String>>)
  {
    self.model = model
    self.selection = selection
    self.expandedItems = expandedItems
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
    func tag(named name: String) -> Tag? { .init(name: name) }
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
  @State var selection: String?
  @State var expandedItems: Set<String> = []

  var body: some View
  {
    TagList(model: .init(tagger: tagger, publisher: tagger),
            selection: $selection,
            expandedItems: $expandedItems)
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
