//
//  DPAGInitialPasswordRepeatViewController.swift
// ginlo
//
//  Created by RBU on 22/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGInitialPasswordRepeatViewController: DPAGInitialPasswordBaseViewController, GNInvitationUIViewController {
  override var labelHeadline: UILabel? {
    didSet {
      self.labelHeadline?.text = DPAGLocalizedString("registration.title.repeatPassword")
    }
  }
  
  override var labelDescription: UILabel? {
    didSet {
      self.labelDescription?.text = DPAGLocalizedString("registration.headline.enterPasswordAgain")
    }
  }
  
  override var viewButtonNext: DPAGButtonPrimaryView! {
    didSet {
      self.viewButtonNext.button.setTitle(DPAGLocalizedString("registration.buttonNextLabel.repeatPassword"), for: .normal)
    }
  }
  
  private var passwordEntered: String
  
  @IBOutlet private var switchPasswordType: UISwitch! {
    didSet {
      self.switchPasswordType.addTarget(self, action: #selector(handleToggleDisablePassword(_:)), for: .valueChanged)
      self.switchPasswordType.accessibilityIdentifier = "SwitchPasswortOnStartup"
    }
  }
  
  @IBOutlet private var stackViewAll: UIStackView!
  @IBOutlet private var stackViewSwitchPasswordType: UIStackView!
  
  var creationJob: GNInitialCreationType
  var invitationData: [String: Any]?
  
  init(password: String, initialPasswordJob: GNInitialCreationType) {
    // self.createDevice = createDevice
    self.creationJob = initialPasswordJob
    self.passwordEntered = password
    super.init(nibName: "DPAGInitialPasswordRepeatViewController", bundle: Bundle(for: type(of: self)))
  }
  
  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func configureView() {
    super.configureView()
    self.title = DPAGLocalizedString("settings.password")
    self.switchInputType?.isEnabled = false
    self.switchInputType?.isOn = DPAGApplicationFacade.preferences.passwordType == .pin
    self.setupInputTypeAnimated(false, secLevelView: false, withCompletion: nil)
    if DPAGApplicationFacade.preferences.canDisablePasswordLogin {
      self.switchPasswordType.isOn = false
    } else {
      self.switchPasswordType.isOn = true
      self.switchPasswordType.isEnabled = false
      self.stackViewSwitchPasswordType.isHidden = true
    }
    self.labelInputType?.text = DPAGLocalizedString("settings.password.disablePassword")
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    self.passwordViewController?.becomeFirstResponder()
  }
  
  @objc
  private func handleToggleDisablePassword(_: Any?) {
    if self.switchPasswordType.isOn == false {
      let actionNO = UIAlertAction(titleIdentifier: "registration.button.askForPassword.no", style: .cancel, handler: { [weak self] _ in
        guard let strongSelf = self else { return }
        strongSelf.switchPasswordType.setOn(true, animated: true)
      })
      let actionYES = UIAlertAction(titleIdentifier: "registration.button.askForPassword.yes", style: .destructive, handler: nil)
      self.presentAlert(alertConfig: AlertConfig(titleIdentifier: "registration.dontAskForPassword.alertTitle", messageIdentifier: "registration.dontAskForPassword.alert", cancelButtonAction: actionNO, otherButtonActions: [actionYES]))
    }
  }
  
  override func handleContinueTapped(_ sender: Any?) {
    self.dismissKeyboard(sender)
    guard let passwordCurrent = self.enteredPassword(), passwordCurrent.isEmpty == false else {
      self.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: "registration.validation.passwordCannotBeEmpty", okActionHandler: { [weak self] _ in
        self?.passwordViewController?.becomeFirstResponder()
      }))
      return
    }
    if self.passwordViewControllerPIN != nil, passwordCurrent.count < 4 {
      self.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: "registration.validation.pinIsTooShort", okActionHandler: { [weak self] _ in
        self?.passwordViewController?.becomeFirstResponder()
      }))
    } else if self.passwordEntered != passwordCurrent {
      self.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: "registration.validation.passwordDoesNotMatch", okActionHandler: { [weak self] _ in
        self?.passwordViewController?.becomeFirstResponder()
      }))
    } else {
      self.proceedToNextRegistrationStep()
    }
  }
  
  private func proceedToNextRegistrationStep() {
    self.dismissKeyboard(nil)
    if let password = self.enteredPassword() {
      switch self.creationJob {
        case .createDevice:
          let requestVC = DPAGApplicationFacadeUIRegistration.beforeCreateDeviceVC(password: password, enabled: self.switchPasswordType.isOn)
          self.navigationController?.pushViewController(requestVC, animated: true)
        case .createAccount:
          let requestVC = DPAGApplicationFacadeUIRegistration.beforeRegistrationVC(password: password, enabled: self.switchPasswordType.isOn)
          self.navigationController?.pushViewController(requestVC, animated: true)
        case .scanInvitation:
          let requestVC = DPAGApplicationFacadeUIRegistration.scanInvitationVC(blockSuccess: { [weak self] (text: String) in
            if let strongSelf = self, let invitationData = DPAGApplicationFacade.contactsWorker.parseInvitationQRCode(invitationContent: text) {
              strongSelf.invitationData = invitationData
              let requestVC = DPAGApplicationFacadeUIRegistration.beforeInvitationRegistrationVC(password: password, enabled: strongSelf.switchPasswordType.isOn, invitationData: invitationData)
              strongSelf.navigationController?.visibleViewController?.navigationController?.pushViewController(requestVC, animated: true)
            }
          }, blockFailed: { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.navigationController?.popViewController(animated: true)
            strongSelf.presentErrorAlert(alertConfig: AlertConfigError(messageIdentifier: "contacts.error.verifyingContactByQRCodeFailed") { _ in
            })
          }, blockCancelled: { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.navigationController?.popViewController(animated: true)
          })
          self.navigationController?.pushViewController(requestVC, animated: true)
        case .executeInvitation:
          if let invitationData = self.invitationData {
            let requestVC = DPAGApplicationFacadeUIRegistration.beforeInvitationRegistrationVC(password: password, enabled: self.switchPasswordType.isOn, invitationData: invitationData)
            self.navigationController?.pushViewController(requestVC, animated: true)
          }
      }
    }
  }
  
}
