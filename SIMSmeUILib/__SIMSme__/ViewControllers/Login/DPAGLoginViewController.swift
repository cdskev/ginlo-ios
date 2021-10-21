//
//  DPAGLoginViewController.swift
// ginlo
//
//  Created by RBU on 11/04/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGLoginViewController: DPAGViewController, DPAGLoginViewControllerProtocol {
    var mustChangePassword = false

    static let sharedInstance = DPAGLoginViewController()
    private let pageViewController = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
    private var currentLoginVC: DPAGLoginViewControllerLocalProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.pageViewController.willMove(toParent: self)
        self.addChild(self.pageViewController)
        self.pageViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.pageViewController.view.frame = self.view.bounds
        self.view.addSubview(self.pageViewController.view)
        self.pageViewController.didMove(toParent: self)
    }

    override func appWillResignActive() {
        super.appWillResignActive()
        self.currentLoginVC?.passwordViewController?.resignFirstResponder()
    }

    override func appDidBecomeActive() {
        super.appDidBecomeActive()
        self.currentLoginVC?.passwordViewController?.becomeFirstResponder()
    }

    func start() {
        self.currentLoginVC?.start()
    }

    func companyRecoveryPasswordSuccess() {
        self.currentLoginVC?.companyRecoveryPasswordSuccess()
    }

    func requestPassword(withTouchID: Bool, completion: @escaping DPAGPasswordRequest) {
        if !Thread.isMainThread {
            self.performBlockOnMainThread { [weak self] in
                self?.requestPassword(withTouchID: withTouchID, completion: completion)
            }
            return
        }
        if DPAGApplicationFacade.preferences.hasSystemGeneratedPassword {
            completion(true)
            return
        }
        self.setupPasswordController(withTouchID: withTouchID)
        self.show(animated: true) { [weak self] in
            self?.currentLoginVC?.requestPassword(completion)
        }
    }

    func loginRequest(withTouchID: Bool, completion: DPAGCompletion?) {
        if !Thread.isMainThread {
            self.performBlockOnMainThread { [weak self] in
                self?.loginRequest(withTouchID: withTouchID, completion: completion)
            }
            return
        }
        self.setupPasswordController(withTouchID: withTouchID)
        self.show(animated: false) { [weak self] in
            self?.currentLoginVC?.loginRequest()
            completion?()
        }
    }

    private func setupPasswordController(withTouchID: Bool) {
        if withTouchID, DPAGApplicationFacade.preferences.touchIDEnabled, CryptoHelper.sharedInstance?.hasPrivateKeyForTouchID() ?? false {
            let nextVC = DPAGLoginViewControllerTouchID()
            nextVC.loginPresenter = self
            self.currentLoginVC = nextVC
            self.pageViewController.setViewControllers([nextVC], direction: .forward, animated: false, completion: nil)
            return
        }

        switch DPAGApplicationFacade.preferences.passwordType {
            case .complex:
                let nextVC = DPAGLoginViewControllerComplex()
                nextVC.loginPresenter = self
                self.currentLoginVC = nextVC
                self.pageViewController.setViewControllers([nextVC], direction: .forward, animated: false, completion: nil)
            case .pin:
                let nextVC = DPAGLoginViewControllerPIN()
                nextVC.loginPresenter = self
                self.currentLoginVC = nextVC
                self.pageViewController.setViewControllers([nextVC], direction: .forward, animated: false, completion: nil)
            case .gesture:
                break
        }
    }
}

extension DPAGLoginViewController: DPAGLoginViewControllerPresenterProtocol {
    fileprivate func show(animated: Bool, completion: DPAGCompletion?) {
        if self.isBeingPresented || self.presentingViewController != nil {
            self.dismiss(animated: false, completion: {
                self.show(animated: animated, completion: completion)
            })
            return
        }
        if let vcRoot = AppConfig.appWindow()??.rootViewController {
            var vc = vcRoot
            while let presentedViewController = vc.presentedViewController, presentedViewController != self {
                vc = presentedViewController
            }
                        self.modalPresentationStyle = .fullScreen
            vc.present(self, animated: animated, completion: { [weak self] in
                completion?()
                self?.currentLoginVC?.start()
            })
        }
    }

    fileprivate func hide(animated: Bool, completion: DPAGCompletion?) {
        self.dismiss(animated: animated, completion: completion)
    }

