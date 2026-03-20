import SwiftUI
import XitGit

/// List cell view used by local and remote branch lists.
struct BranchCell<Item: PathTreeData,
                  TrailingContent: View,
                  ContextMenuContent: View>: View
{
  let node: PathTreeNode<Item>
  let isCurrent: Bool
  let hasContextMenu: Bool
  @ViewBuilder
  let trailingContent: () -> TrailingContent
  @ViewBuilder
  let contextMenuContent: () -> ContextMenuContent

  var body: some View
  {
    if hasContextMenu {
      row.contextMenu(menuItems: contextMenuContent)
    }
    else {
      row
    }
  }

  @ViewBuilder
  private var row: some View
  {
    let branch = node.item

    HStack {
      Label(
        title: {
          ExpansionText(node.path.lastPathComponent,
                        font: .systemFontSized(weight: isCurrent ? .bold
                                                                 : .regular))
            .padding(.horizontal, 4)
            .cornerRadius(4)
            // Putting the ID on the cell doesn't work, so put it here.
            .accessibilityIdentifier(isCurrent ? "currentBranch" : "branch")
        },
        icon: {
          if branch == nil {
            Image(systemName: "folder.fill")
          }
          else {
            Image("scm.branch")
              .background(
                isCurrent
                  ? AnyView(Image(systemName: "checkmark")
                    .offset(x: -18, y: 0))
                  : AnyView(EmptyView())
              )
              .fontWeight(isCurrent ? .bold : .regular)
              .accessibilityElement()
              .axid(isCurrent ? .Sidebar.currentBranchCheck : .empty)
          }
        }
      )
      Spacer()
      trailingContent()
    }
      .contentShape(Rectangle())
      .listRowSeparator(.hidden)
      .selectionDisabled(branch == nil)
  }

  init(node: PathTreeNode<Item>,
       isCurrent: Bool = false,
       @ViewBuilder trailingContent: @escaping () -> TrailingContent)
    where ContextMenuContent == EmptyView
  {
    self.node = node
    self.isCurrent = isCurrent
    self.hasContextMenu = false
    self.trailingContent = trailingContent
    self.contextMenuContent = { EmptyView() }
  }

  init(node: PathTreeNode<Item>,
       isCurrent: Bool = false,
       @ViewBuilder trailingContent: @escaping () -> TrailingContent,
       @ViewBuilder contextMenu: @escaping () -> ContextMenuContent)
  {
    self.node = node
    self.isCurrent = isCurrent
    self.hasContextMenu = true
    self.trailingContent = trailingContent
    self.contextMenuContent = contextMenu
  }
}
