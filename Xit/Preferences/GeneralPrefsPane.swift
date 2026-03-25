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
  @AppStorage var guideWidth: Int
  @AppStorage var showGuide: Bool

  var body: some View
  {
    Form {
      LabeledContent("Interface options:") {
        VStack(alignment: .leading) {
          Toggle("Collapse history list in Staging view", isOn: $collapseHistory)
            .accessibilityIdentifier(.Preferences.Controls.collapseHistory)
          Toggle("De-emphasize merge commits", isOn: $deemphasize)
            .accessibilityIdentifier(.Preferences.Controls.deemphasize)
          Toggle("Automatically reset \"Amend\"", isOn: $resetAmend)
            .accessibilityIdentifier(.Preferences.Controls.resetAmend)
          Toggle("Workspace status in tabs", isOn: $tabStatus)
            .accessibilityIdentifier(.Preferences.Controls.tabStatus)
        }.fixedSize()
      }
      TextField("User name:", text: $userName)
      TextField("User email:", text: $userEmail)
      LabeledContent("Fetch options:") {
        VStack(alignment: .leading) {
          Toggle("Download tags", isOn: $fetchTags)
          Toggle("Prune branches", isOn: $pruneBranches)
        }.fixedSize()
      }
      LabeledContent("Commit view:") {
        VStack(alignment: .leading) {
          Toggle("Show page guide", isOn: $showGuide)
          HStack {
            Text("Page guide at column")
            TextField("", value: $guideWidth, formatter: NumberFormatter())
              .labelsHidden()
              .frame(width: 40)
            Stepper(value: $guideWidth, in: 0...9999, label: {}).labelsHidden()
          }.disabled(!showGuide)
        }
      }
    }.frame(minWidth: 350)
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
    self._guideWidth = .init(wrappedValue: defaults.guideWidth,
                             PreferenceKeys.guideWidth.key,
                             store: defaults)
    self._showGuide = .init(wrappedValue: defaults.showGuide,
                            PreferenceKeys.showGuide.key,
                            store: defaults)
  }
}

struct GeneralPrefsPane_Previews: PreviewProvider
{
  static var config = DictionaryConfig()

  static var previews: some View
  {
    GeneralPrefsPane(defaults: .testing, config: config).padding()
  }
}
