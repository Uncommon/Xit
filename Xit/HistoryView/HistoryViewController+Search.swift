import Foundation

enum HistorySearch
{
  static func matchingIndex<Commits: RandomAccessCollection>(
      in commits: Commits,
      selectedIndex: Int,
      text: String,
      type: HistorySearchType,
      direction: SearchDirection)
    -> Int?
    where Commits.Element: Commit, Commits.Index == Int
  {
    let search = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !search.isEmpty, !commits.isEmpty
    else { return nil }

    let normalizedSearch = search.lowercased()

    switch direction {
      case .up:
        var index = min(selectedIndex - 1, commits.count - 1)

        while index >= 0 {
          if matches(commits[index], text: normalizedSearch, type: type) {
            return index
          }
          index -= 1
        }
      case .down:
        var index = max(selectedIndex + 1, 0)

        while index < commits.count {
          if matches(commits[index], text: normalizedSearch, type: type) {
            return index
          }
          index += 1
        }
    }

    return nil
  }

  static func matches<C: Commit>(_ commit: C,
                                 text: String,
                                 type: HistorySearchType)
    -> Bool
  {
    switch type {
      case .summary:
        commit.messageSummary.lowercased().contains(text)
      case .author:
        commit.authorSig?.contains(text) ?? false
      case .committer:
        commit.committerSig?.contains(text) ?? false
      case .sha:
        commit.id.sha.rawValue.lowercased().hasPrefix(text)
    }
  }
}

extension HistoryViewController
{
  func search(for text: String,
              type: HistorySearchType,
              direction: SearchDirection)
  {
    let entries = tableController.history.entries
    let commits = entries.lazy.map(\.commit)

    guard let index = HistorySearch.matchingIndex(in: commits,
                                                  selectedIndex: historyTable.selectedRow,
                                                  text: text,
                                                  type: type,
                                                  direction: direction)
    else { return }

    historyTable.selectRowIndexes(IndexSet(integer: index),
                                  byExtendingSelection: false)
    historyTable.scrollRowToVisible(index)
  }
}
