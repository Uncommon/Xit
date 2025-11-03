import SwiftUI

/// List cell view used by local and remote branch lists.
struct BranchCell<Item: PathTreeData, TrailingContent: View>: View
{
  let node: PathTreeNode<Item>
  let isCurrent: Bool
  @ViewBuilder
  let trailingContent: () -> TrailingContent

  var body: some View
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
  {
    self.node = node
    self.isCurrent = isCurrent
    self.trailingContent = trailingContent
  }
}

