import Combine
import SwiftUI

class TagListViewModel<Tagger: Tagging,
                       Publisher: RepositoryPublishing>: FilteringListViewModel
{
  let tagger: Tagger
  let publisher: Publisher

  @Published var tags: [PathTreeNode<Tagger.Tag>] = []

  init(tagger: Tagger, publisher: Publisher)
  {
    self.tagger = tagger
    self.publisher = publisher
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
