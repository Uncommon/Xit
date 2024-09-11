import SwiftUI

/// A partial re-implementation of `OutlineGroup` with the addition of a binding
/// to read and write the set of expanded items.
struct RecursiveDisclosureGroup<Data, ID, RowContent>: View
  where Data: RandomAccessCollection, ID: Hashable, RowContent: View
{
  typealias DataElement = Data.Element

  let data: Data
  let id: KeyPath<DataElement, ID>
  let children: KeyPath<DataElement, Data?>
  let expandedItems: Binding<Set<ID>>
  let content: (DataElement) -> RowContent

  var body: some View
  {
    ForEach(data, id: id) {
      (element) in
      if let subElements = element[keyPath: children] {
        DisclosureGroup(
          isExpanded: binding(for: element[keyPath: id]),
          content: {
            RecursiveDisclosureGroup(data: subElements, id: id,
                                     children: children,
                                     expandedItems: expandedItems,
                                     content: content)
          },
          label: { content(element) }
        )
      }
      else {
        content(element)
      }
    }
  }

  private func binding(for id: ID) -> Binding<Bool>
  {
    .init {
      expandedItems.wrappedValue.contains(id)
    } set: {
      if $0 {
        expandedItems.wrappedValue.insert(id)
      }
      else {
        expandedItems.wrappedValue.remove(id)
      }
    }
  }
}

struct RDGPreview: View
{
  let data: [PathTreeNode<String>]
  let folderPaths: [String]
  @State var expandedItems: Set<String> = []

  var body: some View
  {
    List {
      RecursiveDisclosureGroup(data: data,
                               id: \.self.path,
                               children: \.children,
                               expandedItems: $expandedItems) {
        Text($0.path.lastPathComponent)
      }
      // This generates a checkbox for every item. All that is really needed
      // is a checkbox for every folder, but filtering those out is too much
      // work for a preview.
      ForEach(folderPaths, id: \.self) {
        (path) in
        Toggle(path, isOn: .init {
          expandedItems.contains(path)
        } set: {
          if $0 {
            expandedItems.insert(path)
          }
          else {
            expandedItems.remove(path)
          }
        })
      }
    }
  }

  init(_ paths: [String])
  {
    self.data = PathTreeNode.makeHierarchy(from: paths)
    self.folderPaths = paths
  }
}

#Preview {
  // The preview relies on having an explicit item for every folder
  // so there can be a checkbox for it.
  RDGPreview([
    "folder",
    "folder/item",
    "folder/folder2",
    "folder/folder2/item2",
  ])
}
