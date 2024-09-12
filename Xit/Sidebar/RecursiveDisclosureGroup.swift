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
            RecursiveDisclosureGroup(subElements, id: id,
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

  init(_ data: Data,
       id: KeyPath<DataElement, ID>,
       children: KeyPath<DataElement, Data?>,
       expandedItems: Binding<Set<ID>>,
       @ViewBuilder content: @escaping (DataElement) -> RowContent)
  {
    self.data = data
    self.id = id
    self.children = children
    self.expandedItems = expandedItems
    self.content = content
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

extension RecursiveDisclosureGroup
{
  init<Item: PathTreeData>(
      _ data: Data,
      expandedItems: Binding<Set<String>>,
      @ViewBuilder content: @escaping (DataElement) -> RowContent)
    where Data == [PathTreeNode<Item>], ID == String
  {
    self.data = data
    self.id = \.path
    self.children = \.children
    self.expandedItems = expandedItems
    self.content = content
  }
}

#if DEBUG
struct RDGPreview: View
{
  let data: [PathTreeNode<String>]
  let folderPaths: [String]
  @State var expandedItems: Set<String> = []

  var body: some View
  {
    List {
      Section("RecursiveDisclosureGroup") {
        RecursiveDisclosureGroup(data, expandedItems: $expandedItems) {
          nodeLabel($0)
        }
      }
      Section("External toggles") {
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
      // For comparison
      Section("OutlineGroup") {
        OutlineGroup(data, id: \.path, children: \.children) {
          nodeLabel($0)
        }
      }
    }
  }

  func nodeLabel(_ node: PathTreeNode<String>) -> some View
  {
    Label {
      Text(node.path.lastPathComponent)
    } icon: {
      Image(systemName: node.children == nil ? "doc" : "folder")
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
#endif
