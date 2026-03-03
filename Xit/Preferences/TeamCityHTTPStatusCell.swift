import SwiftUI

// TODO: consolidate this back with AccountStatusCell once all services use the
// same superclass/protocol again.
struct TeamCityHTTPStatusCell: View
{
  @ObservedObject var service: TeamCityHTTPService
  
  @ViewBuilder
  static func `for`(service: TeamCityHTTPService?) -> some View
  {
    if let service {
      TeamCityHTTPStatusCell(service: service)
    }
    else {
      EmptyView()
    }
  }
  
  var body: some View
  {
    let imageName = statusImage(for: service)
    
    HStack {
      Spacer()
      if service.authenticationStatus == .inProgress {
        ProgressView().controlSize(.small)
      }
      else {
        Image(nsImage: .init(named: imageName)!)
      }
      Spacer()
    }
  }
  
  func statusImage(for service: TeamCityHTTPService) -> NSImage.Name
  {
    switch service.authenticationStatus {
      case .unknown, .notStarted:
        return NSImage.statusNoneName
      case .inProgress:
        return NSImage.statusPartiallyAvailableName
      case .done:
        break
      case .failed:
        return NSImage.statusUnavailableName
    }
    switch service.buildTypesStatus {
      case .unknown, .notStarted, .inProgress:
        return NSImage.statusAvailableName
      case .done:
        return NSImage.statusAvailableName
      case .failed:
        return NSImage.statusPartiallyAvailableName
    }
  }
}
