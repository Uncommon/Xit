import SwiftUI

struct GeneralPrefsPane: View
{
  let defaults: UserDefaults
  let config: any Config

  @AppStorage var collapseHistory: Bool
  @AppStorage var deemphasize: Bool
  @AppStorage var resetAmend: Bool
  @AppStorage var tabStatus: Bool
  @ConfigValue var userName: String
  @ConfigValue var userEmail: String
  @AppStorage var fetchTags: Bool
  @ConfigValue var pruneBranches: Bool

  var body: some View
  {
    VStack(alignment: .leading) {
      LabeledField("Interface options:", VStack(alignment: .leading) {
        Toggle("Collapse history list in Staging view", isOn: $collapseHistory)
          .accessibilityIdentifier(.Preferences.Controls.collapseHistory)
        Toggle("De-emphasize merge commits", isOn: $deemphasize)
          .accessibilityIdentifier(.Preferences.Controls.deemphasize)
        Toggle("Automatically reset \"Amend\"", isOn: $resetAmend)
          .accessibilityIdentifier(.Preferences.Controls.resetAmend)
        Toggle("Workspace status in tabs", isOn: $tabStatus)
          .accessibilityIdentifier(.Preferences.Controls.tabStatus)
      }.fixedSize())
      LabeledField("User name:", TextField(text: $userName, label: { EmptyView() }))
      LabeledField("User email:", TextField(text: $userEmail, label: { EmptyView() }))
      LabeledField("Fetch options:", VStack(alignment: .leading) {
        Toggle("Download tags", isOn: $fetchTags)
        Toggle("Prune branches", isOn: $pruneBranches)
      }.fixedSize())
    }.labelWidthGroup().frame(minWidth: 350)
  }

  init(defaults: UserDefaults, config: any Config)
  {
    self.defaults = defaults
    self.config = config
    self._collapseHistory = .init(wrappedValue: false,
                                  PreferenceKeys.collapseHistory,
                                  store: defaults)
    self._deemphasize = .init(wrappedValue: false,
                              PreferenceKeys.deemphasizeMerges,
                              store: defaults)
    self._resetAmend = .init(wrappedValue: false,
                             PreferenceKeys.resetAmend,
                             store: defaults)
    self._tabStatus = .init(wrappedValue: false,
                            PreferenceKeys.statusInTabs,
                            store: defaults)
    self._userName = .init(key: "user.name", config: config, default: "")
    self._userEmail = .init(key: "user.email", config: config, default: "")
    self._fetchTags = .init(wrappedValue: false,
                            PreferenceKeys.fetchTags,
                            store: defaults)
    self._pruneBranches = .init(key: "fetch.prune", config: config, default: false)
  }
}

struct GeneralPrefsPane_Previews: PreviewProvider
{
  static var tempDefaults: UserDefaults = {
    let defaults = UserDefaults(suiteName: "xit-temp")!
    defaults.removePersistentDomain(forName: "xit-temp")
    return defaults
  }()
  static var config = DictionaryConfig()

  static var previews: some View
  {
    GeneralPrefsPane(defaults: tempDefaults, config: config).padding()
  }
}