    internal func touchIDAuthenticationFailed() {
        let state = self.currentLoginVC?.state
        let passwordRequestBlock = self.currentLoginVC?.passwordRequestBlock
        self.setupPasswordController(withTouchID: false)
        self.currentLoginVC?.passwordRequestBlock = passwordRequestBlock
        self.currentLoginVC?.state = state ?? .login
        self.start()
    }
}

protocol DPAGLoginViewControllerLocalProtocol: DPAGPasswordInputDelegate {
    var state: DPAGPasswordViewControllerState { get set }
    var passwordRequestBlock: DPAGPasswordRequest? { get set }
    var passwordViewController: (UIViewController & DPAGPasswordViewControllerProtocol)? { get }

    func companyRecoveryPasswordSuccess()

    func requestPassword(_ block: @escaping DPAGPasswordRequest)
    func loginRequest()
    func start()
}

private protocol DPAGLoginViewControllerPresenterProtocol: AnyObject {
    func touchIDAuthenticationFailed()
    func show(animated: Bool, completion: DPAGCompletion?)
    func hide(animated: Bool, completion: DPAGCompletion?)
}

private class DPAGLoginViewControllerBase: DPAGViewControllerWithKeyboard, DPAGPasswordInputDelegate, DPAGLoginViewControllerLocalProtocol {
    fileprivate var loginPresenter: DPAGLoginViewControllerPresenterProtocol?

    fileprivate var state: DPAGPasswordViewControllerState = .login {
        didSet {
            self.passwordViewController?.state = self.state
        }
    }

    fileprivate var passwordViewController: (UIViewController & DPAGPasswordViewControllerProtocol)?
    fileprivate var passwordRequestBlock: DPAGPasswordRequest?

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

//        self.passwordViewController?.becomeFirstResponder()
    }

    override func handleViewTapped(_: Any?) {
        self.passwordViewController?.resignFirstResponder()
    }

    @objc
    fileprivate func cancelPasswordRequest() {
        self.passwordViewController?.resignFirstResponder()
        self.loginPresenter?.hide(animated: true) { [weak self] in
            self?.passwordRequestBlock?(false)
            self?.passwordRequestBlock = nil
        }
    }

    func start() {
        self.passwordViewController?.activate()
    }

    fileprivate func countdownPasswordTries() {
        var triesLeft = DPAGApplicationFacade.preferences.passwordRetriesLeft
        triesLeft -= 1
        DPAGApplicationFacade.preferences.passwordRetriesLeft = triesLeft
        if triesLeft <= 0 {
            self.performBlockOnMainThread { [weak self] in
                self?.passwordViewController?.resignFirstResponder()
                NotificationCenter.default.post(name: DPAGStrings.Notification.Application.SECURITY_RESET_APP, object: nil)
                self?.loginPresenter?.hide(animated: true, completion: nil)
            }
        } else {
            let format = DPAGLocalizedString("login.password.incorrect")
            self.passwordViewController?.resignFirstResponder()
            self.presentErrorAlert(alertConfig: AlertConfigError(messageIdentifier: String(format: format, NSNumber(value: triesLeft)), accessibilityIdentifier: "login.password.incorrect"))
        }
    }

    // MARK: - DPAGPasswordInputDelegate

    func passwordDidDecryptPrivateKey() {
        DPAGLog("passwordDidDecryptPrivateKey")
        if CryptoHelper.sharedInstance?.isPrivateKeyDecrypted() ?? false {
            if DPAGApplicationFacade.preferences.passwordOnStartEnabled == false {
                do {
                    try CryptoHelper.sharedInstance?.putDecryptedPKFromHeapInKeyChain()
                } catch {
                    DPAGLog(error)
                }
            }
            if DPAGApplicationFacade.preferences.touchIDEnabled {
                do {
                    try CryptoHelper.sharedInstance?.putDecryptedPKFromHeapInKeyChainForTouchID()
                } catch {
                    DPAGLog(error)
                }
            }
        }
        NotificationCenter.default.post(name: DPAGStrings.Notification.Application.DID_COMPLETE_LOGIN, object: nil)
        self.passwordViewController?.resignFirstResponder()
        DPAGApplicationFacade.preferences.resetPasswordTries()
        DPAGApplicationFacade.preferences.passwordInputWrongCounter = 0
        self.loginPresenter?.hide(animated: true) {
            NotificationCenter.default.post(name: DPAGStrings.Notification.Application.DID_HIDE_LOGIN, object: nil)
        }
    }

    func passwordCorrespondsNotToThePasswordPolicies() {
        self.passwordViewController?.resignFirstResponder()
        self.presentErrorAlert(alertConfig: AlertConfigError(messageIdentifier: "registration.validation.pwd_verifcation_fails", okActionHandler: { [weak self] _ in
            DPAGApplicationFacadeUIBase.loginVC.mustChangePassword = true
            NotificationCenter.default.post(name: DPAGStrings.Notification.Application.DID_COMPLETE_LOGIN, object: nil)
            self?.loginPresenter?.hide(animated: true) {
                NotificationCenter.default.post(name: DPAGStrings.Notification.Application.DID_HIDE_LOGIN, object: nil)
            }
        }))
    }

    func companyRecoveryPasswordSuccess() {
        DPAGApplicationFacadeUIBase.loginVC.mustChangePassword = true

        NotificationCenter.default.post(name: DPAGStrings.Notification.Application.DID_COMPLETE_LOGIN, object: nil)

        self.passwordViewController?.resignFirstResponder()

        self.loginPresenter?.hide(animated: true) {
            NotificationCenter.default.post(name: DPAGStrings.Notification.Application.DID_HIDE_LOGIN, object: nil)
        }
    }

    func passwordIsExpired() {
        self.passwordViewController?.resignFirstResponder()
        self.presentErrorAlert(alertConfig: AlertConfigError(messageIdentifier: "registration.validation.pwd_is_expired", okActionHandler: { [weak self] _ in
            DPAGApplicationFacadeUIBase.loginVC.mustChangePassword = true
            NotificationCenter.default.post(name: DPAGStrings.Notification.Application.DID_COMPLETE_LOGIN, object: nil)
            self?.loginPresenter?.hide(animated: true) {
                NotificationCenter.default.post(name: DPAGStrings.Notification.Application.DID_HIDE_LOGIN, object: nil)
            }
        }))
    }

    func touchIDAuthenticationFailed() {
        self.loginPresenter?.touchIDAuthenticationFailed()
    }

    func loginRequest() {
        self.state = .login
    }

    func requestPassword(_ block: @escaping DPAGPasswordRequest) {
        self.passwordRequestBlock = block
        self.state = .enterPassword
    }

    func passwordDidNotDecryptPrivateKey() {
        self.passwordIsInvalid()
    }

    func passwordIsValid() {
        DPAGApplicationFacade.preferences.resetPasswordTries()
        DPAGApplicationFacade.preferences.passwordInputWrongCounter = 0
        self.passwordViewController?.resignFirstResponder()
        self.loginPresenter?.hide(animated: true) { [weak self] in
            self?.passwordRequestBlock?(true)
            self?.passwordRequestBlock = nil
        }
    }

    func passwordIsInvalid() {}
    func passwordViewController(_: DPAGPasswordViewControllerProtocol, finishedInputWithPassword _: String?) {}
}

