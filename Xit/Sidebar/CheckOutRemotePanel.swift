import SwiftUI

struct CheckOutRemotePanel: View {
  class Model: ObservableObject
  {
    @Published var branchName: String = ""
    @Published var checkOut: Bool = true
    
    init(branchName: String = "", checkOut: Bool = true)
    {
      self.branchName = branchName
      self.checkOut = checkOut
    }
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
  @State private var status: BranchNameStatus
  
  var body: some View {
    VStack(alignment: .leading) {
      Text("Create a local branch tracking \"\(originBranch)\"")
        .accessibilityIdentifier(.CreateTracking.prompt)
      HStack(alignment: .firstTextBaseline) {
        Text(.name.colon)
        VStack(alignment: .leading) {
          TextField("", text: $model.branchName)
            .accessibilityIdentifier(.CreateTracking.branchName)
          Toggle("Check out new branch", isOn: $model.checkOut)
            .accessibilityIdentifier(.CreateTracking.checkOut)
        }
      }
      HStack {
        if !model.branchName.isEmpty {
          Text(status.text).foregroundColor(.red)
            .accessibilityIdentifier(.CreateTracking.errorMessage)
        }
        Spacer()
        Button(.cancel, action: cancelAction).keyboardShortcut(.cancelAction)
          .accessibilityIdentifier(.Button.cancel)
        Button(.create, action: createAction).keyboardShortcut(.defaultAction)
          .disabled(status != .valid)
          .accessibilityIdentifier(.Button.accept)
      }
        .onSubmit(createAction)
    }.frame(width: 410)
      .onChange(of: model.branchName) {
        (_, newValue) in
        status = validateBranch(newValue)
      }
  }
  
  init(model: Model,
       originBranch: String,
       validateBranch: @escaping (String) -> BranchNameStatus,
       cancelAction: @escaping () -> Void,
       createAction: @escaping () -> Void) {
    self.model = model
    self.originBranch = originBranch
    self.validateBranch = validateBranch
    self.cancelAction = cancelAction
    self.createAction = createAction
    self.status = validateBranch(model.branchName)
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
        model: {
          let model = CheckOutRemotePanel.Model()
          model.branchName = "name"
          return model
        }(),
        originBranch: "origin/something/branch",
        validateBranch: { _ in .invalid },
        cancelAction: {},
        createAction: {}).padding()
      .previewDisplayName("Invalid")
  }
}
