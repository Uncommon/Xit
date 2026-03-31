import Foundation
import SwiftUI

protocol TabItem: Identifiable, Equatable {
  associatedtype Icon: View

  var icon: Icon { get }
  var toolTip: UIString { get }
}

extension TabItem {
  var id: Self { self }
}

struct IconPicker<Item>: View where Item: TabItem {
  let items: [Item]
  let showsDividers: Bool
  let spacing: CGFloat
  @Binding var selection: Item

  var body: some View {
    HStack(spacing: 4) {
      ForEach(items) {
        (item) in
        let isSelected = item == selection
        // Use TupleView so that the buttons and dividers are
        // all subviews of the HStack.
        TupleView((
          Button(action: { selection = item },
                 label: {
            item.icon
              .padding(.horizontal, spacing)
              .contentShape(Rectangle()) // make padding hittable
          })
            .buttonStyle(.plain)
            .symbolVariant(isSelected ? .fill : .none)
            .foregroundColor(isSelected ? .accentColor : .primary)
            .help(item.toolTip.rawValue)
            .accessibilityIdentifier(item.toolTip.rawValue),
          showsDividers && item.id != items.last?.id
            ? AnyView(Divider().frame(height: 16))
            : AnyView(EmptyView())
        ))
      }
    }
  }

  init(items: [Item],
       selection: Binding<Item>,
       showsDividers: Bool = true,
       spacing: CGFloat = 6)
  {
    self.items = items
    self._selection = selection
    self.showsDividers = showsDividers
    self.spacing = spacing
  }
}

struct IconTabPicker_Preview: View {
  let showsDividers: Bool
  @State var selection: SidebarTab = .local(modified: false)

  var body: some View {
    IconPicker(items: SidebarTab.cleanCases, selection: $selection, showsDividers: showsDividers)
  }
}

#Preview("Divider") {
  IconTabPicker_Preview(showsDividers: true).padding()
}

#Preview("No Divider") {
  IconTabPicker_Preview(showsDividers: false).padding()
}
