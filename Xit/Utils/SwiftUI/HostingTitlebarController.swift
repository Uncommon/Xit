import Foundation
import SwiftUI

class HostingTitlebarController<T>: NSTitlebarAccessoryViewController
  where T: View
{
  init(rootView: T)
  {
    super.init(nibName: nil, bundle: nil)
    view = NSView()
    view.translatesAutoresizingMaskIntoConstraints = false

    let host = NSHostingController(rootView: rootView)

    host.view.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(host.view)
    NSLayoutConstraint.activate([
      view.topAnchor.constraint(equalTo: host.view.topAnchor),
      view.bottomAnchor.constraint(equalTo: host.view.bottomAnchor),
      view.leadingAnchor.constraint(equalTo: host.view.leadingAnchor),
      view.trailingAnchor.constraint(equalTo: host.view.trailingAnchor),
    ])
    addChild(host)
  }

  required init?(coder: NSCoder)
  {
    fatalError("init(coder:) has not been implemented")
  }
}
