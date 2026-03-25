import Foundation

public protocol DiffStats
{
  var filesChanged: Int { get }
  var insertions: Int { get }
  var deletions: Int { get }
}

final class GitDiffStats: DiffStats
{
  let stats: OpaquePointer

  var filesChanged: Int
  { git_diff_stats_files_changed(stats) }
  var insertions: Int
  { git_diff_stats_insertions(stats) }
  var deletions: Int
  { git_diff_stats_deletions(stats) }

  init(stats: OpaquePointer)
  {
    self.stats = stats
  }

  deinit
  {
    git_diff_stats_free(stats)
  }
}
