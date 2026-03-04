import SwiftUI

// TODO: consolidate this back with AccountStatusCell once all services use the
// same superclass/protocol again.
struct HTTPAccountStatusCell: View
{
  @ObservedObject var service: BaseHTTPService
  
  @ViewBuilder
  static func `for`(service: BaseHTTPService?) -> some View
  {
    if let service {
      HTTPAccountStatusCell(service: service)
    }
    else {
      EmptyView()
    }
  }
  
  var body: some View
  {
    let imageName: NSImage.Name = switch service.authenticationStatus {
      case .unknown, .notStarted:
        NSImage.statusNoneName
      case .inProgress:
        NSImage.statusPartiallyAvailableName
      case .done:
        NSImage.statusAvailableName
      case .failed:
        NSImage.statusUnavailableName
    }
    
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
}
