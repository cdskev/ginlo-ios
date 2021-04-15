//
//  DPAGApplicationFacadeUI.swift
//  SIMSmeUILib
//
//  Created by RBU on 26.05.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

public struct DPAGApplicationFacadeUISettings {
    private init() {}

    static func aboutSimsMeVC() -> (UIViewController) { DPAGAboutSimsMeViewController() }
    static func infoOverviewVC() -> (UIViewController) { DPAGInfoOverviewViewController() }
    static func licenceVC() -> (UIViewController) { DPAGLicenceViewController() }
    public static func supportVC() -> (UIViewController) { DPAGSupportViewController() }
    public static func devicesVC() -> (UIViewController) { DPAGDevicesTableViewController() }
    static func deviceVC(device: DPAGDevice) -> (UIViewController) { DPAGDeviceViewController(device: device) }
    static func addDeviceVC() -> (UIViewController) { DPAGAddDeviceViewController() }
    static func backupCloudInfoVC() -> (UIViewController) { DPAGBackupCloudInfoViewController() }
    static func backupIntervalVC() -> (UIViewController) { DPAGBackupIntervalViewController(style: .grouped) }
    static func backupPasswordRepeatVC(password: String) -> (UIViewController) { DPAGBackupPasswordRepeatViewController(password: password) }
    static func backupPasswordVC() -> (UIViewController) { DPAGBackupPasswordViewController() }
    public static func backupVC() -> (UIViewController) { DPAGBackupViewController(style: .grouped) }
    static func adjustChatBackgroundVC(image: UIImage, imageLandscape: UIImage?, delegate: DPAGAdjustChatBackgroundDelegate?) -> (UIViewController) { DPAGAdjustChatBackgroundViewController(image: image, imageLandscape: imageLandscape, delegate: delegate) }
    static func blockedContactsVC(blockedContacts: [DPAGContact]) -> (UIViewController) { DPAGBlockedContactsViewController(blockedContacts: blockedContacts) }
    static func simsMeBackgroundsVC() -> (UIViewController) { DPAGSimsMeBackgroundsViewController() }
    static func settingsPasswordTableVC() -> (UIViewController) { DPAGSettingsPasswordTableViewController(style: .grouped) }
    static func settingsPrivacyTableVC() -> (UIViewController) { DPAGSettingsPrivacyTableViewController(style: .grouped) }
    static func settingsChatTableVC() -> (UIViewController) { DPAGSettingsChatTableViewController(style: .grouped) }
    static func settingsAutoDownloadTableVC() -> (UIViewController) { DPAGSettingsAutoDownloadTableViewController(style: .grouped) }
    static func settingsNotificationsTableVC() -> (UIViewController) { DPAGSettingsNotificationsTableViewController(style: .grouped) }
    static func changePasswordRepeatVC(password: String, passwordType: DPAGPasswordType) -> (UIViewController) { DPAGChangePasswordRepeatViewController(password: password, passwordType: passwordType) }
    public static func companyProfilConfirmEMailVC() -> (UIViewController) { DPAGCompanyProfilConfirmEMailController() }
    public static func companyProfilConfirmPhoneNumberVC() -> (UIViewController) { DPAGCompanyProfilConfirmPhoneNumberController() }
    public static func companyProfilInitEMailVC() -> (UIViewController) { DPAGCompanyProfilInitEMailController() }
    public static func companyProfilInitPhoneNumberVC() -> (UIViewController) { DPAGCompanyProfilInitPhoneNumberController() }
    public static func deleteProfileVC(showAccountID: Bool) -> (UIViewController) { DPAGDeleteProfileViewController(showAccountID: showAccountID) }
    public static func profileVC() -> (UIViewController & DPAGProfileViewControllerProtocol) { DPAGProfileViewController() }
    public static func outOfOfficeStatusVC() -> (UIViewController & DPAGOutOfOfficeStatusViewControllerProtocol) { DPAGOutOfOfficeStatusViewController() }
    static func statusMessageVC() -> (UIViewController & DPAGStatusPickerTableViewControllerProtocol) { DPAGStatusPickerTableViewController() }
    static func cellDeviceNib() -> UINib { UINib(nibName: "DPAGDeviceTableViewCell", bundle: Bundle(for: DPAGDeviceTableViewCell.self)) }
    static func cellBackgroundsNib() -> UINib { UINib(nibName: "DPAGBackgroundsCollectionViewCell", bundle: Bundle(for: DPAGBackgroundsCollectionViewCell.self)) }
    static func cellBackupCreateNib() -> UINib { UINib(nibName: "DPAGBackupCreateTableViewCell", bundle: Bundle(for: DPAGBackupCreateTableViewCell.self)) }
    static func soundSelectionVC(soundType: DPAGNotificationChatType) -> (UIViewController) { DPAGSettingsNotificationsSoundSelectionTableViewController(soundType: soundType) }

    public static func settingsVC(appRouter: ApplicationRouterProtocol) -> (UIViewController) {
        let viewController = DPAGSettingsTableViewController()
        let settingsRouter = SettingsRouter()
        viewController.presenter = SettingsPresenter(appRouter: appRouter, settingsRouter: settingsRouter)
        return viewController
    }

    public static func changePasswordVC() -> (UIViewController) { DPAGChangePasswordViewController() }
    public static func setPasswordVC() -> (UIViewController) {
        let rc = DPAGChangePasswordViewController()
        rc.forceBackToRoot = false
        return rc
    }
}
