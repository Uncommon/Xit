import Foundation
import AppKit
import SwiftUI

class TabbedSidebarController<Repo: FullRepository>:
  NSHostingController<TabbedSidebar<Repo, Repo, Repo, Repo>>
{
  init(repo: Repo,
       controller: any RepositoryUIController)
  {
    let view = TabbedSidebar(brancher: repo,
                             referencer: repo,
                             publisher: controller.repoController,
                             stasher: repo,
                             submoduleManager: repo,
                             tagger: repo,
                             selection: controller.selectionBinding)

    super.init(rootView: view)
  }
  
  @MainActor required dynamic init?(coder: NSCoder) 
  {
    fatalError("init(coder:) has not been implemented")
  }
}