private class DPAGLoginViewControllerTouchID: DPAGLoginViewControllerBase {
    @IBOutlet private var passwordContainer: UIView! {
        didSet {
            let passwordViewControllerTouchID = DPAGApplicationFacadeUIBase.passwordTouchIDVC()
            passwordViewControllerTouchID.delegate = self
            passwordViewControllerTouchID.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            passwordViewControllerTouchID.view.frame = CGRect(x: 0, y: 0, width: self.passwordContainer.frame.size.width, height: self.passwordContainer.frame.size.height)
            passwordViewControllerTouchID.willMove(toParent: nil)
            self.addChild(passwordViewControllerTouchID)
            self.passwordContainer.addSubview(passwordViewControllerTouchID.view)
            passwordViewControllerTouchID.didMove(toParent: self)
            self.passwordViewController = passwordViewControllerTouchID
        }
    }

    init() {
        super.init(nibName: "DPAGLoginViewControllerTouchID", bundle: Bundle(for: type(of: self)))
    }
}

private class DPAGLoginViewControllerInput: DPAGLoginViewControllerBase {
    @IBOutlet fileprivate var cancelButton: UIButton! {
        didSet {
            self.cancelButton.accessibilityIdentifier = "cancelButton"
            self.cancelButton.setImage(DPAGImageProvider.shared[.kImageBarButtonNavBack], for: .normal)
            self.cancelButton.addTarget(self, action: #selector(cancelPasswordRequest), for: .touchUpInside)
            self.cancelButton.isHidden = true
        }
    }

    @IBOutlet fileprivate var passwordContainer: UIView! {
        didSet {}
    }

    @IBOutlet fileprivate var scrollView: UIScrollView! {
        didSet {}
    }

    @IBOutlet fileprivate var viewButtonNext: DPAGButtonPrimaryView! {
        didSet {
            self.viewButtonNext.button.accessibilityIdentifier = "buttonNext"
            self.viewButtonNext.button.addTarget(self, action: #selector(buttonNextAction(_:)), for: .touchUpInside)
            self.viewButtonNext.button.setTitle(DPAGLocalizedString("login.loginButton.titleForLoginRequest"), for: .normal)
        }
    }

    @IBOutlet fileprivate var buttonForgotPassword: UIButton! {
        didSet {
            self.buttonForgotPassword.accessibilityIdentifier = "buttonForgotPassword"
            self.buttonForgotPassword.isHidden = true
            self.buttonForgotPassword.setTitle(DPAGLocalizedString("login.passwordForgottenButton.title"), for: .normal)
            self.buttonForgotPassword.addTarget(self, action: #selector(buttonForgotPasswordAction(_:)), for: .touchUpInside)
        }
    }

    @IBOutlet fileprivate var constraintPasswordContainerHeight: NSLayoutConstraint!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.cancelButton.tintColor = DPAGColorProvider.shared[.buttonTintNoBackground]
        self.buttonForgotPassword.setTitleColor(DPAGColorProvider.shared[.buttonTintNoBackground], for: .normal)
    }

    override func handleKeyboardWillShow(_ aNotification: Notification) {
        super.handleKeyboardWillShow(aNotification, scrollView: self.scrollView, viewVisible: self.passwordContainer, viewButtonPrimary: self.viewButtonNext)
    }

    override func handleKeyboardWillHide(_ aNotification: Notification) {
        super.handleKeyboardWillHide(aNotification, scrollView: self.scrollView, viewButtonPrimary: self.viewButtonNext)
    }

    override func loginRequest() {
        self.viewButtonNext.button.setTitle(DPAGLocalizedString("login.loginButton.titleForLoginRequest"), for: .normal)
        self.viewButtonNext.isEnabled = false
        super.loginRequest()
    }

    override func requestPassword(_ block: @escaping DPAGPasswordRequest) {
        self.viewButtonNext.button.setTitle(DPAGLocalizedString("res.continue"), for: .normal)
        self.viewButtonNext.isEnabled = false
        self.cancelButton.isHidden = false
        super.requestPassword(block)
    }

    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.cancelButton.tintColor = DPAGColorProvider.shared[.buttonTintNoBackground]
                self.buttonForgotPassword.setTitleColor(DPAGColorProvider.shared[.buttonTintNoBackground], for: .normal)
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    override func passwordIsInvalid() {
        super.passwordIsInvalid()
        if DPAGApplicationFacade.preferences.deleteData {
            self.countdownPasswordTries()
        } else {
            var countWrongInput = DPAGApplicationFacade.preferences.passwordInputWrongCounter
            countWrongInput += 1
            DPAGApplicationFacade.preferences.passwordInputWrongCounter = countWrongInput
            let block: DPAGCompletion = { [weak self] in
                self?.passwordViewController?.resignFirstResponder()
                self?.presentErrorAlert(alertConfig: UIViewController.AlertConfigError(messageIdentifier: "login.password.incorrect.noTries", okActionHandler: { [weak self] _ in
                    self?.passwordViewController?.reset()
                    self?.passwordViewController?.activate()
                }))
            }
            if countWrongInput > 2 {
                DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true, completion: { _ in
                    Thread.sleep(forTimeInterval: TimeInterval(min(300, pow(CGFloat(2), CGFloat(countWrongInput - 3)))))
                    DPAGProgressHUD.sharedInstance.hide(true, completion: block)
                })
            } else {
                block()
            }
        }
        if self.buttonForgotPassword.isEnabled {
            self.buttonForgotPassword.isHidden = false
        }
    }

    @objc
    private func buttonForgotPasswordAction(_: Any?) {
        if DPAGApplicationFacade.preferences.backgroundAccessToken != nil {
            if DPAGApplicationFacade.preferences.isBaMandant, DPAGApplicationFacade.preferences.simsmeRecoveryEnabled {
                let vc = DPAGApplicationFacadeUIBase.passwordForgotVC()
                let navVC = DPAGApplicationFacadeUIBase.navVC(rootViewController: vc)
                self.present(navVC, animated: true, completion: nil)
                return
            }
            if DPAGApplicationFacade.preferences.isBaMandant, (try? DPAGApplicationFacade.accountManager.hasCompanyRecoveryPasswordFile()) ?? false, let vc = DPAGApplicationFacade.preferences.viewControllerForIdent(DPAGWhiteLabelNextView.dpagPasswordForgotViewController) {
                let navVC = DPAGApplicationFacadeUIBase.navVC(rootViewController: vc)
                self.present(navVC, animated: true, completion: nil)
                return
            }
        }
        let nextVC = DPAGApplicationFacadeUIBase.initialPasswordForgotVC()
        let navVC = DPAGApplicationFacadeUIBase.navVC(rootViewController: nextVC)
        self.present(navVC, animated: true, completion: nil)
    }

    @objc
    private func buttonNextAction(_: Any?) {
        self.passwordViewController?.authenticate()
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if let textFieldText = textField.text {
            let text: NSString = textFieldText as NSString
            let resultedString = text.replacingCharacters(in: range, with: string) as NSString
            self.viewButtonNext.isEnabled = DPAGApplicationFacade.preferences.passwordType == .pin ? resultedString.length == 4 : resultedString.length > 0
            if DPAGApplicationFacade.preferences.passwordType == .pin, resultedString.length == 4 {
                self.perform(#selector(buttonNextAction(_:)), with: nil, afterDelay: 0.1)
            }
        } else {
            self.viewButtonNext.isEnabled = false
        }
        return true
    }
}

private class DPAGLoginViewControllerComplex: DPAGLoginViewControllerInput {
    init() {
        super.init(nibName: "DPAGLoginViewControllerComplex", bundle: Bundle(for: type(of: self)))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let passwordViewControllerComplex = DPAGApplicationFacadeUIBase.passwordComplexVC(secLevelView: false, isNewPassword: false)
        passwordViewControllerComplex.delegate = self
        passwordViewControllerComplex.willMove(toParent: self)
        self.addChild(passwordViewControllerComplex)
        self.passwordContainer.addSubview(passwordViewControllerComplex.view)
        passwordViewControllerComplex.didMove(toParent: self)
        passwordViewControllerComplex.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate(self.passwordContainer.constraintsFill(subview: passwordViewControllerComplex.view))
        self.passwordViewController = passwordViewControllerComplex
        passwordViewControllerComplex.textFieldPassword.backgroundColor = .clear
        passwordViewControllerComplex.textFieldPassword.textColor = DPAGColorProvider.shared[.textFieldText]
        passwordViewControllerComplex.textFieldPassword.tintColor = DPAGColorProvider.shared[.textFieldText]
        passwordViewControllerComplex.textFieldPassword.attributedPlaceholder = NSAttributedString(string: DPAGLocalizedString("registration.label.passwordSecLevel.placeholder"), attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
    }
    
    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                if let pvc = self.passwordViewController as? DPAGComplexPasswordViewControllerProtocol {
                    pvc.textFieldPassword.textColor = DPAGColorProvider.shared[.textFieldText]
                    pvc.textFieldPassword.tintColor = DPAGColorProvider.shared[.textFieldText]
                }
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }
}

private class DPAGLoginViewControllerPIN: DPAGLoginViewControllerInput {
    init() {
        super.init(nibName: "DPAGLoginViewControllerPIN", bundle: Bundle(for: type(of: self)))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let passwordViewControllerPIN = DPAGApplicationFacadeUIBase.passwordPINVC(secLevelView: false)
        passwordViewControllerPIN.colorFillEmpty = DPAGColorProvider.shared[.passwordPINEmpty]
        passwordViewControllerPIN.colorFillFilled = DPAGColorProvider.shared[.passwordPIN]
        passwordViewControllerPIN.colorBorderFocused = DPAGColorProvider.shared[.passwordPIN]
        passwordViewControllerPIN.delegate = self
        passwordViewControllerPIN.willMove(toParent: self)
        self.addChild(passwordViewControllerPIN)
        self.passwordContainer.addSubview(passwordViewControllerPIN.view)
        passwordViewControllerPIN.didMove(toParent: self)
        passwordViewControllerPIN.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate(self.passwordContainer.constraintsFill(subview: passwordViewControllerPIN.view))
        self.passwordViewController = passwordViewControllerPIN
    }
    
    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                if let pvc = self.passwordViewController as? DPAGPINPasswordViewControllerProtocol {
                    pvc.colorFillEmpty = DPAGColorProvider.shared[.passwordPINEmpty]
                    pvc.colorFillFilled = DPAGColorProvider.shared[.passwordPIN]
                    pvc.colorBorderFocused = DPAGColorProvider.shared[.passwordPIN]
                }
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }
}
