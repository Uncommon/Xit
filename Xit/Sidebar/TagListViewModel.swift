import Combine
import SwiftUI

class TagListViewModel<Tagger: Tagging>: FilteringListViewModel
{
  let tagger: Tagger

  @Published var tags: [PathTreeNode<Tagger.Tag>] = []

  init(tagger: Tagger, publisher: any RepositoryPublishing)
  {
    self.tagger = tagger
    super.init()

    setTagHierarchy()
    sinks.append(publisher.refsPublisher.sinkOnMainQueue {
      [weak self] in
      self?.setTagHierarchy()
    })
  }

  func setTagHierarchy()
  {
    let tagList = (try? tagger.tags()) ?? []
    var tags = PathTreeNode.makeHierarchy(from: tagList)

    if !filter.isEmpty {
      tags = tags.filtered(with: filter)
    }
    self.tags = tags
  }
  
  override func filterChanged(_ newFilter: String)
  {
    setTagHierarchy()
  }
}
