import SwiftUI

struct CheckOutRemotePanel: View {
  class Model: ObservableObject
  {
    @Published var branchName: String = ""
    @Published var checkOut: Bool = true
  }
  
  enum BranchNameStatus
  {
    case valid, invalid, conflict
    
    var text: UIString
    {
      switch self {
        case .valid: return .empty
        case .invalid: return .branchNameInvalid
        case .conflict: return .branchNameExists
      }
    }
  }
  
  @ObservedObject var model: Model
  let originBranch: String
  let validateBranch: (String) -> BranchNameStatus
  let cancelAction, createAction: () -> Void
  
  var body: some View {
    let status = validateBranch(model.branchName)
    
    VStack(alignment: .leading) {
      Text("Create a local branch tracking \(originBranch)")
      HStack(alignment: .firstTextBaseline) {
        Text(.name.colon)
        VStack(alignment: .leading) {
          TextField("", text: $model.branchName)
          Toggle("Check out new branch", isOn: $model.checkOut)
        }
      }
      HStack {
        if !model.branchName.isEmpty {
          Text(status.text).foregroundColor(.red)
        }
        Spacer()
        Button(.cancel, action: {}).keyboardShortcut(.cancelAction)
        Button(.create, action: {}).keyboardShortcut(.defaultAction)
          .disabled(status != .valid)
      }
        .onSubmit(createAction)
    }.frame(width: 410)
  }
}

struct CheckOutRemotePanel_Previews: PreviewProvider {
  @State static var branchName = "branch"
  
  static var previews: some View {
    CheckOutRemotePanel(
        model: .init(),
        originBranch: "origin/something/branch",
        validateBranch: { _ in .valid },
        cancelAction: {},
        createAction: {}).padding()
      .previewDisplayName("Valid")
    CheckOutRemotePanel(
        model: .init(),
        originBranch: "origin/something/branch",
        validateBranch: { _ in .invalid },
        cancelAction: {},
        createAction: {}).padding()
      .previewDisplayName("Invalid")
  }
}
