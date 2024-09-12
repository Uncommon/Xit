import Foundation
import AppKit
import SwiftUI

class TabbedSidebarController: NSHostingController<TabbedSidebar>
{
  init(repo: any FullRepository, publisher: any RepositoryPublishing)
  {
    let view = TabbedSidebar(repo: repo, publisher: publisher)

    super.init(rootView: view)
  }
  
  @MainActor required dynamic init?(coder: NSCoder) 
  {
    fatalError("init(coder:) has not been implemented")
  }
}
