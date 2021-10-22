//
//  DPAGComplexPasswordViewController.swift
// ginlo
//
//  Created by RBU on 09/04/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

enum DPAGPasswordSecurityLevel: Int {
    case _0,
        _1,
        _2,
        _3,
        _4,
        _5,
        _6,
        _7
}

class DPAGComplexPasswordViewController: DPAGPasswordViewController, DPAGComplexPasswordViewControllerProtocol {
    @IBOutlet var textFieldPassword: DPAGTextField! {
        didSet {
            self.textFieldPassword.accessibilityIdentifier = "textFieldPassword"
            self.textFieldPassword.delegate = self
            self.textFieldPassword.delegateDelete = self
            self.textFieldPassword.returnKeyType = .done

            self.textFieldPassword.configureDefault()

            self.textFieldPassword.keyboardType = .default
            self.textFieldPassword.autocorrectionType = .no
            self.textFieldPassword.autocapitalizationType = .none
            self.textFieldPassword.clearButtonMode = .whileEditing
            self.textFieldPassword.isSecureTextEntry = true
            self.textFieldPassword.enablesReturnKeyAutomatically = true

            self.textFieldPassword.attributedPlaceholder = NSAttributedString(string: DPAGLocalizedString("registration.label.passwordSecLevel.placeholder"), attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
            self.textFieldPassword.enablesReturnKeyAutomatically = true
        }
    }

    @IBOutlet private var viewPasswordSecLevel0: UIView?
    @IBOutlet private var viewPasswordSecLevel1: UIView?
    @IBOutlet private var viewPasswordSecLevel2: UIView?
    @IBOutlet private var viewPasswordSecLevel3: UIView?
    @IBOutlet private var viewPasswordSecLevel4: UIView?
    @IBOutlet private var viewPasswordSecLevel5: UIView?
    @IBOutlet private var viewPasswordSecLevel6: UIView?
    @IBOutlet private var viewPasswordSecLevel7: UIView?

    private var regExSecValue0: NSRegularExpression? = try? NSRegularExpression(pattern: "^.{0,3}$", options: NSRegularExpression.Options())

    private var regExSecValue1: NSRegularExpression? = try? NSRegularExpression(pattern: "^.{4,6}$", options: NSRegularExpression.Options())

    private var regExSecValue2: NSRegularExpression? = try? NSRegularExpression(pattern: "^(?=.{4,6}$)(?=.*\\d)(?=.*[a-z])(?=.*[A-Z]).*$", options: NSRegularExpression.Options())

    private var regExSecValue30: NSRegularExpression? = try? NSRegularExpression(pattern: "^(?=.{4,6}$)(?=.*\\w)(?=.*\\W).*$", options: NSRegularExpression.Options())
    private var regExSecValue31: NSRegularExpression? = try? NSRegularExpression(pattern: "^(?=.{7,}$).*$", options: NSRegularExpression.Options())

    private var regExSecValue40: NSRegularExpression? = try? NSRegularExpression(pattern: "^(?=.{7,8}$)(?=.*\\d)(?=.*[a-z]).*$", options: NSRegularExpression.Options())
    private var regExSecValue41: NSRegularExpression? = try? NSRegularExpression(pattern: "^(?=.{7,8}$)(?=.*\\d)(?=.*[A-Z]).*$", options: NSRegularExpression.Options())
    private var regExSecValue42: NSRegularExpression? = try? NSRegularExpression(pattern: "^(?=.{7,8}$)(?=.*\\W)(?=.*[a-z]).*$", options: NSRegularExpression.Options())
    private var regExSecValue43: NSRegularExpression? = try? NSRegularExpression(pattern: "^(?=.{7,8}$)(?=.*\\W)(?=.*[A-Z]).*$", options: NSRegularExpression.Options())
    private var regExSecValue44: NSRegularExpression? = try? NSRegularExpression(pattern: "^(?=.{7,8}$)(?=.*\\d)(?=.*\\W).*$", options: NSRegularExpression.Options())
    private var regExSecValue45: NSRegularExpression? = try? NSRegularExpression(pattern: "^(?=.{7,8}$)(?=.*[a-z])(?=.*[A-Z]).*$", options: NSRegularExpression.Options())
    private var regExSecValue46: NSRegularExpression? = try? NSRegularExpression(pattern: "^(?=.{9,}$).*$", options: NSRegularExpression.Options())

    private var regExSecValue50: NSRegularExpression? = try? NSRegularExpression(pattern: "^(?=.{7,8}$)(?=.*\\d)(?=.*[a-z])(?=.*[A-Z]).*$", options: NSRegularExpression.Options())
    private var regExSecValue51: NSRegularExpression? = try? NSRegularExpression(pattern: "^(?=.{7,8}$)(?=.*\\d)(?=.*[a-z])(?=.*\\W).*$", options: NSRegularExpression.Options())
    private var regExSecValue52: NSRegularExpression? = try? NSRegularExpression(pattern: "^(?=.{7,8}$)(?=.*\\d)(?=.*[A-Z])(?=.*\\W).*$", options: NSRegularExpression.Options())
    private var regExSecValue53: NSRegularExpression? = try? NSRegularExpression(pattern: "^(?=.{7,8}$)(?=.*[a-z])(?=.*[A-Z])(?=.*\\W).*$", options: NSRegularExpression.Options())

    private var regExSecValue54: NSRegularExpression? = try? NSRegularExpression(pattern: "^(?=.{9,}$)(?=.*\\d)(?=.*[a-z]).*$", options: NSRegularExpression.Options())
    private var regExSecValue55: NSRegularExpression? = try? NSRegularExpression(pattern: "^(?=.{9,}$)(?=.*\\d)(?=.*\\W).*$", options: NSRegularExpression.Options())
    private var regExSecValue56: NSRegularExpression? = try? NSRegularExpression(pattern: "^(?=.{9,}$)(?=.*\\d)(?=.*[A-Z]).*$", options: NSRegularExpression.Options())
    private var regExSecValue57: NSRegularExpression? = try? NSRegularExpression(pattern: "^(?=.{9,}$)(?=.*[a-z])(?=.*\\W).*$", options: NSRegularExpression.Options())
    private var regExSecValue58: NSRegularExpression? = try? NSRegularExpression(pattern: "^(?=.{9,}$)(?=.*[a-z])(?=.*[A-Z]).*$", options: NSRegularExpression.Options())
    private var regExSecValue59: NSRegularExpression? = try? NSRegularExpression(pattern: "^(?=.{9,}$)(?=.*[A-Z])(?=.*\\W).*$", options: NSRegularExpression.Options())

    private var regExSecValue60: NSRegularExpression? = try? NSRegularExpression(pattern: "^(?=.{9,}$)(?=.*\\d)(?=.*[a-z])(?=.*[A-Z]).*$", options: NSRegularExpression.Options())
    private var regExSecValue61: NSRegularExpression? = try? NSRegularExpression(pattern: "^(?=.{9,}$)(?=.*\\d)(?=.*[a-z])(?=.*\\W).*$", options: NSRegularExpression.Options())
    private var regExSecValue62: NSRegularExpression? = try? NSRegularExpression(pattern: "^(?=.{9,}$)(?=.*\\d)(?=.*[A-Z])(?=.*\\W).*$", options: NSRegularExpression.Options())
    private var regExSecValue63: NSRegularExpression? = try? NSRegularExpression(pattern: "^(?=.{9,}$)(?=.*[a-z])(?=.*[A-Z])(?=.*\\W).*$", options: NSRegularExpression.Options())
    private var regExSecValue64: NSRegularExpression? = try? NSRegularExpression(pattern: "^(?=.{7,}$)(?=.*\\d)(?=.*[a-z])(?=.*[A-Z])(?=.*\\W).*$", options: NSRegularExpression.Options())

    private let regExSecValue7: NSRegularExpression? = try? NSRegularExpression(pattern: "^(?=.{9,}$)(?=.*\\d)(?=.*[a-z])(?=.*[A-Z])(?=.*\\W).*$", options: NSRegularExpression.Options())

    private var showSecLevel = false
    private var isNewPassword = false

    init(secLevelView showSecLevel: Bool, isNewPassword: Bool) {
        self.showSecLevel = showSecLevel
        self.isNewPassword = isNewPassword

        let nibName = showSecLevel ? "DPAGComplexPasswordWithLevelViewController" : "DPAGComplexPasswordViewController"

        super.init(nibName: nibName, bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        if self.showSecLevel {
            self.initSecLevels()
        }
    }

    private func initSecLevels() {
        self.viewPasswordSecLevel0?.layer.cornerRadius = 5
        self.viewPasswordSecLevel1?.layer.cornerRadius = 5
        self.viewPasswordSecLevel2?.layer.cornerRadius = 5
        self.viewPasswordSecLevel3?.layer.cornerRadius = 5
        self.viewPasswordSecLevel4?.layer.cornerRadius = 5
        self.viewPasswordSecLevel5?.layer.cornerRadius = 5
        self.viewPasswordSecLevel6?.layer.cornerRadius = 5
        self.viewPasswordSecLevel7?.layer.cornerRadius = 5

        self.viewPasswordSecLevel0?.backgroundColor = DPAGColorProvider.SecurityLevel.level0
        self.viewPasswordSecLevel1?.backgroundColor = DPAGColorProvider.SecurityLevel.level0
        self.viewPasswordSecLevel2?.backgroundColor = DPAGColorProvider.SecurityLevel.level0
        self.viewPasswordSecLevel3?.backgroundColor = DPAGColorProvider.SecurityLevel.level0
        self.viewPasswordSecLevel4?.backgroundColor = DPAGColorProvider.SecurityLevel.level0
        self.viewPasswordSecLevel5?.backgroundColor = DPAGColorProvider.SecurityLevel.level0
        self.viewPasswordSecLevel6?.backgroundColor = DPAGColorProvider.SecurityLevel.level0
        self.viewPasswordSecLevel7?.backgroundColor = DPAGColorProvider.SecurityLevel.level0
    }

    // MARK: - Public

    override func activate() {
        self.textFieldPassword.becomeFirstResponder()
    }

    override func reset() {
        self.textFieldPassword.resignFirstResponder()
        self.textFieldPassword.text = ""
        self.updatePwdSecureLevelWithPassword(self.textFieldPassword.text)
    }

    override func getEnteredPassword() -> String? {
        self.textFieldPassword.text
    }

    override func becomeFirstResponder() -> Bool {
        self.textFieldPassword.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        let retVal = super.resignFirstResponder()

        self.textFieldPassword.resignFirstResponder()

        return retVal
    }

    override func authenticate() {
        let enteredPassword = self.textFieldPassword.text

        switch self.state {
            case .registration:
                self.delegate?.passwordViewController(self, finishedInputWithPassword: enteredPassword)
            case .login:
                if self.validatePassword(enteredPassword) {
                    _ = self.tryToDecryptPrivateKey(enteredPassword)
                }
            case .enterPassword:
                _ = self.checkPasswordAndProceed(enteredPassword)
            case .changePassword:
                if self.validatePassword(enteredPassword) {
                    let state = self.verifyPassword(checkSimplePinUsage: false)
                    if !state.contains(.PwdOk) {
                        if let msg = getMessageForPasswordVerifyState(state) {
                            self.presentErrorAlert(alertConfig: AlertConfigError(messageIdentifier: msg, accessibilityIdentifier: "registration.validation.pwd_policies_fails"))
                        }
                    } else {
                        if self.checkPasswordReusability() {
                            self.delegate?.passwordViewController(self, finishedInputWithPassword: enteredPassword)
                        } else {
                            self.presentErrorAlert(alertConfig: AlertConfigError(messageIdentifier: "registration.validation.pwd_is_used_again"))
                        }
                    }
                }
            case .backup:
                self.delegate?.passwordViewController(self, finishedInputWithPassword: enteredPassword)
        }
    }

    func getMessageForPasswordVerifyState(_ state: DPAGPasswordViewControllerVerifyState) -> String? {
        if state.isEmpty || state.contains(.PwdOk) {
            return nil
        }

        var message = DPAGLocalizedString("registration.validation.pwd_policies_fails")

        if let pwdMinLength: Int = DPAGApplicationFacade.preferences.passwordMinLength {
            message += "\n" + DPAGLocalizedString("registration.validation.pwd_policies_min_length") + " \(pwdMinLength)"
        }

        if let pwdMinDigit: Int = DPAGApplicationFacade.preferences.passwordMinDigit {
            message += "\n" + DPAGLocalizedString("registration.validation.pwd_policies_min_digit") + " \(pwdMinDigit)"
        }

        if let pwdMinValue: Int = DPAGApplicationFacade.preferences.passwordMinLowercase {
            message += "\n" + DPAGLocalizedString("registration.validation.pwd_policies_min_lowercase") + " \(pwdMinValue)"
        }

        if let pwdMinValue: Int = DPAGApplicationFacade.preferences.passwordMinUppercase {
            message += "\n" + DPAGLocalizedString("registration.validation.pwd_policies_min_uppercase") + " \(pwdMinValue)"
        }

        if let pwdMinValue: Int = DPAGApplicationFacade.preferences.passwordMinSpecialChar {
            message += "\n" + DPAGLocalizedString("registration.validation.pwd_policies_min_special_char") + " \(pwdMinValue)"
        }

        if let pwdMinValue: Int = DPAGApplicationFacade.preferences.passwordMinClasses {
            message += "\n" + String(format: DPAGLocalizedString("registration.validation.pwd_policies_min_classes"), NSNumber(value: pwdMinValue as Int))
        }

        return message
    }

    // MARK: - Private

    private func validatePassword(_ enteredPassword: String?) -> Bool {
        if enteredPassword?.isEmpty ?? true {
            self.presentErrorAlert(alertConfig: AlertConfigError(messageIdentifier: "registration.validation.passwordCannotBeEmpty"))
            return false
        }
        return true
    }

    private func updatePwdSecureLevelWithPassword(_ password: String?) {
        guard self.showSecLevel else { return }

        let secLevel = self.getSecurityLevelForPassword(password)

        UIView.animate(withDuration: TimeInterval(UINavigationController.hideShowBarDuration)) { [weak self] in

            guard let strongSelf = self else { return }

            switch secLevel {
            case ._7:
                strongSelf.viewPasswordSecLevel0?.backgroundColor = DPAGColorProvider.SecurityLevel.level8
                strongSelf.viewPasswordSecLevel1?.backgroundColor = DPAGColorProvider.SecurityLevel.level8
                strongSelf.viewPasswordSecLevel2?.backgroundColor = DPAGColorProvider.SecurityLevel.level8
                strongSelf.viewPasswordSecLevel3?.backgroundColor = DPAGColorProvider.SecurityLevel.level8
                strongSelf.viewPasswordSecLevel4?.backgroundColor = DPAGColorProvider.SecurityLevel.level8
                strongSelf.viewPasswordSecLevel5?.backgroundColor = DPAGColorProvider.SecurityLevel.level8
                strongSelf.viewPasswordSecLevel6?.backgroundColor = DPAGColorProvider.SecurityLevel.level8
                strongSelf.viewPasswordSecLevel7?.backgroundColor = DPAGColorProvider.SecurityLevel.level8
            case ._6:
                strongSelf.viewPasswordSecLevel0?.backgroundColor = DPAGColorProvider.SecurityLevel.level7
                strongSelf.viewPasswordSecLevel1?.backgroundColor = DPAGColorProvider.SecurityLevel.level7
                strongSelf.viewPasswordSecLevel2?.backgroundColor = DPAGColorProvider.SecurityLevel.level7
                strongSelf.viewPasswordSecLevel3?.backgroundColor = DPAGColorProvider.SecurityLevel.level7
                strongSelf.viewPasswordSecLevel4?.backgroundColor = DPAGColorProvider.SecurityLevel.level7
                strongSelf.viewPasswordSecLevel5?.backgroundColor = DPAGColorProvider.SecurityLevel.level7
                strongSelf.viewPasswordSecLevel6?.backgroundColor = DPAGColorProvider.SecurityLevel.level7
                strongSelf.viewPasswordSecLevel7?.backgroundColor = DPAGColorProvider.SecurityLevel.level0
            case ._5:
                strongSelf.viewPasswordSecLevel0?.backgroundColor = DPAGColorProvider.SecurityLevel.level6
                strongSelf.viewPasswordSecLevel1?.backgroundColor = DPAGColorProvider.SecurityLevel.level6
                strongSelf.viewPasswordSecLevel2?.backgroundColor = DPAGColorProvider.SecurityLevel.level6
                strongSelf.viewPasswordSecLevel3?.backgroundColor = DPAGColorProvider.SecurityLevel.level6
                strongSelf.viewPasswordSecLevel4?.backgroundColor = DPAGColorProvider.SecurityLevel.level6
                strongSelf.viewPasswordSecLevel5?.backgroundColor = DPAGColorProvider.SecurityLevel.level6
                strongSelf.viewPasswordSecLevel6?.backgroundColor = DPAGColorProvider.SecurityLevel.level0
                strongSelf.viewPasswordSecLevel7?.backgroundColor = DPAGColorProvider.SecurityLevel.level0
            case ._4:
                strongSelf.viewPasswordSecLevel0?.backgroundColor = DPAGColorProvider.SecurityLevel.level5
                strongSelf.viewPasswordSecLevel1?.backgroundColor = DPAGColorProvider.SecurityLevel.level5
                strongSelf.viewPasswordSecLevel2?.backgroundColor = DPAGColorProvider.SecurityLevel.level5
                strongSelf.viewPasswordSecLevel3?.backgroundColor = DPAGColorProvider.SecurityLevel.level5
                strongSelf.viewPasswordSecLevel4?.backgroundColor = DPAGColorProvider.SecurityLevel.level5
                strongSelf.viewPasswordSecLevel5?.backgroundColor = DPAGColorProvider.SecurityLevel.level0
                strongSelf.viewPasswordSecLevel6?.backgroundColor = DPAGColorProvider.SecurityLevel.level0
                strongSelf.viewPasswordSecLevel7?.backgroundColor = DPAGColorProvider.SecurityLevel.level0
            case ._3:
                strongSelf.viewPasswordSecLevel0?.backgroundColor = DPAGColorProvider.SecurityLevel.level4
                strongSelf.viewPasswordSecLevel1?.backgroundColor = DPAGColorProvider.SecurityLevel.level4
                strongSelf.viewPasswordSecLevel2?.backgroundColor = DPAGColorProvider.SecurityLevel.level4
                strongSelf.viewPasswordSecLevel3?.backgroundColor = DPAGColorProvider.SecurityLevel.level4
                strongSelf.viewPasswordSecLevel4?.backgroundColor = DPAGColorProvider.SecurityLevel.level0
                strongSelf.viewPasswordSecLevel5?.backgroundColor = DPAGColorProvider.SecurityLevel.level0
                strongSelf.viewPasswordSecLevel6?.backgroundColor = DPAGColorProvider.SecurityLevel.level0
                strongSelf.viewPasswordSecLevel7?.backgroundColor = DPAGColorProvider.SecurityLevel.level0
            case ._2:
                strongSelf.viewPasswordSecLevel0?.backgroundColor = DPAGColorProvider.SecurityLevel.level3
                strongSelf.viewPasswordSecLevel1?.backgroundColor = DPAGColorProvider.SecurityLevel.level3
                strongSelf.viewPasswordSecLevel2?.backgroundColor = DPAGColorProvider.SecurityLevel.level3
                strongSelf.viewPasswordSecLevel3?.backgroundColor = DPAGColorProvider.SecurityLevel.level0
                strongSelf.viewPasswordSecLevel4?.backgroundColor = DPAGColorProvider.SecurityLevel.level0
                strongSelf.viewPasswordSecLevel5?.backgroundColor = DPAGColorProvider.SecurityLevel.level0
                strongSelf.viewPasswordSecLevel6?.backgroundColor = DPAGColorProvider.SecurityLevel.level0
                strongSelf.viewPasswordSecLevel7?.backgroundColor = DPAGColorProvider.SecurityLevel.level0
            case ._1:
                strongSelf.viewPasswordSecLevel0?.backgroundColor = DPAGColorProvider.SecurityLevel.level2
                strongSelf.viewPasswordSecLevel1?.backgroundColor = DPAGColorProvider.SecurityLevel.level2
                strongSelf.viewPasswordSecLevel2?.backgroundColor = DPAGColorProvider.SecurityLevel.level0
                strongSelf.viewPasswordSecLevel3?.backgroundColor = DPAGColorProvider.SecurityLevel.level0
                strongSelf.viewPasswordSecLevel4?.backgroundColor = DPAGColorProvider.SecurityLevel.level0
                strongSelf.viewPasswordSecLevel5?.backgroundColor = DPAGColorProvider.SecurityLevel.level0
                strongSelf.viewPasswordSecLevel6?.backgroundColor = DPAGColorProvider.SecurityLevel.level0
                strongSelf.viewPasswordSecLevel7?.backgroundColor = DPAGColorProvider.SecurityLevel.level0
            case ._0:
                if (password?.isEmpty ?? true) == false {
                    strongSelf.viewPasswordSecLevel0?.backgroundColor = DPAGColorProvider.SecurityLevel.level1
                    strongSelf.viewPasswordSecLevel1?.backgroundColor = DPAGColorProvider.SecurityLevel.level0
                    strongSelf.viewPasswordSecLevel2?.backgroundColor = DPAGColorProvider.SecurityLevel.level0
                    strongSelf.viewPasswordSecLevel3?.backgroundColor = DPAGColorProvider.SecurityLevel.level0
                    strongSelf.viewPasswordSecLevel4?.backgroundColor = DPAGColorProvider.SecurityLevel.level0
                    strongSelf.viewPasswordSecLevel5?.backgroundColor = DPAGColorProvider.SecurityLevel.level0
                    strongSelf.viewPasswordSecLevel6?.backgroundColor = DPAGColorProvider.SecurityLevel.level0
                    strongSelf.viewPasswordSecLevel7?.backgroundColor = DPAGColorProvider.SecurityLevel.level0
                } else {
                    strongSelf.viewPasswordSecLevel0?.backgroundColor = DPAGColorProvider.SecurityLevel.level0
                    strongSelf.viewPasswordSecLevel1?.backgroundColor = DPAGColorProvider.SecurityLevel.level0
                    strongSelf.viewPasswordSecLevel2?.backgroundColor = DPAGColorProvider.SecurityLevel.level0
                    strongSelf.viewPasswordSecLevel3?.backgroundColor = DPAGColorProvider.SecurityLevel.level0
                    strongSelf.viewPasswordSecLevel4?.backgroundColor = DPAGColorProvider.SecurityLevel.level0
                    strongSelf.viewPasswordSecLevel5?.backgroundColor = DPAGColorProvider.SecurityLevel.level0
                    strongSelf.viewPasswordSecLevel6?.backgroundColor = DPAGColorProvider.SecurityLevel.level0
                    strongSelf.viewPasswordSecLevel7?.backgroundColor = DPAGColorProvider.SecurityLevel.level0
                }
            }
        }
    }

    open override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.textFieldPassword.attributedPlaceholder = NSAttributedString(string: DPAGLocalizedString("registration.label.passwordSecLevel.placeholder"), attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
                initSecLevels()
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    private func regExFound(pwd: String, regExs: NSRegularExpression?...) -> Bool {
        let pwdLength = (pwd as NSString).length

        for regEx in regExs {
            if let regEx = regEx, regEx.numberOfMatches(in: pwd, options: .reportCompletion, range: NSRange(location: 0, length: pwdLength)) == 1 {
                return true
            }
        }

        return false
    }

    private func getSecurityLevelForPassword(_ password: String?) -> DPAGPasswordSecurityLevel {
        guard let pwd = password, pwd.isEmpty == false else {
            return ._0
        }

        if self.regExFound(pwd: pwd, regExs: self.regExSecValue7) {
            return ._7
        } else if self.regExFound(pwd: pwd, regExs: self.regExSecValue60, self.regExSecValue61, self.regExSecValue62, self.regExSecValue63, self.regExSecValue64) {
            return ._6
        } else if self.regExFound(pwd: pwd, regExs: self.regExSecValue50, self.regExSecValue51, self.regExSecValue52, self.regExSecValue53, self.regExSecValue54, self.regExSecValue55, self.regExSecValue56, self.regExSecValue57, self.regExSecValue58, self.regExSecValue59) {
            return ._5
        } else if self.regExFound(pwd: pwd, regExs: self.regExSecValue40, self.regExSecValue41, self.regExSecValue42, self.regExSecValue43, self.regExSecValue44, self.regExSecValue45, self.regExSecValue46) {
            return ._4
        } else if self.regExFound(pwd: pwd, regExs: self.regExSecValue30, self.regExSecValue31) {
            return ._3
        } else if self.regExFound(pwd: pwd, regExs: self.regExSecValue2) {
            return ._2
        } else if self.regExFound(pwd: pwd, regExs: self.regExSecValue1) {
            return ._1
        } else if self.regExFound(pwd: pwd, regExs: self.regExSecValue0) {
            return ._0
        }

        // this line shold never be reached
        return ._0
    }
}

// MARK: - UITextFieldDelegate

extension DPAGComplexPasswordViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_: UITextField) -> Bool {
        self.authenticate()
        return true
    }

    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        if let textFieldText = textField.text {
            let text: NSString = textFieldText as NSString
            let textFieldTextLength = text.length

            if self.delegate?.textField?(textField, shouldChangeCharactersIn: NSRange(location: 0, length: textFieldTextLength), replacementString: "") ?? true {
                self.updatePwdSecureLevelWithPassword("")
                return true
            }
        }
        return false
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let retVal = self.delegate?.textField?(textField, shouldChangeCharactersIn: range, replacementString: string) ?? true

        if retVal, self.showSecLevel {
            if let textFieldText = textField.text {
                let text: NSString = textFieldText as NSString
                let resultedString = text.replacingCharacters(in: range, with: string)

                self.updatePwdSecureLevelWithPassword(resultedString)
            } else {
                self.updatePwdSecureLevelWithPassword("")
            }
        }
        return retVal
    }
}

extension DPAGComplexPasswordViewController: DPAGTextFieldDelegate {
    func willDeleteBackward(_: UITextField) {}

    func didDeleteBackward(_ textField: UITextField) {
        if self.showSecLevel {
            if let textFieldText = textField.text {
                self.updatePwdSecureLevelWithPassword(textFieldText)
            } else {
                self.updatePwdSecureLevelWithPassword("")
            }
        }
    }
}
