import Foundation
import SwiftUI

protocol TabItem: CaseIterable, Identifiable, Equatable {
  var imageName: String { get }
  var toolTip: UIString { get }
}

extension TabItem {
  var id: Self { self }
}

struct IconTabPicker<Item>: View where Item: TabItem {
  let items: [Item]
  let selection: Binding<Item>

  var body: some View {
    HStack {
      ForEach(items) {
        (item) in
        let isSelected = item == selection.wrappedValue
        Button(action: { selection.wrappedValue = item },
               label: {
          Image(systemName: item.imageName)
            .padding(.horizontal, 6)
            .contentShape(Rectangle()) // make padding hittable
        })
          .buttonStyle(.plain)
          .symbolVariant(isSelected ? .fill : .none)
          .foregroundColor(isSelected ? .accentColor : .primary)
          .help(item.toolTip.rawValue)
      }
    }
  }
}

struct IconTabPicker_Preview: View {
  @State var selection: SidebarTab = .local

  var body: some View {
    IconTabPicker(items: SidebarTab.allCases, selection: $selection)
  }
}
#Preview {
  IconTabPicker_Preview().padding()
}
