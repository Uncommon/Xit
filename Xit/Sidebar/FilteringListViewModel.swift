import Combine
import SwiftUI

class FilteringListViewModel: ObservableObject
{
  @Published var filter: String = ""
  var sinks: [AnyCancellable] = []
  
  init()
  {
    sinks.append($filter
      .debounce(for: 0.5, scheduler: DispatchQueue.main)
      .sink {
        [weak self] in
        self?.filterChanged($0)
      }
    )
  }
  
  func filterChanged(_ newFilter: String)
  {
    assertionFailure("filterChanged not implemented")
  }
  
  // TODO: Probably should be moved out of the view model and into a protocol
  @ViewBuilder
  func contentUnavailableView(_ label: String,
                              systemImage: String) -> some View
  {
    if filter.isEmpty {
      ContentUnavailableView(label, systemImage: systemImage)
    }
    else {
      ContentUnavailableView.search(text: filter)
    }
  }
  
  @ViewBuilder
  func contentUnavailableView(_ label: String,
                              image: String) -> some View
  {
    if filter.isEmpty {
      ContentUnavailableView(label, image: image)
    }
    else {
      ContentUnavailableView.search(text: filter)
    }
  }
}
