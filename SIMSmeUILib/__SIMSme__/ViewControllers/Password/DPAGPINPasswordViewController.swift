//
//  DPAGPINPasswordViewController.swift
//  SIMSme
//
//  Created by RBU on 09/04/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGPINPasswordViewController: DPAGPasswordViewController, DPAGPINPasswordViewControllerProtocol {
    private static let PIN_SIZE: CGFloat = 14
    private lazy var imagePINempty = UIImage.circleImage(size: CGSize(width: DPAGPINPasswordViewController.PIN_SIZE, height: DPAGPINPasswordViewController.PIN_SIZE), colorFill: self.colorFillEmpty, colorBorder: self.colorBorderEmpty)
    private lazy var imagePINfocused = UIImage.circleImage(size: CGSize(width: DPAGPINPasswordViewController.PIN_SIZE, height: DPAGPINPasswordViewController.PIN_SIZE), colorFill: self.colorFillFocused, colorBorder: self.colorBorderFocused)
    private lazy var imagePINfilled = UIImage.circleImage(size: CGSize(width: DPAGPINPasswordViewController.PIN_SIZE, height: DPAGPINPasswordViewController.PIN_SIZE), colorFill: self.colorFillFilled, colorBorder: self.colorBorderFilled)

    @IBOutlet private var textFieldPIN: UITextField!

    @IBOutlet private var firstImageView: UIImageView!
    @IBOutlet private var secondImageView: UIImageView!
    @IBOutlet private var thirdImageView: UIImageView!
    @IBOutlet private var fourthImageView: UIImageView!

    private var textfieldsImageViews: [UIImageView] = []

    var colorFillEmpty = DPAGColorProvider.shared[.passwordPIN]
    var colorBorderEmpty = UIColor.clear
    var colorFillFocused = UIColor.clear
    var colorBorderFocused = DPAGColorProvider.shared[.passwordPIN]
    var colorFillFilled = DPAGColorProvider.shared[.passwordPIN]
    var colorBorderFilled = UIColor.clear

    private var showSecLevel = false

    init(secLevelView showSecLevel: Bool) {
        self.showSecLevel = showSecLevel

        let nibName = showSecLevel ? "DPAGPINPasswordWithLevelViewController" : "DPAGPINPasswordViewController"

        super.init(nibName: nibName, bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                colorFillEmpty = DPAGColorProvider.shared[.passwordPIN]
                colorBorderFocused = DPAGColorProvider.shared[.passwordPIN]
                colorFillFilled = DPAGColorProvider.shared[.passwordPIN]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        self.textFieldPIN.accessibilityIdentifier = "textFieldPIN"

        self.textfieldsImageViews = [self.firstImageView, self.secondImageView, self.thirdImageView, self.fourthImageView]
        self.textFieldPIN.configureDefault()
        self.textFieldPIN.delegate = self
        self.textFieldPIN.keyboardType = .numberPad
        self.textFieldPIN.isHidden = true

        for idx in 0 ..< self.textfieldsImageViews.count {
            let pinImageView = self.textfieldsImageViews[idx]

            pinImageView.image = self.imagePINempty
        }

        self.view.isUserInteractionEnabled = true

        let tapGr = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))

        self.view.addGestureRecognizer(tapGr)
    }

    @objc
    private func handleTap(_: UITapGestureRecognizer) {
        // In case something goes wrong and the Keyboard gets dismissed
        if self.textFieldPIN.isFirstResponder == false {
            self.reset()
            self.activate()
        }
    }

    override func activate() {
        super.activate()
        self.textFieldPIN.becomeFirstResponder()
        self.updatePINImagesForString(self.textFieldPIN.text)
    }

    override func reset() {
        super.reset()
        self.clearInput()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.clearInput()
    }

    private func clearInput() {
        self.textFieldPIN.text = ""
        self.updatePINImagesForString(self.textFieldPIN.text)

    }

    override func resignFirstResponder() -> Bool {
        let retVal = super.resignFirstResponder()

        self.textFieldPIN.resignFirstResponder()

        return retVal
    }

    override func becomeFirstResponder() -> Bool {
        super.activate()
        self.updatePINImagesForString(self.textFieldPIN.text)

        return self.textFieldPIN.becomeFirstResponder()
    }

    // MARK: - Password Handling

    override func getEnteredPassword() -> String? {
        self.textFieldPIN.text
    }

    private func decryptPassword() {
        if let password = self.getEnteredPassword() {
            let isDecrypted = (self.tryToDecryptPrivateKey(password) == false)

            if isDecrypted {
                self.clearInput()
                _ = self.becomeFirstResponder()
            }
        }
    }

    private func updatePINImagesForString(_ string: String?) {
        for i in 0 ..< self.textfieldsImageViews.count {
            if (string?.count ?? 0) > i {
                self.textfieldsImageViews[i].image = self.imagePINfilled
            } else {
                if (string?.count ?? 0) == i {
                    self.textfieldsImageViews[i].image = self.imagePINfocused
                } else {
                    self.textfieldsImageViews[i].image = self.imagePINempty
                }
            }
        }
    }

    override func passwordEnteredCanBeValidated(_ enteredPassword: String?) -> Bool {
        enteredPassword?.count == 4
    }

    override func authenticate() {
        let password = self.getEnteredPassword()

        switch self.state {
        case .registration:

            if self.passwordEnteredCanBeValidated(password) {
                self.delegate?.passwordViewController(self, finishedInputWithPassword: password)
            }

        case .login:

            if self.passwordEnteredCanBeValidated(password) {
                self.decryptPassword()
            }

        case .enterPassword:

            if self.passwordEnteredCanBeValidated(password), self.checkPasswordAndProceed(password) == false {
                self.reset()
                self.activate()
            }

        case .changePassword:

            if self.passwordEnteredCanBeValidated(password) {
                self.delegate?.passwordViewController(self, finishedInputWithPassword: password)
                self.reset()
            }

        case .backup:
            break
        }
    }
}

// MARK: - GUI/Input Handling

extension DPAGPINPasswordViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if let textFieldText = textField.text {
            let text: NSString = textFieldText as NSString
            let resultedString = text.replacingCharacters(in: range, with: string)

            self.updatePINImagesForString(resultedString)

            let result = self.delegate?.textField?(textField, shouldChangeCharactersIn: range, replacementString: string) ?? true

            if resultedString.count == 4 {
                self.textFieldPIN.text = resultedString
                _ = self.resignFirstResponder()

                return false
            }

            return result
        }
        return true
    }

    func textFieldShouldReturn(_: UITextField) -> Bool {
        self.authenticate()

        return true
    }
}
