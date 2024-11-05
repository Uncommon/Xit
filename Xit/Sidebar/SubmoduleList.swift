import SwiftUI
import Combine

struct SubmoduleList<Manager: SubmoduleManagement>: View
{
  @ObservedObject var model: SubmoduleListModel<Manager>
  @Binding var selection: String?

  var body: some View
  {
    VStack {
      List(model.submodules, id: \.name, selection: $selection) {
        Label($0.name, systemImage: "square.split.bottomrightquarter")
      }.overlay {
        if model.submodules.isEmpty {
          model.contentUnavailableView(
              "No Submodules", systemImage: "square.split.bottomrightquarter")
        }
      }
      FilterBar(text: $model.filter)
    }
  }
}

#if DEBUG
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
