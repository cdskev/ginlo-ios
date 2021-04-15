//
//  DPAGConfirmAccountViewController.swift
//  SIMSme
//
//  Created by RBU on 11/04/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGConfirmAccountViewController: DPAGViewControllerWithKeyboard, DPAGConfirmAccountViewControllerProtocol {
    private static let kConfirmTimeout = AppConfig.buildConfigurationMode == .DEBUG ? TimeInterval(10) : TimeInterval(300)

    @IBOutlet private var scrollView: UIScrollView!
    @IBOutlet private var viewDigits: UIView!
    @IBOutlet private var viewAlphaNum: UIView!
    @IBOutlet private var textField0: DPAGTextField! {
        didSet {
            self.textField0.accessibilityIdentifier = "textField0"
            self.configureInput(self.textField0)
        }
    }

    @IBOutlet private var textField1: DPAGTextField! {
        didSet {
            self.textField1.accessibilityIdentifier = "textField1"
            self.configureInput(self.textField1)
        }
    }

    @IBOutlet private var textFieldConfirmCode: DPAGTextField! {
        didSet {
            self.textFieldConfirmCode.configureDefault()
            self.textFieldConfirmCode.accessibilityIdentifier = "textFieldConfirmCode"
            self.textFieldConfirmCode.delegate = self
            self.textFieldConfirmCode.textAlignment = .center
            self.textFieldConfirmCode.setPaddingLeftTo(0)
            self.textFieldConfirmCode.font = UIFont.kFontCodeInput
            self.textFieldConfirmCode.enablesReturnKeyAutomatically = true
            self.textFieldConfirmCode.returnKeyType = .continue
        }
    }

    @IBOutlet private var viewButtonNext: DPAGButtonPrimaryView! {
        didSet {
            self.viewButtonNext.button.accessibilityIdentifier = "btnNext"
            self.viewButtonNext.button.setTitle(DPAGLocalizedString("res.continue"), for: .normal)
            self.viewButtonNext.button.addTarget(self, action: #selector(handleContinueTapped), for: .touchUpInside)
        }
    }

    @IBOutlet private var labelConfirmationText: UILabel! {
        didSet {
            self.labelConfirmationText.font = UIFont.kFontSubheadline
            self.labelConfirmationText.textColor = DPAGColorProvider.shared[.labelText]
            self.labelConfirmationText.numberOfLines = 0
        }
    }

    @IBOutlet private var labelHeadline: UILabel! {
        didSet {
            self.labelHeadline.font = UIFont.kFontTitle1
            self.labelHeadline.textColor = DPAGColorProvider.shared[.labelText]
            self.labelHeadline.numberOfLines = 0
        }
    }

    @IBOutlet private var labelConfirmationInput: UILabel! {
        didSet {
            self.labelConfirmationInput.font = UIFont.kFontCallout
            self.labelConfirmationInput.textColor = DPAGColorProvider.shared[.labelText]
            self.labelConfirmationInput.text = DPAGLocalizedString("registration.label.confirmationTextView")
        }
    }

    @IBOutlet private var labelTimer: UILabel! {
        didSet {
            self.labelTimer.font = UIFont.kFontHeadline
            self.labelTimer.textColor = DPAGColorProvider.shared[.labelText]
        }
    }

    open override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.labelConfirmationText.textColor = DPAGColorProvider.shared[.labelText]
                self.labelHeadline.textColor = DPAGColorProvider.shared[.labelText]
                self.labelConfirmationInput.textColor = DPAGColorProvider.shared[.labelText]
                self.configureInput(self.textField0)
                self.configureInput(self.textField1)
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    private var telephoneNumber: String = "-"
    private var timerRegistrationStarted: Timer?

    private var confirmationCode: String?

    init(confirmationCode code: String?) {
        self.confirmationCode = code

        super.init(nibName: "DPAGConfirmAccountViewController", bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureInput(_ textField: DPAGTextField) {
        textField.configureDefault()
        textField.font = UIFont.kFontCodeInput
        textField.setPaddingLeftTo(3)
        textField.setPaddingRightTo(3)
        textField.delegate = self
        textField.keyboardType = .numberPad
        textField.attributedPlaceholder = NSAttributedString(string: "000", attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
        textField.textAlignment = .center
        textField.enablesReturnKeyAutomatically = true
        textField.returnKeyType = .continue
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = DPAGLocalizedString("registration.title.createAccount")

        self.configureGui()

        let dateRegistrationStarted = DPAGApplicationFacade.preferences.accountRegisteredAt

        let timeRegistrationStarted = Date().timeIntervalSince(dateRegistrationStarted)

        if dateRegistrationStarted.isInFuture || (timeRegistrationStarted > DPAGConfirmAccountViewController.kConfirmTimeout && (self.navigationController?.viewControllers.count ?? 0) > 1) {
            DPAGApplicationFacade.preferences.accountRegisteredAt = Date()
        }
        self.labelTimer.isHidden = true
        self.viewButtonNext.isEnabled = false
    }

    private weak var sharedInstanceProgress: DPAGProgressHUDWithProgressProtocol?

    override var preferredStatusBarStyle: UIStatusBarStyle {
        self.sharedInstanceProgress?.statusBarStyle ?? super.preferredStatusBarStyle
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.navigationController?.isNavigationBarHidden = false

        self.setLeftBackBarButtonItem(action: #selector(checkRegistrationTimer))
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if let confirmationCode = self.confirmationCode, confirmationCode.isEmpty == false {
            self.proceed(code: confirmationCode)
            self.confirmationCode = nil
        } else if self.viewAlphaNum.isHidden {
            let empty0 = (self.textField0.text?.isEmpty ?? true)
            let empty1 = (self.textField1.text?.isEmpty ?? true)

            if empty0 {
                self.textField0.becomeFirstResponder()
            } else if empty1 {
                self.textField1.becomeFirstResponder()
            }
        } else if self.textFieldConfirmCode.text?.isEmpty ?? true {
            self.textFieldConfirmCode.becomeFirstResponder()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        self.timerRegistrationStarted?.invalidate()
    }

    @objc
    private func checkRegistrationTimer() {
        let dateRegistrationStarted = DPAGApplicationFacade.preferences.accountRegisteredAt

        let timeRegistrationStarted = Date().timeIntervalSince(dateRegistrationStarted)

        if timeRegistrationStarted >= DPAGConfirmAccountViewController.kConfirmTimeout {
            if let controllers = self.navigationController?.viewControllers {
                if controllers.count < 2 {
                    self.popToPasswortInitialisation()
                } else {
                    self.dismissViewController()
                }
            } else {
                self.popToPasswortInitialisation()
            }
        } else {
            self.updateRegistrationTimer()
        }
    }

    private func dismissViewController() {
        _ = self.navigationController?.popViewController(animated: true)
    }

    private func popToPasswortInitialisation() {
        DPAGApplicationFacade.accountManager.resetDatabase()

        let initialPasswordViewController = DPAGApplicationFacadeUIRegistration.initialPasswordVC(createDevice: false)

        self.navigationController?.setViewControllers([DPAGApplicationFacadeUIRegistration.introVC(), initialPasswordViewController], animated: true)
    }

    @objc
    private func updateRegistrationTimer() {
        let dateRegistrationStarted = DPAGApplicationFacade.preferences.accountRegisteredAt

        var timeRegistrationStarted = Date().timeIntervalSince(dateRegistrationStarted)

        self.labelTimer.isHidden = false

        if timeRegistrationStarted >= DPAGConfirmAccountViewController.kConfirmTimeout {
            self.timerRegistrationStarted?.invalidate()
            self.navigationItem.leftBarButtonItem?.isEnabled = true

            self.labelTimer.text = " " // <- dieser Label darf leider nicht leer sein damit XCUITest diesen noch verwenden kann.
        } else {
            let localizedString = DPAGLocalizedString("registration.registerAccount.timer")

            timeRegistrationStarted = DPAGConfirmAccountViewController.kConfirmTimeout - timeRegistrationStarted

            self.navigationItem.leftBarButtonItem?.isEnabled = false

            self.timerRegistrationStarted = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(updateRegistrationTimer), userInfo: nil, repeats: false)

            self.labelTimer.text = String(format: "%@ %.2i:%.2i", localizedString, Int(timeRegistrationStarted) / 60, Int(timeRegistrationStarted) % 60)
            self.labelTimer.accessibilityIdentifier = "registration.registerAccount.timer"
        }
    }

    private func proceed(code: String) {
        if self.viewAlphaNum.isHidden {
            self.textField0.text = code.count > 3 ? String(code[..<code.index(code.startIndex, offsetBy: 3)]) : code
            self.textField1.text = code.count > 3 ? String(code[code.index(code.startIndex, offsetBy: 3)...]) : ""
        } else {
            self.textFieldConfirmCode.text = code
        }

        if DPAGApplicationFacade.preferences.bootstrappingOverrideAccount {
            DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in

                DPAGApplicationFacade.accountManager.isConfirmationValid(code: code, responseBlock: { _, _, errorMessage in

                    if let errorMessage = errorMessage {
                        if errorMessage == DPAGLocalizedString("service.error499") {
                            self.handleServiceError("service.error499.createAccount")
                        } else {
                            self.handleServiceError(errorMessage)
                        }
                    } else {
                        DPAGApplicationFacade.preferences.bootstrappingConfirmationCode = code
                        self.handleServiceSuccessSearchBackup()
                    }
                })
            }
        } else {
            DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in

                DPAGApplicationFacade.accountManager.confirmAccount(code: code, responseBlock: { _, _, errorMessage in

                    if let errorMessage = errorMessage {
                        if errorMessage == DPAGLocalizedString("service.error499") {
                            self.handleServiceError("service.error499.createAccount")
                        } else {
                            self.handleServiceError(errorMessage)
                        }
                    } else {
                        self.handleServiceSuccessNoBackup()
                    }
                })
            }
        }
    }

    private func configureGui() {
        // reinit phoneNumber if this is first VC after start
        let contact = DPAGApplicationFacade.cache.contact(for: DPAGApplicationFacade.cache.account?.guid ?? "???")

        if let eMailAddress = contact?.eMailAddress {
            self.viewDigits.isHidden = true

            self.labelHeadline.text = DPAGLocalizedString("registration.label.labelHeadline.emailAddress")
            self.textField0.accessibilityLabel = DPAGLocalizedString("registration.label.labelHeadline.emailAddress")
            self.textField1.accessibilityLabel = DPAGLocalizedString("registration.label.labelHeadline.emailAddress")
            self.labelConfirmationText.text = String(format: DPAGLocalizedString("registration.textView.confirmationTextView.emailAddress"), eMailAddress)

            self.textFieldConfirmCode.text = self.confirmationCode
        } else {
            self.viewAlphaNum.isHidden = true

            self.telephoneNumber = contact?.phoneNumber ?? "-"
            self.labelHeadline.text = DPAGLocalizedString("registration.label.labelHeadline")
            self.textField0.accessibilityLabel = DPAGLocalizedString("registration.label.labelHeadline")
            self.textField1.accessibilityLabel = DPAGLocalizedString("registration.label.labelHeadline")
            self.labelConfirmationText.text = String(format: DPAGLocalizedString("registration.textView.confirmationTextView"), self.telephoneNumber)

            if let confirmationCode = self.confirmationCode {
                self.textField0.text = confirmationCode.count > 3 ? String(confirmationCode[...confirmationCode.index(confirmationCode.startIndex, offsetBy: 3)]) : confirmationCode
                self.textField1.text = confirmationCode.count > 3 ? String(confirmationCode[confirmationCode.index(confirmationCode.startIndex, offsetBy: 3)...]) : ""
            } else {
                self.textField0.text = ""
                self.textField1.text = ""
            }

            self.textField0.configure(textFieldBefore: nil, textFieldAfter: self.textField1, textFieldMaxLength: 3, didChangeCompletion: self.updateBtnState)
            self.textField1.configure(textFieldBefore: self.textField0, textFieldAfter: nil, textFieldMaxLength: 3, didChangeCompletion: self.updateBtnState)
        }
    }

    private func updateBtnState() {
        if let text1 = self.textField0.text, let text2 = self.textField1.text, text1.isEmpty == false || text2.isEmpty == false {
            self.viewButtonNext.isEnabled = true
        } else {
            self.viewButtonNext.isEnabled = false
        }
    }

    override func handleKeyboardWillShow(_ aNotification: Notification) {
        self.setRightBarButtonItem(image: DPAGImageProvider.shared[.kImageBarButtonNavCheck], action: #selector(handleNumberInputDoneTapped(_:)), accessibilityLabelIdentifier: "navigation.done")

        super.handleKeyboardWillShow(aNotification, scrollView: self.scrollView, viewVisible: self.textField0, viewButtonPrimary: self.viewButtonNext)
    }

    override func handleKeyboardWillHide(_ aNotification: Notification) {
        self.navigationItem.setRightBarButton(nil, animated: true)

        super.handleKeyboardWillHide(aNotification, scrollView: self.scrollView, viewButtonPrimary: self.viewButtonNext)
    }

    private func dismissKeyboard() {
        self.textField0.resignFirstResponder()
        self.textField1.resignFirstResponder()
        self.textFieldConfirmCode.resignFirstResponder()
    }

    @objc
    private func handleNumberInputDoneTapped(_: Any?) {
        self.dismissKeyboard()
    }

    override func handleViewTapped(_: Any?) {
        self.dismissKeyboard()
    }

    @objc
    private func handleContinueTapped() {
        self.dismissKeyboard()

        if self.viewAlphaNum.isHidden {
            if let text1 = self.textField0.text, let text2 = self.textField1.text, text1.isEmpty == false || text2.isEmpty == false {
                self.proceed(code: text1 + text2)
            }
        } else if let text = self.textFieldConfirmCode.text, text.isEmpty == false {
            self.proceed(code: text)
        }
    }

    // MARK: - DPAGServiceDelegate

    private func handleServiceSuccessNoBackup() {
        DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
            guard let strongSelf = self, let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid), let accountID = contact.accountID else {
                return
            }
            DPAGApplicationFacade.preferences.shouldInviteFriendsAfterInstall = true
            DPAGApplicationFacade.preferences.shouldInviteFriendsAfterChatPrivateCreation = true
            DPAGApplicationFacade.preferences.didAskForCompanyEmail = contact.eMailAddress != nil
            DPAGApplicationFacade.preferences.migrationVersion = .versionCurrent
            DPAGApplicationFacade.preferences.createSimsmeRecoveryInfos()
            if DPAGApplicationFacade.preferences.isBaMandant {
                let vc = DPAGApplicationFacadeUIRegistration.welcomeVC(account: account.guid, accountID: accountID, phoneNumber: contact.phoneNumber, emailAddress: contact.eMailAddress, emailDomain: contact.eMailDomain, checkUsage: true)
                strongSelf.navigationController?.pushViewController(vc, animated: true)
            } else {
                let vc = DPAGApplicationFacadeUIRegistration.welcomeVC(account: account.guid, accountID: accountID, phoneNumber: contact.phoneNumber, emailAddress: contact.eMailAddress, emailDomain: contact.eMailDomain, checkUsage: false)
                strongSelf.navigationController?.pushViewController(vc, animated: true)
            }
        }
    }

    private var iCloudQuery: NSMetadataQuery?

    private func handleServiceSuccessSearchBackup() {
        DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
            if ((try? DPAGApplicationFacade.backupWorker.isICloudEnabled()) ?? false) == false {
                self?.didFinishGatheringMetadata()
                return
            }
            AppConfig.setIdleTimerDisabled(true)
            DPAGProgressHUDWithProgress.sharedInstanceProgress.showForBackgroundProcess(true, completion: { [weak self] _ in
                self?.performBlockOnMainThread { [weak self] in
                    self?.setNeedsStatusBarAppearanceUpdate()
                }
                guard let strongSelf = self else { return }
                strongSelf.iCloudQuery = NSMetadataQuery()
                strongSelf.iCloudQuery?.operationQueue = OperationQueue.main
                strongSelf.iCloudQuery?.searchScopes = [NSMetadataQueryUbiquitousDataScope]
                strongSelf.iCloudQuery?.sortDescriptors = [NSSortDescriptor(key: NSMetadataItemDisplayNameKey, ascending: true)]
                NotificationCenter.default.addObserver(strongSelf, selector: #selector(strongSelf.didFinishGatheringMetadata), name: NSNotification.Name.NSMetadataQueryDidFinishGathering, object: nil)
                NotificationCenter.default.addObserver(strongSelf, selector: #selector(strongSelf.didFinishGatheringMetadata), name: NSNotification.Name.NSMetadataQueryDidUpdate, object: nil)
                strongSelf.iCloudQuery?.start()
            }, delegate: self)
        }
    }

    @objc
    private func didFinishGatheringMetadata() {
        var backupItems: [DPAGBackupFileInfo] = []
        if let iCloudQuery = self.iCloudQuery {
            iCloudQuery.disableUpdates()
            if DPAGHelperEx.isNetworkReachable() {
                do {
                    backupItems = try DPAGApplicationFacade.backupWorker.listBackups(accountIDs: DPAGApplicationFacade.preferences.bootstrappingAvailableAccountID ?? [], orPhone: self.telephoneNumber, queryResults: iCloudQuery.results, checkContent: false)
                    var hasWork = false
                    for itemToDownload in backupItems {
                        if itemToDownload.isDownloading {
                            hasWork = true
                            continue
                        }
                        if itemToDownload.downloadingStatus == NSMetadataUbiquitousItemDownloadingStatusNotDownloaded || itemToDownload.downloadingStatus == NSMetadataUbiquitousItemDownloadingStatusDownloaded, let filePath = itemToDownload.filePath {
                            try? FileManager.default.startDownloadingUbiquitousItem(at: filePath)
                            hasWork = true
                            continue
                        }
                    }
                    if hasWork {
                        iCloudQuery.enableUpdates()
                        return
                    }
                } catch {
                    iCloudQuery.enableUpdates()
                    AppConfig.setIdleTimerDisabled(false)
                    DPAGProgressHUDWithProgress.sharedInstanceProgress.hide(true, completion: { [weak self] in
                        self?.sharedInstanceProgress = nil
                        self?.setNeedsStatusBarAppearanceUpdate()
                        self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: error.localizedDescription))
                    })
                    return
                }
            }
            do {
                backupItems = try DPAGApplicationFacade.backupWorker.listBackups(accountIDs: DPAGApplicationFacade.preferences.bootstrappingAvailableAccountID ?? [], orPhone: self.telephoneNumber, queryResults: iCloudQuery.results, checkContent: true).sorted(by: { (fi1, fi2) -> Bool in
                    if let d1 = fi1.backupDate {
                        if let d2 = fi2.backupDate {
                            return d1 > d2
                        }
                        return true
                    }
                    return false
                })
            } catch {
                iCloudQuery.enableUpdates()
                AppConfig.setIdleTimerDisabled(false)
                DPAGProgressHUDWithProgress.sharedInstanceProgress.hide(true, completion: { [weak self] in
                    self?.sharedInstanceProgress = nil
                    self?.setNeedsStatusBarAppearanceUpdate()
                    self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: error.localizedDescription))
                })
                return
            }
        }
        self.iCloudQuery?.stop()
        AppConfig.setIdleTimerDisabled(false)
        DPAGApplicationFacade.preferences.shouldInviteFriendsAfterInstall = true
        DPAGApplicationFacade.preferences.shouldInviteFriendsAfterChatPrivateCreation = true
        DPAGApplicationFacade.preferences.migrationVersion = .versionCurrent
        DPAGApplicationFacade.preferences.createSimsmeRecoveryInfos()
        let oldAccountId = DPAGApplicationFacade.preferences.bootstrappingOldAccountID
        DPAGProgressHUDWithProgress.sharedInstanceProgress.hide(true) { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.sharedInstanceProgress = nil
            strongSelf.setNeedsStatusBarAppearanceUpdate()
            if backupItems.isEmpty == false {
                let vc = DPAGApplicationFacadeUIRegistration.backupRecoverVC(oldAccountID: oldAccountId, backupEntries: backupItems)
                strongSelf.navigationController?.pushViewController(vc, animated: false)
            } else {
                let vc = DPAGApplicationFacadeUIRegistration.backupNotFoundVC(oldAccountID: oldAccountId)
                strongSelf.navigationController?.pushViewController(vc, animated: false)
            }
        }
    }

    private func handleServiceError(_ message: String) {
        DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in

            guard let strongSelf = self else {
                return
            }

            if message == "service.ERR-0062" {
                strongSelf.viewButtonNext.isEnabled = false

                strongSelf.presentErrorAlert(alertConfig: AlertConfigError(messageIdentifier: message, okActionHandler: { [weak self] _ in

                    if let strongSelf = self {
                        let controllers = strongSelf.navigationController?.viewControllers

                        if (controllers?.count ?? 0) < 2 {
                            strongSelf.popToPasswortInitialisation()
                        } else {
                            strongSelf.dismissViewController()
                        }
                    }
                }))
            } else {
                strongSelf.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: message))
            }
        }
    }
}

extension DPAGConfirmAccountViewController: DPAGProgressHUDDelegate {
    func setupHUD(_ hud: DPAGProgressHUDProtocol) {
        if let hudWithLabels = hud as? DPAGProgressHUDWithProgressProtocol {
            hudWithLabels.labelTitle.text = DPAGLocalizedString("backup.recover.connect")
            hudWithLabels.labelDescription.text = ""
            hudWithLabels.viewProgress.progress = 0
        }
    }
}

extension DPAGConfirmAccountViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_: UITextField) -> Bool {
        self.handleContinueTapped()

        return true
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if self.viewAlphaNum.isHidden {
            if textField == self.textField0 {
                if (self.textField1.text?.isEmpty ?? true) == false {
                    self.viewButtonNext.isEnabled = true
                    return true
                }
            } else {
                if (self.textField0.text?.isEmpty ?? true) == false {
                    self.viewButtonNext.isEnabled = true
                    return true
                }
            }
        }

        if let textFieldText = textField.text {
            let text: NSString = textFieldText as NSString
            let resultedString = text.replacingCharacters(in: range, with: string)

            self.viewButtonNext.isEnabled = resultedString.isEmpty == false
        } else {
            self.viewButtonNext.isEnabled = false
        }

        return true
    }
}
