//
//  DPAGDeleteProfileViewController.swift
// ginlo
//
//  Created by RBU on 28/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGDeleteProfileViewController: DPAGViewControllerWithKeyboard {
    @IBOutlet private var scrollView: UIScrollView!

    @IBOutlet private var viewAlert: UIView! {
        didSet {
            self.viewAlert.backgroundColor = DPAGColorProvider.shared[.alertDestructiveBackground]
        }
    }

    @IBOutlet private var labelAlert: UILabel! {
        didSet {
            self.labelAlert.textColor = DPAGColorProvider.shared[.alertDestructiveTint]
            self.labelAlert.text = DPAGLocalizedString("settings.deleteAccount.introductionLabel")
            self.labelAlert.font = UIFont.kFontSubheadline
            self.labelAlert.numberOfLines = 0
        }
    }

    @IBOutlet private var labelConfirm: UILabel! {
        didSet {
            self.labelConfirm.text = DPAGLocalizedString("settings.profile.delete.confirm")
            self.labelConfirm.font = UIFont.kFontTitle1
            self.labelConfirm.textColor = DPAGColorProvider.shared[.labelText]
            self.labelConfirm.numberOfLines = 0
        }
    }

    @IBOutlet private var stackViewAccountIDConfirm: UIStackView!
    @IBOutlet private var labelAccountIDConfirmLabel: UILabel! {
        didSet {
            self.labelAccountIDConfirmLabel.text = DPAGLocalizedString("contacts.details.labelAccountIDConfirmSimple")
            self.labelAccountIDConfirmLabel.configureLabelForTextField()
        }
    }

    @IBOutlet private var textFieldAccountIDConfirm: UITextField! {
        didSet {
            self.textFieldAccountIDConfirm.configureDefault()
            self.textFieldAccountIDConfirm.accessibilityIdentifier = "textFieldAccountIDConfirm"
            self.textFieldAccountIDConfirm.autocapitalizationType = .allCharacters
            self.textFieldAccountIDConfirm.autocorrectionType = .no
            self.textFieldAccountIDConfirm.font = UIFont.kFontInputAccountID
        }
    }

    @IBOutlet private var imageViewAccountIDConfirm: UIImageView! {
        didSet {
            self.imageViewAccountIDConfirm.image = DPAGImageProvider.shared[.kImageChatMessageFingerprint]
            self.imageViewAccountIDConfirm.tintColor = DPAGColorProvider.shared[.accountID]
        }
    }

    @IBOutlet private var viewButtonNext: DPAGButtonPrimaryView! {
        didSet {
            self.viewButtonNext.button.accessibilityIdentifier = "btnDeleteAccount"
            self.viewButtonNext.button.setTitle(DPAGLocalizedString("settings.profile.button.deleteAccount"), for: .normal)
            self.viewButtonNext.button.addTarget(self, action: #selector(handleDeleteAccount(_:)), for: .touchUpInside)
        }
    }

    @IBOutlet private var constraintBtnDeleteAccountBottom: NSLayoutConstraint!

    private let showAccountID: Bool

    init(showAccountID: Bool) {
        self.showAccountID = showAccountID
        super.init(nibName: "DPAGDeleteProfileViewController", bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = DPAGLocalizedString("settings.profile.button.deleteAccount")
        configureShowAccountID()
    }

    private func configureShowAccountID() {
        if let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid) {
            if self.showAccountID {
                self.textFieldAccountIDConfirm.attributedPlaceholder = NSAttributedString(string: "S1M5M3ID", attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
                if AppConfig.buildConfigurationMode == .DEBUG {
                    self.textFieldAccountIDConfirm.text = contact.accountID
                }
            } else {
                self.textFieldAccountIDConfirm.text = contact.accountID
                self.textFieldAccountIDConfirm.attributedPlaceholder = NSAttributedString(string: contact.accountID ?? "", attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
            }
        } else {
            self.viewButtonNext.isEnabled = false
        }
    }
    
    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.viewAlert.backgroundColor = DPAGColorProvider.shared[.alertDestructiveBackground]
                self.labelAlert.textColor = DPAGColorProvider.shared[.alertDestructiveTint]
                self.imageViewAccountIDConfirm.tintColor = DPAGColorProvider.shared[.accountID]
                self.labelConfirm.textColor = DPAGColorProvider.shared[.labelText]
                configureShowAccountID()
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    @IBAction private func handleDeleteAccount(_: Any?) {
        self.textFieldAccountIDConfirm.resignFirstResponder()

        guard let accountID = self.textFieldAccountIDConfirm.text, let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid), accountID == contact.accountID else {
            self.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: "settings.profile.delete.accountIDDoesNotMatch"))
            return
        }

        // TODO: Here it is not obvious who will hide the progress HUD
        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { [weak self] _ in

            DPAGApplicationFacade.accountManager.deleteAccount(force: false, withResponse: { responseObject, _, errorMessage in

                if let errorMessage = errorMessage {
                    DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                        self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
                    }
                } else {
                    if responseObject != nil, let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid), let accountID = contact.accountID {
                        do {
                            try DPAGApplicationFacade.backupWorker.deleteBackups(accountID: accountID)
                        } catch {
                            DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in

                                self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: error.localizedDescription))
                            }
                            return
                        }
                    }
                    DPAGProgressHUD.sharedInstance.hide(true)
                }
            })
        }
    }

    override func handleViewTapped(_ sender: Any?) {
        super.handleViewTapped(sender)

        self.textFieldAccountIDConfirm.resignFirstResponder()
    }

    override func handleKeyboardWillShow(_ aNotification: Notification) {
        if self.textFieldAccountIDConfirm != nil {
            super.handleKeyboardWillShow(aNotification, scrollView: self.scrollView, viewVisible: self.textFieldAccountIDConfirm, viewButtonPrimary: self.viewButtonNext)
        }
    }

    override func handleKeyboardWillHide(_ aNotification: Notification) {
        super.handleKeyboardWillHide(aNotification, scrollView: self.scrollView, viewButtonPrimary: self.viewButtonNext)
    }
}
