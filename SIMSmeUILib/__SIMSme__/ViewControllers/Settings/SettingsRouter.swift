//
//  SettingsRouter.swift
//  SIMSmeUISettingsLib
//

public protocol SettingsRouterProtocol {
    func showProfileSettings()
    func showPasswordSettings()
    func showPrivacySettings()
    func showHelp()
    func showChatsSettings()
    func showAutoDownloadSettings()
    func showNotificationSettings()
}

class SettingsRouter: SettingsRouterProtocol {
    weak var navigationController: UINavigationController?

    func showProfileSettings() {
        showNextViewController(DPAGApplicationFacadeUISettings.profileVC())
    }

    func showPasswordSettings() {
        showNextViewController(DPAGApplicationFacadeUISettings.settingsPasswordTableVC())
    }

    func showPrivacySettings() {
        showNextViewController(DPAGApplicationFacadeUISettings.settingsPrivacyTableVC())
    }

    func showHelp() {
        showNextViewController(DPAGApplicationFacadeUISettings.infoOverviewVC())
    }

    func showChatsSettings() {
        showNextViewController(DPAGApplicationFacadeUISettings.settingsChatTableVC())
    }

    func showAutoDownloadSettings() {
        showNextViewController(DPAGApplicationFacadeUISettings.settingsAutoDownloadTableVC())
    }

    func showNotificationSettings() {
        showNextViewController(DPAGApplicationFacadeUISettings.settingsNotificationsTableVC())
    }

    private func showNextViewController(_ viewController: UIViewController) {
        DPAGApplicationFacadeUIBase.containerVC.pushSecondaryViewController(viewController, animated: true)
    }
}
