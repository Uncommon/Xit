import SwiftUI

struct ServiceLabel: View
{
  let type: AccountType
  @Environment(\.lineSpacing) var lineSpacing: CGFloat

  var body: some View
  {
    // Using `Label` doesn't work in menus
    HStack {
      Image(type.imageName)
        .renderingMode(.template)
        .imageScale(.large)
        .frame(width: 18)
      Text(type.displayName)
    }
  }

  init(_ type: AccountType)
  {
    self.type = type
  }
}

struct AccountsPrefsPane: View
{
  let bottomBarHeight: CGFloat = 21
  let accountsManager: AccountsManager
  let services: Services

  @State var selectedAccount: UUID?
  @State var newAccountInfo: AccountInfo?
  @State var editAccountInfo: AccountInfo?

  @State var showAlert: Bool = false
  @State var passwordError: PasswordError?

  var body: some View
  {
    VStack(spacing: -1) {
      Table(accountsManager.accounts, selection: $selectedAccount) {
        TableColumn("Service", content: { ServiceLabel($0.type) })
            .width(min: 40, ideal: 80)
        TableColumn("User name", value: \.user)
        TableColumn("Location", value: \.location.absoluteString)
            .width(min: 40, ideal: 150)
        TableColumn("Status", content: serviceStatus).width(47)
      }.tableStyle(.bordered)
      HStack {
        HStack(spacing: 0) {
          Button(action: addNewAccount, label: { Image(systemName: "plus") })
            .frame(width: bottomBarHeight)
            .sheet(item: $newAccountInfo, content: newAccountSheet(_:))
          Divider()
          Button(action: deleteAccount, label: { Image(systemName: "minus") })
            .frame(width: bottomBarHeight)
            .disabled(selectedAccount == nil)
          Divider()
        }.buttonStyle(.plain)
        Spacer()
        HStack {
          Button(action: editAccount, label: { Image(systemName: "pencil") })
            .disabled(selectedAccount == nil)
            .sheet(item: $editAccountInfo, content: editAccountSheet(_:))
          Button(action: refreshAccount,
                 label: { Image(systemName: "arrow.clockwise.circle.fill") })
            .padding([.trailing], 4)
        }.buttonStyle(.plain)
      }.background(.tertiary)
        .frame(height: bottomBarHeight)
        .border(.tertiary)
    }.alert(isPresented: $showAlert, error: passwordError) {
      Button(.ok, action: { showAlert = false })
    }
  }

  func statusImage(forTeamCity api: TeamCityAPI?) -> NSImage.Name
  {
    guard let api = api
    else { return NSImage.statusUnavailableName }

    switch api.authenticationStatus {
      case .unknown, .notStarted:
        return NSImage.statusNoneName
      case .inProgress:
        // eventually have a spinner instead
        return NSImage.statusPartiallyAvailableName
      case .done:
        break
      case .failed:
        return NSImage.statusUnavailableName
    }

    switch api.buildTypesStatus {
      case .unknown, .notStarted, .inProgress:
        return NSImage.statusAvailableName
      case .done:
        return NSImage.statusAvailableName
      case .failed:
        return NSImage.statusPartiallyAvailableName
    }
  }

  func statusImage(forService api: BasicAuthService?) -> NSImage.Name
  {
    guard let api = api
    else { return NSImage.statusUnavailableName }

    switch api.authenticationStatus {
      case .unknown, .notStarted:
        return NSImage.statusNoneName
      case .inProgress:
        // eventually have a spinner instead
        return NSImage.statusPartiallyAvailableName
      case .done:
        return NSImage.statusAvailableName
      case .failed:
        return NSImage.statusUnavailableName
    }
  }

  func serviceStatus(_ account: Account) -> some View
  {
    let service = services.service(for: account)
    let imageName = statusImage(forService: service)

    return HStack {
      Spacer()
      Image(nsImage: .init(named: imageName)!)
      Spacer()
    }
  }

  func newAccountSheet(_ info: AccountInfo) -> some View
  {
    var info = info
    let binding = Binding<AccountInfo>(get: { info }, set: { info = $0 })

    return accountInfoSheet(for: binding, title: "Create",
                            action: { addAccount(from: info) },
                            cancel: { newAccountInfo = nil })
  }

  func editAccountSheet(_ info: AccountInfo) -> some View
  {
    var info = info
    let binding = Binding<AccountInfo>(get: { info }, set: { info = $0 })

    return accountInfoSheet(for: binding, title: "Save",
                            action: { modifyAccount(with: info) },
                            cancel: { editAccountInfo = nil })
  }

  func accountInfoSheet(for binding: Binding<AccountInfo>,
                        title: String,
                        action: @escaping () -> Void,
                        cancel: @escaping () -> Void) -> some View
  {
    VStack {
      EditAccountPanel(model: binding.wrappedValue)
      DialogButtonRow(validator: binding.wrappedValue, buttons: [
        (.cancel, cancel),
        (.accept(title), action),
      ])
    }.padding()
  }

  func addNewAccount()
  {
    newAccountInfo = AccountInfo() // trigger the sheet
  }

  func addAccount(from info: AccountInfo)
  {
    do {
      let account = Account(type: info.serviceType,
                            user: info.userName,
                            location: .init(string: info.location)!,
                            id: info.id)

      try accountsManager.add(account, password: info.password)
    }
    catch let error as PasswordError {
      self.passwordError = error
      showAlert = true
    }
    catch {}
  }

  func modifyAccount(with info: AccountInfo)
  {
    guard let account = accountsManager.accounts
                                       .first(where: { $0.id == info.id })
    else { return }

    account.type = info.serviceType
    account.user = info.userName
    account.location = URL(string: info.location)!
  }

  func deleteAccount()
  {

  }

  func editAccount()
  {
    guard let selectedAccount = selectedAccount,
          let account = accountsManager.accounts
                                       .first(where: { $0.id == selectedAccount })
    else { return }
    let password = accountsManager.passwordStorage.find(account: account) ?? ""

    editAccountInfo = AccountInfo(with: account, password: password)
  }

  func refreshAccount()
  {
    // tell the account service to log in again
  }
}

struct AccountsPrefsPane_Previews: PreviewProvider
{
  static let manager: AccountsManager = {
    let accounts: [Account] = [
      .init(type: .gitHub, user: "This guy",
            location: .init(string:"https://github.com")!, id: .init()),
      .init(type: .teamCity, user: "Person",
            location: .init(string:"https://teamcity.com")!, id: .init()),
      .init(type: .gitLab, user: "Henry",
            location: .init(string:"https://gitlab.com")!, id: .init()),
      .init(type: .bitbucketServer, user: "Hank",
            location: .init(string:"https://bitbucket.com")!, id: .init()),
    ]
    let manager = AccountsManager(defaults: .testing,
                                  passwordStorage: NoOpKeychain())

    UserDefaults.testing.accounts = accounts
    manager.readAccounts()
    return manager
  }()
  static let services = Services(passwordStorage: NoOpKeychain())

  static var previews: some View
  {
    AccountsPrefsPane(accountsManager: manager, services: services)
      .padding().frame(height: 300.0)
  }
}
