//
//  DPAGAutomaticTestRegistrationViewController.swift
//  SIMSmeUIRegistrationLib
//
//  Created by Robert Burchert on 25.09.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGAutomaticTestRegistrationViewController: DPAGViewControllerWithKeyboard {
    private weak var textFieldEditing: UITextField?

    @IBOutlet var scrollView: UIScrollView!

    @IBOutlet var labelFirstName: UILabel! {
        didSet {
            self.labelFirstName.font = UIFont.kFontHeadline
            self.labelFirstName.textColor = DPAGColorProvider.shared[.labelText]
        }
    }

    @IBOutlet private var textFieldFirstName: UITextField! {
        didSet {
            self.textFieldFirstName.accessibilityIdentifier = "textFieldFirstName"
            self.textFieldFirstName.configureDefault()
            self.textFieldFirstName.delegate = self
        }
    }

    @IBOutlet var labelLastName: UILabel! {
        didSet {
            self.labelLastName.font = UIFont.kFontHeadline
            self.labelLastName.textColor = DPAGColorProvider.shared[.labelText]
        }
    }

    @IBOutlet private var textFieldLastName: UITextField! {
        didSet {
            self.textFieldLastName.accessibilityIdentifier = "textFieldLastName"
            self.textFieldLastName.configureDefault()
            self.textFieldLastName.delegate = self
        }
    }

    @IBOutlet var labelEmailAddressPre: UILabel! {
        didSet {
            self.labelEmailAddressPre.font = UIFont.kFontHeadline
            self.labelEmailAddressPre.textColor = DPAGColorProvider.shared[.labelText]
        }
    }

    @IBOutlet private var textFieldEmailAddressPre: UITextField! {
        didSet {
            self.textFieldEmailAddressPre.accessibilityIdentifier = "textFieldEmailAddressPre"
            self.textFieldEmailAddressPre.configureDefault()
            self.textFieldEmailAddressPre.delegate = self
        }
    }

    @IBOutlet private var labelEmailDomain: UILabel! {
        didSet {
            self.labelEmailDomain.font = UIFont.kFontHeadline
            self.labelEmailDomain.textColor = DPAGColorProvider.shared[.labelText]
        }
    }

    @IBOutlet private var textFieldEmailDomain: UITextField! {
        didSet {
            self.textFieldEmailDomain.accessibilityIdentifier = "textFieldEmailDomain"
            self.textFieldEmailDomain.configureDefault()
            self.textFieldEmailDomain.delegate = self
        }
    }

    @IBOutlet private var labelCompanyToken: UILabel! {
        didSet {
            self.labelCompanyToken.font = UIFont.kFontHeadline
            self.labelCompanyToken.textColor = DPAGColorProvider.shared[.labelText]
        }
    }

    open override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.labelFirstName.textColor = DPAGColorProvider.shared[.labelText]
                self.labelLastName.textColor = DPAGColorProvider.shared[.labelText]
                self.labelEmailAddressPre.textColor = DPAGColorProvider.shared[.labelText]
                self.labelEmailDomain.textColor = DPAGColorProvider.shared[.labelText]
                self.labelCompanyToken.textColor = DPAGColorProvider.shared[.labelText]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    @IBOutlet private var textFieldCompanyToken: UITextField! {
        didSet {
            self.textFieldCompanyToken.accessibilityIdentifier = "textFieldCompanyToken"
            self.textFieldCompanyToken.configureDefault()
            self.textFieldCompanyToken.delegate = self
        }
    }

    @IBOutlet private var viewButtonNext: DPAGButtonPrimaryView! {
        didSet {
            self.viewButtonNext.button.accessibilityIdentifier = "btnContinue"
            self.viewButtonNext.button.setTitle("Next", for: .normal)
            self.viewButtonNext.button.addTargetClosure { [weak self] _ in

                guard let domain = self?.textFieldEmailDomain.text, domain.isEmpty == false, let token = self?.textFieldCompanyToken.text, token.isEmpty == false, let firstName = self?.textFieldFirstName.text, firstName.isEmpty == false, let lastName = self?.textFieldLastName.text, lastName.isEmpty == false, let emailAddressPre = self?.textFieldEmailAddressPre.text, emailAddressPre.isEmpty == false else {
                    return
                }

                if AppConfig.buildConfigurationMode == .TEST {
                    self?.navigationController?.pushViewController(DPAGApplicationFacadeUIRegistration.requestAutomaticRegistrationVC(registrationValues: DPAGAutomaticRegistrationPreferences(firstName: firstName, lastName: lastName, eMailAddress: (emailAddressPre + "@" + domain).lowercased(), loginCode: token)), animated: true)
                }
            }
        }
    }

    init() {
        super.init(nibName: "DPAGAutomaticTestRegistrationViewController", bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func handleViewTapped(_ sender: Any?) {
        self.dismissKeyboard(sender)
    }

    override func handleKeyboardWillShow(_ notification: Notification) {
        if let textFieldEditing = self.textFieldEditing {
            super.handleKeyboardWillShow(notification, scrollView: self.scrollView, viewVisible: textFieldEditing, viewButtonPrimary: self.viewButtonNext)
        }
    }

    override func handleKeyboardWillHide(_ notification: Notification) {
        super.handleKeyboardWillHide(notification, scrollView: self.scrollView, viewButtonPrimary: self.viewButtonNext)
    }

    private func dismissKeyboard(_: Any?) {
        self.textFieldFirstName?.resignFirstResponder()
        self.textFieldLastName?.resignFirstResponder()
        self.textFieldEmailAddressPre?.resignFirstResponder()
        self.textFieldEmailDomain?.resignFirstResponder()
        self.textFieldCompanyToken?.resignFirstResponder()
    }
}

extension DPAGAutomaticTestRegistrationViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        self.textFieldEditing = textField
    }
}
