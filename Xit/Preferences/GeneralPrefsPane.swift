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

  @State private var guideTextValue = "0"

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
      LabeledField("User name:",
                   TextField(text: $userName, label: { EmptyView() }))
      LabeledField("User email:",
                   TextField(text: $userEmail, label: { EmptyView() }))
      LabeledField("Fetch options:", VStack(alignment: .leading) {
        Toggle("Download tags", isOn: $fetchTags)
        Toggle("Prune branches", isOn: $pruneBranches)
      }.fixedSize())
      LabeledField("Commit view:", VStack(alignment: .leading) {
        Group {
          VStack(alignment: .leading) {
            Toggle("Show page guide", isOn: $showGuide)
              .toggleStyle(.checkbox)

            HStack(spacing: 0) {
              Text("Page guide at column")
                .padding(.trailing)
              TextField("Page guide column", text: $guideTextValue)
                .onChange(of: guideTextValue) { _, value in
                  guideWidth = Int(value) ?? 0
                }
                .frame(width: 40)
              Stepper(value: $guideWidth, in: 0...9999, label: {}) { _ in
                guideTextValue = String(guideWidth)
              }
              .onAppear {
                guideTextValue = String(guideWidth)
              }
            }
            .disabled(showGuide == false)
          }
        }
      })
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
