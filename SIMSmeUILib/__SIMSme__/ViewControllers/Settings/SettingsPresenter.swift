//
//  SettingsPresenter.swift
//  SIMSmeUISettingsLib
//

import SIMSmeCore

protocol SettingsPresenterProtocol {
  var viewModel: SettingsViewModel { get }
  
  func viewWillAppear()
  func show(selection: SettingsSelection)
}

class SettingsPresenter: SettingsPresenterProtocol {
  let appRouter: ApplicationRouterProtocol
  let settingsRouter: SettingsRouterProtocol
  
  var viewModel = SettingsViewModel()
  
  init(appRouter: ApplicationRouterProtocol, settingsRouter: SettingsRouterProtocol) {
    self.appRouter = appRouter
    self.settingsRouter = settingsRouter
  }
  
  func viewWillAppear() {
    setupProfileInfo()
  }
  
  func show(selection: SettingsSelection) {
    switch selection {
      case .profileSettings:
        settingsRouter.showProfileSettings()
      case .passwordSettings:
        settingsRouter.showPasswordSettings()
      case .privacySettings:
        settingsRouter.showPrivacySettings()
      case .contacts:
        appRouter.showContacts()
      case .files:
        appRouter.showFiles()
      case .channels:
        appRouter.showChannels()
      case .devices:
        appRouter.showDevices()
      case .help:
        settingsRouter.showHelp()
      case .chatsSettings:
        settingsRouter.showChatsSettings()
      case .autoDownloadSettings:
        settingsRouter.showAutoDownloadSettings()
      case .notificationSettings:
        settingsRouter.showNotificationSettings()
      case .releaseNotes:
        openReleaseNotes()
    }
  }
  
  private func openReleaseNotes() {
    let currentLanguage = Bundle.main.preferredLocalizations[0]
    var versionString = ""
    if let dictionary = Bundle.main.infoDictionary, let shortVersion = dictionary["CFBundleShortVersionString"] as? String {
      versionString = shortVersion
    }
    if DPAGApplicationFacade.preferences.isBaMandant {
      let releaseNotesUrl = URL(string: "https://app-help.ginlo.net/releasenotes/ios/\(currentLanguage)/ginlo-Business-\(versionString)/")
      AppConfig.openURL(releaseNotesUrl)
    } else {
      let releaseNotesUrl = URL(string: "https://app-help.ginlo.net/releasenotes/ios/\(currentLanguage)/ginlo-\(versionString)/")
      AppConfig.openURL(releaseNotesUrl)
    }
  }
  
  private func setupProfileInfo() {
    guard let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid) else { return }
    viewModel.profileName = contact.nickName
    viewModel.profilePicture = contact.image(for: .profile)
  }
}

class SettingsViewModel {
  var profileName: String?
  var profilePicture: UIImage?
}

enum SettingsSelection {
  case profileSettings
  case passwordSettings
  case privacySettings
  case contacts
  case files
  case devices
  case channels
  case chatsSettings
  case autoDownloadSettings
  case notificationSettings
  // case backup
  case help
  case releaseNotes
}
