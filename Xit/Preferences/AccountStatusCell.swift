import SwiftUI

struct AccountStatusCell: View
{
  @ObservedObject var service: BaseHTTPService
  
  @ViewBuilder
  static func `for`(service: BaseHTTPService?) -> some View
  {
    if let service {
      AccountStatusCell(service: service)
    }
    else {
      EmptyView()
    }
  }
  
  var body: some View
  {
    HStack {
      Spacer()
      if service.authenticationStatus == .inProgress {
        ProgressView().controlSize(.small)
      }
      else {
        Image(nsImage: .init(named: statusImage(for: service))!)
      }
      Spacer()
    }
  }
  
  private func statusImage(for service: BaseHTTPService) -> NSImage.Name
  {
    if let teamCity = service as? TeamCityService {
      switch teamCity.authenticationStatus {
        case .unknown, .notStarted:
          return NSImage.statusNoneName
        case .inProgress:
          return NSImage.statusPartiallyAvailableName
        case .done:
          break
        case .failed:
          return NSImage.statusUnavailableName
      }
      switch teamCity.buildTypesStatus {
        case .unknown, .notStarted, .inProgress:
          return NSImage.statusAvailableName
        case .done:
          return NSImage.statusAvailableName
        case .failed:
          return NSImage.statusPartiallyAvailableName
      }
    }
    return switch service.authenticationStatus {
      case .unknown, .notStarted:
        NSImage.statusNoneName
      case .inProgress:
        NSImage.statusPartiallyAvailableName
      case .done:
        NSImage.statusAvailableName
      case .failed:
        NSImage.statusUnavailableName
    }
  }
}
