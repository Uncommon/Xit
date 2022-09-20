import SwiftUI

enum SearchDirection
{
  case up, down
}

struct HistorySearchBar: View
{
  @State var searchType: HistorySearchType = .summary
  @State var searchString: String = ""

  let searchUp: (String, HistorySearchType) -> Void
  let searchDown: (String, HistorySearchType) -> Void

  var body: some View
  {
    HStack {
      Picker(selection: $searchType) {
        ForEach(HistorySearchType.allCases, id: \.self) {
          Text($0.displayName.rawValue)
        }
      } label: {
        EmptyView()
      }.fixedSize()
        .accessibilityIdentifier(.Search.typePopup)

      SearchField($searchString, prompt: "Search")
        .onSearch {
          searchDown($0, searchType)
        }
        .accessibilityIdentifier(.Search.field)

      ControlGroup {
        Button {
          searchUp(searchString, searchType)
        } label: {
          Image(systemName: "chevron.up")
        }.accessibilityIdentifier(.Search.up)
        Button {
          searchDown(searchString, searchType)
        } label: {
          Image(systemName: "chevron.down")
        }.accessibilityIdentifier(.Search.down)
      }.fixedSize().disabled(searchString.isEmpty)
    }.padding([.horizontal])
  }
}

struct HistorySearchBar_Previews: PreviewProvider
{
  static var previews: some View
  {
    HistorySearchBar(searchUp: { (_, _) in }, searchDown: { (_, _) in })
  }
}
