//
//  GNRegisterUsingInvitationViewController.swift
//  SIMSmeUILib
//
//  Created by Imdat Solak on 08.09.21.
//  Copyright © 2021 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class GNRegisterUsingInvitationViewController: DPAGViewControllerWithKeyboard {
    @IBOutlet private var labelHeadline: UILabel! {
        didSet {
            self.labelHeadline.text = DPAGLocalizedString("registration.headline.creatingInvitationAccount")
            self.labelHeadline.font = UIFont.kFontTitle1
            self.labelHeadline.textColor = DPAGColorProvider.shared[.labelText]
            self.labelHeadline.numberOfLines = 0
        }
    }

    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.labelHeadline.textColor = DPAGColorProvider.shared[.labelText]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    private var accountGuid: String?
    private var password: String?
    private var enabledPassword = false
    private var endpoint: String?
    private var inivitationData: [String: Any]

    init(password: String, enabled: Bool, endpoint: String?, invitationData: [String: Any]) {
        self.password = password
        self.enabledPassword = enabled
        self.endpoint = endpoint
        self.inivitationData = invitationData
        super.init(nibName: "GNRegisterUsingInvitationViewController", bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = DPAGLocalizedString("registration.title.createInvitationAccount")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DPAGApplicationFacade.accountManager.resetDatabase()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        createAccount()
    }

    private func createAccount() {
        guard self.password != nil else { return }
        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true, completion: { [weak self] _ in
            guard let strongSelf = self, let password = strongSelf.password else { return }
            do {
                _ = try DPAGApplicationFacade.backupWorker.isICloudEnabled()
            } catch {
                DPAGLog(error)
            }
            strongSelf.accountGuid = DPAGApplicationFacade.accountManager.createAccount(password: password, phoneNumber: nil, emailAddress: nil, emailDomain: nil, endpoint: strongSelf.endpoint) { [weak self] responseObject, _, errorMessage in
                if let errorMessage = errorMessage {
                    self?.handleServiceError(errorMessage)
                } else if let responseArr = responseObject as? [Any] {
                    self?.handleServiceSuccess(responseArr)
                } else {
                    self?.handleServiceError("service.ERR-0001")
                }
            }
        })
    }

    private func handleServiceSuccess(_ responseArr: [Any]) {
        DPAGApplicationFacade.preferences.isInAppNotificationEnabled = false
        if responseArr.count > 1 {
            DPAGApplicationFacade.preferences.setBootstrappingCheckbackup(true)
            DPAGApplicationFacade.preferences.bootstrappingOverrideAccount = true
            var skipOverwriteWarning = true
            var availableAccountID: [String] = []
            responseArr.forEach { accountObj in
                if let account = accountObj as? [String: Any], let accountDict = account["Account"] as? [String: String] {
                    let guid = accountDict["guid"]
                    let mandant = accountDict["mandant"]
                    let accountID = accountDict["accountID"]
                    if guid != self.accountGuid, let accountID = accountID {
                        availableAccountID.append(accountID)
                        if mandant == DPAGApplicationFacade.preferences.mandantIdent {
                            skipOverwriteWarning = false
                            DPAGApplicationFacade.preferences.bootstrappingOldAccountID = accountID
                        }
                    }
                }
            }
            DPAGApplicationFacade.preferences.bootstrappingAvailableAccountID = availableAccountID
            DPAGApplicationFacade.preferences.bootstrappingSkipWarningOverrideAccount = skipOverwriteWarning
        }
        if let dictionary = responseArr[0] as? [AnyHashable: Any], let dictAccount = dictionary[DPAGStrings.JSON.Account.OBJECT_KEY] as? [AnyHashable: Any], let accountID = dictAccount[DPAGStrings.JSON.Account.ACCOUNT_ID] as? String {
            DPAGApplicationFacade.accountManager.autoConfirmAccount(accountID: accountID)
            DPAGApplicationFacade.model.update(with: nil)
            DPAGApplicationFacade.profileWorker.setBrabblerSwitchState()
            DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                if let strongSelf = self {
                    if strongSelf.enabledPassword == false {
                        DPAGApplicationFacade.preferences.passwordOnStartEnabled = false
                    }
                    guard let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid), let accountID = contact.accountID else { return }
                    let vc = DPAGApplicationFacadeUIRegistration.welcomeVC(account: account.guid, accountID: accountID, phoneNumber: contact.phoneNumber, emailAddress: contact.eMailAddress, emailDomain: contact.eMailDomain, checkUsage: false)
                    strongSelf.navigationController?.pushViewController(vc, animated: true)
                }
            }
        }
    }

    private func handleServiceError(_ message: String) {
        DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
            if let strongSelf = self {
                strongSelf.handleAccountCreationFailedWithMessage(message)
            }
        }
    }

    private func handleAccountCreationFailedWithMessage(_ message: String) {
        DPAGApplicationFacade.accountManager.resetDatabase()
        self.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: message))
    }
}
