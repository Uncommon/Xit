import SwiftUI
import Combine
import XitGit

struct SubmoduleList<Manager: SubmoduleManagement>: View
{
  @ObservedObject var model: SubmoduleListModel<Manager>
  @Binding var selection: String?
  @EnvironmentObject private var coordinator: SidebarCoordinator

  var body: some View
  {
    VStack(spacing: 0) {
      List(model.submodules, id: \.name, selection: $selection) {
        submodule in
        Label(submodule.name, systemImage: "square.split.bottomrightquarter")
          .contextMenu {
            submoduleContextMenu(for: submodule.name)
          }
      }
        .contextMenu(forSelectionType: String.self) { _ in
        }
        .overlay {
        if model.submodules.isEmpty {
          model.contentUnavailableView(
              "No Submodules", systemImage: "square.split.bottomrightquarter")
        }
      }
      FilterBar(text: $model.filter) {
        SidebarActionButton {
          Button("Show in Finder", systemImage: "folder") {
            if let selection {
              coordinator.showSubmoduleInFinder(selection)
            }
          }
            .disabled(selection == nil)
          Button("Update", systemImage: "arrow.clockwise") {
            if let selection {
              coordinator.updateSubmodule(selection)
            }
          }
            .disabled(selection == nil)
        }
      }
    }
  }

  @ViewBuilder
  func submoduleContextMenu(for name: String) -> some View
  {
    Button("Show in Finder", systemImage: "folder") {
      coordinator.showSubmoduleInFinder(name)
    }
    Button("Update", systemImage: "arrow.clockwise") {
      coordinator.updateSubmodule(name)
    }
  }
}

#if false
struct SubmoduleListPreview
{
  struct Submodule: Xit.Submodule
  {
    var name: String
    var path: String
    var url: URL?
    
    var ignoreRule: SubmoduleIgnore = .unspecified
    var updateStrategy: SubmoduleUpdate = .default
    var recurse: SubmoduleRecurse = .yes
    
    func update(initialize: Bool, callbacks: RemoteCallbacks) throws {}
  }
  
  class SubmoduleManager: SubmoduleManagement
  {
    var submoduleList: [any Xit.Submodule] = []
    
    func submodules() -> [any Xit.Submodule] { submoduleList }
    func addSubmodule(path: String, url: String) throws {}
    
    init(submodules: [any Xit.Submodule] = [])
    {
      self.submoduleList = submodules
    }
  }
}
#endif
