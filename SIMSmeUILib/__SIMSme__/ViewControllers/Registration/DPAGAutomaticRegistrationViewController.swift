//
//  DPAGAutomaticRegistrationViewController.swift
//  SIMSmeUIRegistrationLib
//
//  Created by Yves Hetzer on 31.07.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

enum DPAGAutomaticRegistrationStates: Int {
    case createAccount,
        createDomainIndexEntry,
        waitCompanyKey,
        loadMdmConfig,
        loadCompanyIndex,
        loadDomainIndex,
        setProfile,
        done

    static let allCases = [createAccount,
                           createDomainIndexEntry,
                           waitCompanyKey,
                           loadMdmConfig,
                           loadCompanyIndex,
                           loadDomainIndex,
                           setProfile]
}

class DPAGAutomaticRegistrationViewController: DPAGViewControllerBackground {
    @IBOutlet private var stepStackView: UIStackView!

    @IBOutlet private var btnNextView: DPAGButtonPrimaryView! {
        didSet {
            self.btnNextView.button.accessibilityIdentifier = "btnContinue"
            self.btnNextView.button.setTitle(DPAGLocalizedString("res.continue"), for: .normal)
            self.btnNextView.button.addTarget(self, action: #selector(handleContinue), for: .touchUpInside)
        }
    }

    private var password: String
    private var enabledPassword = false

    private var errorOccured: Bool = false
    private var currentStep: DPAGAutomaticRegistrationStates = .createAccount

    private var registrationSteps: [DPAGAutomaticRegistrationStepViewProtocol] = []

    private let registrationValues: DPAGAutomaticRegistrationPreferences

    private weak var viewCompanyIndexStep: (UIView & DPAGAutomaticRegistrationStepViewProtocol)?
    private weak var viewDomainIndexStep: (UIView & DPAGAutomaticRegistrationStepViewProtocol)?

    init(registrationValues: DPAGAutomaticRegistrationPreferences) {
        self.registrationValues = registrationValues

        self.password = (try? CryptoHelperGenerator.createTicketTan()) ?? "0123456789ABCDEF"
        self.enabledPassword = false

        super.init(nibName: "DPAGAutomaticRegistrationViewController", bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: true)
        self.setNeedsStatusBarAppearanceUpdate()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        for i in DPAGAutomaticRegistrationStates.allCases {
            guard let v = DPAGApplicationFacadeUIRegistration.viewDPAGAutomaticRegistrationStep() else {
                return
            }
            switch i {
            case .createAccount:
                v.setDescription(DPAGLocalizedString("registration.automaticRegistration.createAccount.label"))
            case .createDomainIndexEntry:
                v.setDescription(DPAGLocalizedString("registration.automaticRegistration.createDomainIndexEntry.label"))
            case .waitCompanyKey:
                v.setDescription(DPAGLocalizedString("registration.automaticRegistration.waitCompanyKey.label"))
            case .loadMdmConfig:
                v.setDescription(DPAGLocalizedString("registration.automaticRegistration.loadMdmConfig.label"))
            case .loadCompanyIndex:
                v.setDescription(DPAGLocalizedString("registration.automaticRegistration.loadCompanyIndex.label"))

                self.viewCompanyIndexStep = v
            case .loadDomainIndex:
                v.setDescription(DPAGLocalizedString("registration.automaticRegistration.loadDomainIndex.label"))

                self.viewDomainIndexStep = v
            case .setProfile:
                v.setDescription(DPAGLocalizedString("registration.automaticRegistration.setProfile.label"))
            case .done:
                // kann nicht passieren
                fatalError("Invalid State")
            }
            v.setState(.waiting)

            self.registrationSteps.append(v)
            self.stepStackView.addArrangedSubview(v)
        }

        // Do any additional setup after loading the view.
        self.performBlockInBackground { [weak self] in
            self?.registerAccount(.createAccount)
        }
    }

    @objc
    private func companyIndexSyncInfo(_ aNotification: Notification) {
        self.indexSyncInfo(aNotification, viewProgress: self.viewCompanyIndexStep)
    }

    @objc
    private func emailIndexSyncInfo(_ aNotification: Notification) {
        self.indexSyncInfo(aNotification, viewProgress: self.viewDomainIndexStep)
    }

    private func indexSyncInfo(_ aNotification: Notification, viewProgress: (UIView & DPAGAutomaticRegistrationStepViewProtocol)?) {
        if let syncInfoState = aNotification.userInfo?[DPAGStrings.Notification.CompanyAdressbookWorker.SyncInfoKeyState] as? DPAGCompanyAdressbookWorkerSyncInfoState {
            if let step = aNotification.userInfo?[DPAGStrings.Notification.CompanyAdressbookWorker.SyncInfoKeyProgressStep] as? Int, let stepMax = aNotification.userInfo?[DPAGStrings.Notification.CompanyAdressbookWorker.SyncInfoKeyProgressMax] as? Int {
                viewProgress?.setProgress(DPAGLocalizedString("companyAdressbook.syncInfo." + syncInfoState.rawValue) + " \(step)/\(stepMax)")
            } else {
                viewProgress?.setProgress(DPAGLocalizedString("companyAdressbook.syncInfo." + syncInfoState.rawValue))
            }
        }
    }

    func setStep(_ actStep: DPAGAutomaticRegistrationStates) {
        self.currentStep = actStep
        self.performBlockOnMainThread {
            for i in 0 ..< self.registrationSteps.count {
                if i < actStep.rawValue {
                    self.registrationSteps[i].setState(.done)
                } else if i == actStep.rawValue {
                    if self.errorOccured {
                        self.registrationSteps[i].setState(.error)
                    } else {
                        self.registrationSteps[i].setState(.processing)
                    }
                } else if i > actStep.rawValue {
                    self.registrationSteps[i].setState(.waiting)
                }
            }
        }
    }

    func handleServiceError(_ message: String) {
        self.errorOccured = true
        self.setStep(self.currentStep)
        let actionRetry = UIAlertAction(titleIdentifier: "registration.automaticRegistration.error.tryAgain", style: .default, handler: { _ in
            self.performBlockInBackground {
                self.errorOccured = false
                self.registerAccount(self.currentStep)
            }
        })
        let actionManual = UIAlertAction(titleIdentifier: "registration.automaticRegistration.error.tryManual", style: .default, handler: { _ in
            DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { [weak self] _ in
                DPAGApplicationFacade.accountManager.resetAccount()
                DPAGApplicationFacade.preferences.resetFirstRunAfterUpdate()
                if let domainName = Bundle.main.bundleIdentifier {
                    UserDefaults.standard.removePersistentDomain(forName: domainName)
                }
                DPAGApplicationFacade.reset()
                DPAGApplicationFacade.isResetingAccount = false
                DPAGProgressHUD.sharedInstance.hide(true) {
                    guard let strongSelf = self else { return }
                    let requestVC = DPAGApplicationFacadeUIRegistration.initialPasswordVC(createDevice: false)
                    let vcs = Array(strongSelf.navigationController?.viewControllers.dropLast() ?? [])
                    strongSelf.navigationController?.setViewControllers(vcs + [requestVC], animated: true)
                }
            }
        })
        self.performBlockOnMainThread {
            self.presentAlert(alertConfig: UIViewController.AlertConfig(titleIdentifier: "attention", messageIdentifier: message, otherButtonActions: [actionRetry, actionManual]))
        }
    }

    func doStep1() throws {
        self.setStep(.createAccount)
        try DPAGApplicationFacade.automaticRegistrationWorker.doStep1(registrationValues: self.registrationValues, password: self.password)
    }

    func doStep2() throws {
        self.setStep(.createDomainIndexEntry)
        try DPAGApplicationFacade.automaticRegistrationWorker.doStep2(registrationValues: self.registrationValues)
    }

    func doStep3() throws {
        self.setStep(.waitCompanyKey)
        try DPAGApplicationFacade.automaticRegistrationWorker.doStep3()
    }

    private var companyLayout: [AnyHashable: Any]?

    func doStep4() throws {
        self.setStep(.loadMdmConfig)
        self.companyLayout = try DPAGApplicationFacade.automaticRegistrationWorker.doStep4()
    }

    func doStep5() {
        self.setStep(.loadCompanyIndex)
        NotificationCenter.default.addObserver(self, selector: #selector(companyIndexSyncInfo(_:)), name: DPAGStrings.Notification.CompanyAdressbookWorker.SyncInfo, object: nil)
        DPAGApplicationFacade.automaticRegistrationWorker.doStep5()
        NotificationCenter.default.removeObserver(self, name: DPAGStrings.Notification.CompanyAdressbookWorker.SyncInfo, object: nil)
    }

    func doStep6() {
        self.setStep(.loadDomainIndex)
        NotificationCenter.default.addObserver(self, selector: #selector(emailIndexSyncInfo(_:)), name: DPAGStrings.Notification.CompanyAdressbookWorker.SyncInfo, object: nil)
        DPAGApplicationFacade.automaticRegistrationWorker.doStep6()
        NotificationCenter.default.removeObserver(self, name: DPAGStrings.Notification.CompanyAdressbookWorker.SyncInfo, object: nil)
    }

    func doStep7() throws {
        self.setStep(.setProfile)
        try DPAGApplicationFacade.automaticRegistrationWorker.doStep7(registrationValues: self.registrationValues)
    }

    func registerAccount(_ initialStep: DPAGAutomaticRegistrationStates) {
        self.performBlockOnMainThread {
            self.btnNextView.isEnabled = false
        }
        do {
            if initialStep.rawValue <= DPAGAutomaticRegistrationStates.createAccount.rawValue {
                try self.doStep1()
            }
            if initialStep.rawValue <= DPAGAutomaticRegistrationStates.createDomainIndexEntry.rawValue {
                try self.doStep2()
            }
            if initialStep.rawValue <= DPAGAutomaticRegistrationStates.waitCompanyKey.rawValue {
                try self.doStep3()
            }
            if initialStep.rawValue <= DPAGAutomaticRegistrationStates.loadMdmConfig.rawValue {
                try self.doStep4()
            }
            if initialStep.rawValue <= DPAGAutomaticRegistrationStates.loadCompanyIndex.rawValue {
                self.doStep5()
            }
            if initialStep.rawValue <= DPAGAutomaticRegistrationStates.loadDomainIndex.rawValue {
                self.doStep6()
            }
            if initialStep.rawValue <= DPAGAutomaticRegistrationStates.loadMdmConfig.rawValue {
                try self.doStep7()
            }
        } catch let DPAGErrorAutomaticRegistration.error(errorMessage) {
            self.handleServiceError(errorMessage)
            return
        } catch {
            self.handleServiceError(error.localizedDescription)
            return
        }
        DPAGApplicationFacade.preferences.didAskForCompanyEmail = true
        var forceSetPwd = true
        // generiertes Passwort auf Gültigkeit prüfen
        if DPAGApplicationFacade.preferences.hasPasswordMDMSettings() {
            DPAGApplicationFacadeUIBase.loginVC.mustChangePassword = true
        } else {
            // Wenn vom MDM erlaubt, dann TouchID und Start Ohne Passwort enablen
            if DPAGApplicationFacade.preferences.canSetTouchId {
                DPAGApplicationFacade.preferences.touchIDEnabled = true
                forceSetPwd = false
            }
            if DPAGApplicationFacade.preferences.canDisablePasswordLogin {
                DPAGApplicationFacade.preferences.passwordOnStartEnabled = false
                forceSetPwd = false
            }
            if forceSetPwd {
                DPAGApplicationFacadeUIBase.loginVC.mustChangePassword = true
            } else {
                DPAGApplicationFacade.preferences.hasSystemGeneratedPassword = true
            }
        }
        // Push mit vorschau enablen
        if DPAGApplicationFacade.preferences.isPushPreviewDisabled == false {
            DPAGApplicationFacade.preferences.previewPushNotification = true
        }
        DPAGApplicationFacade.preferences.didAskForPushPreview = true
        // Nickname
        DPAGApplicationFacade.preferences[.kNotificationNicknameEnabled] = DPAGPreferences.kValueNotificationEnabled
        self.setStep(.done)
        self.performBlockOnMainThread { [weak self] in
            guard let strongSelf = self else { return }
            if let companyLayout = strongSelf.companyLayout {
                DPAGApplicationFacade.preferences.setCompanyLayout(companyLayout)
                strongSelf.companyLayout = nil
            }
            strongSelf.btnNextView.isEnabled = true
            if forceSetPwd == false {
                DPAGUIHelper.setupAppAppearance()
                NotificationCenter.default.post(name: DPAGStrings.Notification.Application.DESIGN_COLORS_UPDATED, object: nil)
                strongSelf.navigationController?.setNavigationBarHidden(false, animated: true)
                strongSelf.setNeedsStatusBarAppearanceUpdate()
                let nextVC = DPAGApplicationFacadeUISettings.setPasswordVC()
                strongSelf.navigationController?.pushViewController(nextVC, animated: true)
            }
        }
    }

    @objc
    private func handleContinue(_: Any?) {
        DPAGUIHelper.setupAppAppearance()
        NotificationCenter.default.post(name: DPAGStrings.Notification.Application.DESIGN_COLORS_UPDATED, object: nil)
        NotificationCenter.default.post(name: DPAGStrings.Notification.Application.DESIGN_LOGO_UPDATED, object: nil)
        NotificationCenter.default.post(name: DPAGStrings.Notification.Application.DID_COMPLETE_LOGIN, object: nil)
        self.dismiss(animated: true, completion: nil)
    }
}
