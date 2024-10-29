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
            // tried hiding this background when the row is selected,
            // but there is a delay so it doesn't look good.
            .background(isCurrent
                        ? AnyShapeStyle(.quaternary)
                        : AnyShapeStyle(.clear))
            .cornerRadius(4)
        },
        icon: {
          if branch == nil {
            Image(systemName: "folder.fill")
          }
          else {
            if isCurrent {
              Image(systemName: "checkmark.circle").fontWeight(.black)
            }
            else {
              Image("scm.branch")
            }
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
