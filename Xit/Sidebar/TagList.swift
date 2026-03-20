import SwiftUI
import Combine
import XitGit

struct TagList<Tagger: Tagging>: View
{
  @ObservedObject var model: TagListViewModel<Tagger>

  @Binding var selection: TagRefName?
  @Binding var expandedItems: Set<String>

  @EnvironmentObject private var coordinator: SidebarCoordinator

  var body: some View
  {
    VStack(spacing: 0) {
      List(selection: $selection) {
        RecursiveDisclosureGroup(model.tags,
                                 expandedItems: $expandedItems) {
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
            Spacer()
            if let item,
               item.type == .annotated {
              let tagInfo = tagInfoModel(for: item)
              Button {
                coordinator.showTagInfo(tagInfo)
              } label: {
                Image(systemName: "info.circle")
              }
                .buttonStyle(.borderless)
                .popover(isPresented: tagInfoBinding(for: tagInfo),
                         arrowEdge: .bottom) {
                  TagInfoView(presentation: tagInfo)
                }
            }
          }
            .contextMenu {
              if let item {
                tagContextMenu(for: item.name)
              }
            }
            .tag(item?.name)
            .selectionDisabled(item == nil)
        }
      }
        .axid(.Sidebar.tagsList)
        .contextMenu(forSelectionType: TagRefName.self) { _ in
        }
        .overlay {
          if model.tags.isEmpty {
            model.contentUnavailableView("No Tags", systemImage: "tag")
          }
        }
      FilterBar(text: $model.filter)
    }
      .accessibilityElement(children: .contain)
      .axid(.Sidebar.tagsList)
  }

  private func tagInfoModel(for tag: Tagger.Tag) -> TagInfoModel
  {
    .init(tagName: tag.name.rawValue,
          authorName: tag.signature?.name ?? "-",
          authorEmail: tag.signature?.email ?? "",
          date: tag.signature?.when ?? .distantPast,
          message: tag.message ?? "")
  }

  private func tagInfoBinding(for info: TagInfoModel) -> Binding<Bool>
  {
    Binding(
        get: { coordinator.presentedTagInfo?.id == info.id },
        set: { isPresented in
          if isPresented {
            coordinator.showTagInfo(info)
          }
          else if coordinator.presentedTagInfo?.id == info.id {
            coordinator.dismissTagInfo()
          }
        })
  }

  @ViewBuilder
  private func tagContextMenu(for tagRef: TagRefName) -> some View
  {
    Button(.delete, systemImage: "trash", role: .destructive) {
      coordinator.deleteTag(tagRef)
    }
      .axid(.TagPopup.delete)
  }
}

#if false
struct TagListPreview: View
{
  struct Tag: EmptyTag
  {
    var name: TagRefName
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
      self.name = .named(name)!
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
    func tag(named name: TagRefName) -> Tag?
    {
      tagList.first { $0.name == name }
    }
    func createTag(name: String, targetOID: GitOID, message: String?) throws {}
    func createLightweightTag(name: String, targetOID: GitOID) throws {}
    
    func deleteTag(name: TagRefName) throws
    {
      if let index = tagList.firstIndex(where: { $0.name == name }) {
        tagList.remove(at: index)
        publisher.send()
      }
    }
  }

  let tagger: Tagger
  @State var selection: TagRefName?
  @State var expandedItems: Set<String> = []

  var body: some View
  {
    TagList(model: .init(tagger: tagger, publisher: tagger),
            selection: $selection,
            expandedItems: $expandedItems)
      .environmentObject(SidebarCoordinator())
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
