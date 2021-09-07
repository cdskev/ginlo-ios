//
//  DPAGApplicationFacadeUI.swift
//  SIMSmeUILib
//
//  Created by RBU on 26.05.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

public struct DPAGApplicationFacadeUIRegistration {
    private init() {}

    static func backupNotFoundVC(oldAccountID: String?) -> (UIViewController) { DPAGBackupNotFoundViewController(oldAccountID: oldAccountID) }
    static func backupRecoverVC(oldAccountID: String?, backupEntries: [DPAGBackupFileInfo]) -> (UIViewController) { DPAGBackupRecoverViewController(oldAccountID: oldAccountID, backupEntries: backupEntries) }
    static func backupRecoverPasswordVC(backup: DPAGBackupFileInfo, delegatePassword: DPAGBackupRecoverPasswordViewControllerDelegate?) -> (UIViewController) { DPAGBackupRecoverPasswordViewController(backup: backup, delegatePassword: delegatePassword) }
    static func confirmAccountOverridePKVC(backupEntry: DPAGBackupFileInfo, delegate: DPAGBackupRecoverViewControllerPKDelegate?) -> (UIViewController) { DPAGConfirmAccountOverridePKViewController(backupEntry: backupEntry, delegate: delegate) }
    static func confirmAccountOverrideVC(oldAccountID: String?) -> (UIViewController) { DPAGConfirmAccountOverrideViewController(oldAccountID: oldAccountID) }
    public static func confirmAccountVC(confirmationCode code: String? = nil) -> (UIViewController) { DPAGConfirmAccountViewController(confirmationCode: code) }
    static func createDeviceConfirmCodeVC(accountGuid: String) -> (UIViewController) { DPAGCreateDeviceConfirmCodeViewController(accountGuid: accountGuid) }
    static func createDeviceRequestCodeVC(password: String, enabled: Bool) -> (UIViewController) { DPAGCreateDeviceRequestCodeViewController(password: password, enabled: enabled) }
    static func createDeviceWaitForConfirmationVC() -> (UIViewController) { DPAGCreateDeviceWaitForConfirmationViewController() }
    static func createDeviceWelcomeVC() -> (UIViewController) { DPAGCreateDeviceWelcomeViewController() }
    static func initialPasswordRepeatVC(password: String, initialPasswordJob: GNInitialPasswordJobType) -> (UIViewController) { DPAGInitialPasswordRepeatViewController(password: password, initialPasswordJob: initialPasswordJob) }
    public static func initialPasswordVC(initialPasswordJob: GNInitialPasswordJobType) -> (UIViewController) { DPAGInitialPasswordViewController(initialPasswordJob: initialPasswordJob) }
    static func introPage0VC(delegatePages: DPAGPageViewControllerProtocol?) -> (UIViewController) { DPAGIntroPage0ViewController(delegatePages: delegatePages) }
    static func introPage1VC(delegatePages: DPAGPageViewControllerProtocol?) -> (UIViewController) { DPAGIntroPage1ViewController(delegatePages: delegatePages) }
    public static func introVC() -> (UIViewController) { DPAGIntroViewController() }
    public static func licencesInitVC() -> (UIViewController) { DPAGLicencesInitViewController() }
    static func licencesInputVC() -> (UIViewController) { DPAGLicencesInputViewController() }
    
    static func requestAccountVC(password: String, enabled: Bool, endpoint: String? = nil) -> (UIViewController) { DPAGRequestAccountViewController(password: password, enabled: enabled, endpoint: endpoint) }
    public static func requestAutomaticRegistrationVC(registrationValues: DPAGAutomaticRegistrationPreferences) -> (UIViewController) { DPAGAutomaticRegistrationViewController(registrationValues: registrationValues) }
    static func requestAutomaticTestRegistrationVC() -> (UIViewController) { DPAGAutomaticTestRegistrationViewController() }
    static func scanCreateDeviceTANVC(blockSuccess successBlock: @escaping (String) -> Void, blockFailed failedBlock: @escaping DPAGCompletion, blockCancelled cancelBlock: @escaping DPAGCompletion) -> (UIViewController) { DPAGScanCreateDeviceTANViewController(blockSuccess: successBlock, blockFailed: failedBlock, blockCancelled: cancelBlock) }
    static func scanInvitationVC(blockSuccess successBlock: @escaping (String) -> Void, blockFailed failedBlock: @escaping DPAGCompletion, blockCancelled cancelBlock: @escaping DPAGCompletion) -> (UIViewController) { GNScanInvitationViewController(blockSuccess: successBlock, blockFailed: failedBlock, blockCancelled: cancelBlock) }
    static func showIdentityVC(accountID: String) -> (UIViewController) { DPAGShowIdentityViewController(accountID: accountID) }
    public static func testLicense() -> (UIViewController) { DPAGTestLicenseViewController() }
    public static func welcomeVC(account accountGuid: String, accountID: String, phoneNumber: String?, emailAddress: String?, emailDomain: String?, checkUsage: Bool) -> (UIViewController & DPAGWelcomeViewControllerProtocol) { DPAGWelcomeViewController(account: accountGuid, accountID: accountID, phoneNumber: phoneNumber, emailAddress: emailAddress, emailDomain: emailDomain, checkUsage: checkUsage) }
    static func companyEnterRecoveryKeyVC() -> (UIViewController) { DPAGCompanyEnterRecoveryKeyViewController() }
    public static func companyPasswordForgotVC() -> (UIViewController) { DPAGCompanyPasswordForgotViewController() }
    static func viewBackupRecoverEntry() -> (UIView & DPAGBackupRecoverEntryViewProtocol)? { UINib(nibName: "DPAGBackupRecoverEntryView", bundle: Bundle(for: DPAGBackupRecoverEntryView.self)).instantiate(withOwner: nil, options: nil).first as? DPAGBackupRecoverEntryView }
    static func viewLicenceItem() -> (UIView & DPAGLicenceItemViewProtocol)? { UINib(nibName: "DPAGLicenceItemView", bundle: Bundle(for: DPAGLicenceItemView.self)).instantiate(withOwner: nil, options: nil).first as? DPAGLicenceItemView }
    static func viewDPAGAutomaticRegistrationStep() -> (UIView & DPAGAutomaticRegistrationStepViewProtocol)? { UINib(nibName: "DPAGAutomaticRegistrationStepView", bundle: Bundle(for: DPAGAutomaticRegistrationStepView.self)).instantiate(withOwner: nil, options: nil).first as? (UIView & DPAGAutomaticRegistrationStepViewProtocol) }

    static func beforeCreateDeviceVC(password: String, enabled: Bool) -> (UIViewController) {
        if AppConfig.buildConfigurationMode == .DEBUG || AppConfig.buildConfigurationMode == .BETA {
            return PageEndpointViewController(password: password, enabled: enabled)
        }
        return DPAGCreateDeviceRequestCodeViewController(password: password, enabled: enabled)
    }

    static func beforeRegistrationVC(password: String, enabled: Bool) -> (UIViewController) {
        if AppConfig.buildConfigurationMode == .DEBUG || AppConfig.buildConfigurationMode == .BETA {
            return PageEndpointViewController(password: password, enabled: enabled, accountCreation: true)
        }
        return DPAGRequestAccountViewController(password: password, enabled: enabled, endpoint: nil)
    }
}
