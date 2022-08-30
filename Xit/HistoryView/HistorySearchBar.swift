import SwiftUI

enum HistorySearchType: CaseIterable
{
  case summary, author, committer, sha

  var displayName: UIString
  {
    switch self {
      case .summary: return .init(rawValue: "Summary")
      case .author: return .init(rawValue: "Author")
      case .committer: return .init(rawValue: "Committer")
      case .sha: return .init(rawValue: "SHA")
    }
  }
}

enum SearchDirection
{
  case up, down
}

struct HistorySearchBar: View
{
  @State var searchType: HistorySearchType = .summary
  @State var searchString: String = ""

  let searchUp: (String) -> Void
  let searchDown: (String) -> Void

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
        .onSearch(searchDown)
        .accessibilityIdentifier(.Search.field)

      ControlGroup {
        Button {
          searchUp(searchString)
        } label: {
          Image(systemName: "chevron.up")
        }.accessibilityIdentifier(.Search.up)
        Button {
          searchDown(searchString)
        } label: {
          Image(systemName: "chevron.down")
        }.accessibilityIdentifier(.Search.down)
      }.fixedSize().disabled(searchString.isEmpty)
    }.padding()
  }
}

struct HistorySearchBar_Previews: PreviewProvider
{
  static var previews: some View
  {
    HistorySearchBar(searchUp: {_ in}, searchDown: {_ in})
  }
}
