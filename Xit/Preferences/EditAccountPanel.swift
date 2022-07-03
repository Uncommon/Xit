import SwiftUI

class AccountInfo: ObservableObject, Identifiable
{
  @Published var serviceType: AccountType
  @Published var location: String
  @Published var userName: String
  @Published var password: String
  let id: UUID

  init()
  {
    self.serviceType = .allCases.first!
    self.location = ""
    self.userName = ""
    self.password = ""
    self.id = .init()
  }

  init(with account: Account, password: String)
  {
    self.serviceType = account.type
    self.location = account.location.absoluteString
    self.userName = account.user
    self.password = password
    self.id = account.id
  }
}

extension AccountInfo: Validating
{
  var isValid: Bool
  {
    !userName.isEmpty &&
    (!serviceType.needsLocation || URL(string: location) != nil)
  }
}

struct EditAccountPanel: DataModelView
{
  typealias Model = AccountInfo
  @ObservedObject var model: AccountInfo

  var body: some View
  {
    VStack {
      LabeledField("Service:", Picker(selection: $model.serviceType) {
        ForEach(AccountType.allCases, id: \.self) {
          (type) in
          ServiceLabel(type)
        }
      } label: { EmptyView() })
      LabeledField("Location:", TextField("", text: $model.location))
      LabeledField("User name:", TextField("", text: $model.userName))
      LabeledField("Password:", SecureField("", text: $model.password))
    }.labelWidthGroup()
  }

  init()
  {
    self.model = .init()
  }

  init(model: AccountInfo)
  {
    self.model = model
  }
}

struct EditAccountPanel_Previews: PreviewProvider
{
  static var model: AccountInfo = .init()

  static var previews: some View
  {
    VStack {
      EditAccountPanel(model: model)
      DialogButtonRow(validator: model, buttons: [
        (.cancel, {}),
        (.accept("Save"), {}),
      ])
    }
    .padding()
    .frame(width: 320.0)
  }
}
