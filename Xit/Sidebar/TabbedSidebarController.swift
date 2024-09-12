import Foundation
import AppKit
import SwiftUI

class TabbedSidebarController: NSHostingController<TabbedSidebar>
{
  init(repo: any FullRepository,
       controller: any RepositoryUIController)
  {
    let view = TabbedSidebar(repo: repo,
                             publisher: controller.repoController,
                             selection: controller.selectionBinding)

    super.init(rootView: view)
  }
  
  @MainActor required dynamic init?(coder: NSCoder) 
  {
    fatalError("init(coder:) has not been implemented")
  }
}
