import Combine
import SwiftUI

class TagListViewModel<Tagger: Tagging,
                       Publisher: RepositoryPublishing>: ObservableObject
{
  let tagger: Tagger
  let publisher: Publisher

  @Published var tags: [PathTreeNode<Tagger.Tag>] = []
  @Published var filter: String = ""

  var sinks: [AnyCancellable] = []

  init(tagger: Tagger, publisher: Publisher)
  {
    self.tagger = tagger
    self.publisher = publisher

    setTagHierarchy()
    sinks.append(contentsOf: [
      publisher.refsPublisher.sinkOnMainQueue {
        [weak self] in
        self?.setTagHierarchy()
      },
      $filter
        .debounce(for: 0.5, scheduler: DispatchQueue.main)
        .sink {
          [weak self] _ in
          self?.setTagHierarchy()
        }
    ])
  }

  func setTagHierarchy()
  {
    let tagList = (try? tagger.tags()) ?? []
    var tags = PathTreeNode.makeHierarchy(from: tagList)

    if !filter.isEmpty {
      tags = tags.filtered(with: filter)
    }
    withAnimation {
      self.tags = tags
    }
  }
}
