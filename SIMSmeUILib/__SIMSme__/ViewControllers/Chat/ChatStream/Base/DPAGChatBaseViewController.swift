//
//  DPAGChatBaseViewController.swift
//  SIMSmeUILib
//
//  Created by Maxime Bentin on 16.09.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation
import SIMSmeCore

class DPAGChatBaseViewController: DPAGTableViewControllerChatStream, DPAGChatBaseViewControllerProtocol {
  var originalmediaSourceType: DPAGSendObjectMediaSourceType = .none
  private var inputContainer: UIView?
  var inputController: (UIViewController & DPAGChatStreamInputBaseViewControllerProtocol)?
  var inputVoiceController: (UIViewController & DPAGChatStreamInputVoiceViewControllerProtocol)?
  var showsInputController = true
  var sendOptionsEnabled = true
  weak var sendingDelegate: DPAGSendingDelegate?
  var draftTextMessage: String?
  var wasDeleted = false
  var isScrollTableViewToBottomAnimated = false
  var addAttachmentAlertHelper = AddAttachmentAlertHelper()
  
  deinit {
    DPAGSendMessageViewOptions.sharedInstance.reset()
    self.inputSendOptionsView?.reset()
    self.inputController?.sendOptionsContainerView?.removeFromSuperview()
  }
  
  weak var inputSendOptionsView: (UIView & DPAGChatStreamSendOptionsViewProtocol)?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.setupAddAttachmentHelper()
    self.view.backgroundColor = DPAGColorProvider.shared[.chatDetailsBackground]
    self.extendedLayoutIncludesOpaqueBars = true
    if self.showsInputController {
      self.initInputController()
    }
  }
  
  override func handleDesignColorsUpdated() {
    super.handleDesignColorsUpdated()
    self.view.backgroundColor = DPAGColorProvider.shared[.chatDetailsBackground]
    UINavigationBar.appearance().tintColor = DPAGColorProvider.shared[.navigationBarTint]
    UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: DPAGColorProvider.shared[.navigationBarTint]]
  }
  
  private func setupAddAttachmentHelper() {
    self.addAttachmentAlertHelper.viewController = self
    self.addAttachmentAlertHelper.documentPickerDelegate = self
    self.addAttachmentAlertHelper.contactSendingDelegate = self
    self.addAttachmentAlertHelper.personSendingDelegate = self
    self.addAttachmentAlertHelper.locationSendingDelegate = self
    self.addAttachmentAlertHelper.imagePickerDelegate = self
    self.addAttachmentAlertHelper.mediaPickerDelegate = self
  }
  
  public func initInputController() {
    let inputController = DPAGApplicationFacadeUI.inputVoiceVC()
    inputController.inputVoiceDelegate = self as? (DPAGChatStreamInputVoiceViewControllerDelegate & DPAGChatStreamSendOptionsContentViewDelegate)
    inputController.sendOptionsEnabled = self.sendOptionsEnabled
    self.inputController = inputController
    self.inputVoiceController = inputController
    self.addChild(inputController)
    inputController.view.translatesAutoresizingMaskIntoConstraints = false
    self.stackViewTableView?.addArrangedSubview(inputController.view)
    inputController.didMove(toParent: self)
    if let inputSendOptionsView = DPAGApplicationFacadeUI.viewChatStreamSendOptions() {
      self.inputSendOptionsView = inputSendOptionsView
      self.tableView.superview?.insertSubview(inputSendOptionsView, aboveSubview: self.tableView)
      inputSendOptionsView.translatesAutoresizingMaskIntoConstraints = false
      self.tableView.superview?.addConstraintsFill(subview: inputSendOptionsView)
      inputSendOptionsView.delegate = self
    }
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    if self.draftTextMessage != nil {
      self.inputController?.textView?.text = self.draftTextMessage
      self.draftTextMessage = nil
    }
    self.configureNavBar()
  }
  
  // Called on viewWillAppear
  func configureNavBar() {
    // Zurücksetzen der Anpassungen Dateiauswahl
    UINavigationBar.appearance().tintColor = DPAGColorProvider.shared[.navigationBarTint]
    UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: DPAGColorProvider.shared[.navigationBarTint]]
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    self.tableView.isEditing = false
  }
  
  func sendMessageResponseBlock() -> DPAGServiceResponseBlock {
    let responseBlock: DPAGServiceResponseBlock = { [weak self] _, _, errorMessage in
      if let strongSelf = self {
        if let errorMessage = errorMessage {
          if errorMessage == "service.ERR-0119" {
            strongSelf.performBlockOnMainThread {
              DPAGSimsMeController.sharedInstance.showPurchaseIfPossible()
            }
          } else {
            strongSelf.performBlockOnMainThread { [weak self] in
              self?.inputController?.textView?.resignFirstResponder()
            }
            strongSelf.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
          }
          strongSelf.handleMessageSendFailed(errorMessage)
        } else {
          strongSelf.handleMessageWasSent()
        }
      }
    }
    return responseBlock
  }
  
  func handleMessageWasSent() {}
  
  func handleMessageSendFailed(_: String?) {}
  
  func updateRecipientsConfidenceState() {
    if let recipients = (self as? DPAGSendingDelegate)?.getRecipients() {
      DPAGApplicationFacade.contactsWorker.updateRecipientsConfidenceState(recipients: recipients)
    }
  }
  
  // MARK: - Input delegate
  
  override func handleTableViewTapped() {
    if let textView = self.inputController?.textView, textView.isFirstResponder() {
      textView.resignFirstResponder()
    } else {
      self.inputController?.dismissSendOptionsView(animated: false)
    }
  }
  
  func inputContainerSizeSizeChangedWithDiff(_ diff: CGFloat) {
    if diff == 0 {
      return
    }
    let diffContentBefore = self.tableView.bounds.size.height - self.tableView.contentSize.height
    if diff > 0 {
      if diffContentBefore > 0 {
        self.tableView.setContentOffset(CGPoint(x: self.tableView.contentOffset.x, y: self.tableView.contentOffset.y + (diff - diffContentBefore)), animated: false)
      } else {
        self.tableView.setContentOffset(CGPoint(x: self.tableView.contentOffset.x, y: self.tableView.contentOffset.y + diff), animated: false)
      }
    } else if diff < 0 {
      self.tableView.setContentOffset(CGPoint(x: self.tableView.contentOffset.x, y: max(0, self.tableView.contentOffset.y + diff)), animated: false)
    }
  }
  
  func inputContainerMaxHeight() -> CGFloat {
    self.view.frame.size.height - self.tableView.contentInset.top
  }
  
  func inputContainerInitDraft() {}
  
  func inputContainerAddAttachment() {
    self.handleAddAttachment()
  }
  
  func inputContainerTextViewDidChange() {
    if (self.inputController?.textView?.text.isEmpty ?? true) == false || self.inputVoiceController?.audioData != nil {
      self.inputSendOptionsView?.show()
    }
  }
  
  func inputContainerTextPlaceholder() -> String? {
    nil
  }
  
  func inputContainerShowsAdditionalView(_: Bool) {}
  
  func inputContainerCitationCancel() {
    self.inputController?.sendOptionsEnabled = true
  }
  
  var inputContainerCitationEnabled: Bool { true }
  
  func inputContainerCanExecuteSendMessage() -> Bool {
    if let destructionConfig = self.inputController?.getSendOptions() {
      if let sendDate = destructionConfig.dateToBeSend, Date().compare(sendDate) == .orderedDescending {
        self.presentErrorAlert(alertConfig: AlertConfigError(titleIdentifier: "attention", messageIdentifier: "chat.message.sendDateBeforeNow"))
        return false
      } else if let destructionDate = destructionConfig.dateSelfDestruction, destructionConfig.countDownSelfDestruction == nil {
        if Date().compare(destructionDate) == .orderedDescending {
          self.presentErrorAlert(alertConfig: AlertConfigError(titleIdentifier: "attention", messageIdentifier: "chat.message.selfDestructDateBeforeNow"))
          return false
        } else if let sendDate = destructionConfig.dateToBeSend, sendDate.compare(destructionDate) == .orderedDescending {
          self.presentErrorAlert(alertConfig: AlertConfigError(titleIdentifier: "attention", messageIdentifier: "chat.message.selfDestructDateBeforeSendDate"))
          return false
        }
      }
    }
    return true
  }
  
  func inputContainerCanExecuteVoiceRecStart() -> Bool {
    true
  }
  
  func inputContainerSendVoiceRec(_ data: Data) {
    self.sendVoiceRec(data, sendMessageOptions: self.inputController?.getSendOptions())
  }
  
  func inputContainerSendText(_ textToSend: String) {
    self.sendTextWithWorker(textToSend, sendMessageOptions: self.inputController?.getSendOptions())
  }
  
  func inputContainerSendMemoji(_ medias: [DPAGMediaResource], sendMessageOptions sendOptions: DPAGSendMessageSendOptions?) {
    let responseBlock = self.sendingDelegate?.sendMessageResponseBlock()
    DPAGChatHelper.sendMessageWithDelegate(self.sendingDelegate) { recipients in
      DPAGApplicationFacade.sendMessageWorker.sendMedias(medias, sendMessageOptions: sendOptions, toRecipients: recipients, response: responseBlock)
    }
  }
  
  func sendCallInvitation(room: String, password: String, server: String) {
    self.sendCallInvitationWithWorker(room: room, password: password, server: server, sendMessageOptions: self.inputController?.getSendOptions())
  }
  
  func sendAVCallAccepted(room: String, password: String, server: String) {
    self.sendAVCallAcceptedWithWorker(room: room, password: password, server: server, sendMessageOptions: self.inputController?.getSendOptions())
  }
  
  func sendAVCallRejected(room: String, password: String, server: String) {
    self.sendAVCallRejectedWithWorker(room: room, password: password, server: server, sendMessageOptions: self.inputController?.getSendOptions())
  }
  
  func isProximityMonitoringEnabled() -> Bool {
    DPAGApplicationFacade.preferences.proximityMonitoringEnabled
  }
  
  func nameForFileOpen() -> String {
    "noname"
  }
  
  func sendCallInvitationWithWorker(room: String, password: String, server: String, sendMessageOptions sendOptions: DPAGSendMessageSendOptions?) {
    let responseBlock = self.sendingDelegate?.sendMessageResponseBlock()
    DPAGChatHelper.sendMessageWithDelegate(self.sendingDelegate) { recipients in
      DPAGApplicationFacade.sendMessageWorker.sendCallInvite(room: room, password: password, server: server, toRecipients: recipients, sendMessageOptions: sendOptions, response: responseBlock)
    }
  }
  
  func sendAVCallAcceptedWithWorker(room: String, password: String, server: String, sendMessageOptions sendOptions: DPAGSendMessageSendOptions?) {
    let responseBlock = self.sendingDelegate?.sendMessageResponseBlock()
    DPAGChatHelper.sendMessageWithDelegate(self.sendingDelegate) { recipients in
      DPAGApplicationFacade.sendMessageWorker.sendAVCallAccepted(room: room, password: password, server: server, toRecipients: recipients, sendMessageOptions: sendOptions, response: responseBlock)
    }
  }
  
  func sendAVCallRejectedWithWorker(room: String, password: String, server: String, sendMessageOptions sendOptions: DPAGSendMessageSendOptions?) {
    let responseBlock = self.sendingDelegate?.sendMessageResponseBlock()
    DPAGChatHelper.sendMessageWithDelegate(self.sendingDelegate) { recipients in
      DPAGApplicationFacade.sendMessageWorker.sendAVCallRejected(room: room, password: password, server: server, toRecipients: recipients, sendMessageOptions: sendOptions, response: responseBlock)
    }
  }
  
  func sendTextWithWorker(_ text: String, sendMessageOptions sendOptions: DPAGSendMessageSendOptions?) {
    let responseBlock = self.sendingDelegate?.sendMessageResponseBlock()
    DPAGChatHelper.sendMessageWithDelegate(self.sendingDelegate) { recipients in
      DPAGApplicationFacade.sendMessageWorker.sendText(text, toRecipients: recipients, sendMessageOptions: sendOptions, response: responseBlock)
    }
  }
  
  func pushToSendImageViewController(imageResource: DPAGMediaResource, mediaSourceType: DPAGSendObjectMediaSourceType, navigationController: UINavigationController?, enableMultiSelection: Bool) {
    let sendImageViewController = DPAGApplicationFacadeUI.imageOrVideoSendVC(mediaSourceType: mediaSourceType, mediaResources: [imageResource], sendDelegate: self.sendingDelegate as? DPAGSendAVViewControllerDelegate ?? self, enableMultiSelection: enableMultiSelection)
    sendImageViewController.title = self.title
    sendImageViewController.draft = self.inputController?.textView?.text
    if navigationController == self.navigationController, let viewControllers = navigationController?.viewControllers {
      var viewControllersNew = [UIViewController]()
      for idx in 0 ..< viewControllers.count {
        viewControllersNew.append(viewControllers[idx])
        if viewControllers[idx] == self {
          break
        }
      }
      viewControllersNew.append(sendImageViewController)
      self.navigationController?.setViewControllers(viewControllersNew, animated: true)
      self.inputSendOptionsView?.reset()
      self.inputController?.sendOptionsContainerView?.removeFromSuperview()
      if AppConfig.isShareExtension == false {
        self.inputController?.dismissCitationView()
      }
    } else {
      navigationController?.dismiss(animated: true) { [weak self] in
        self?.navigationController?.pushViewController(sendImageViewController, animated: true)
        self?.inputSendOptionsView?.reset()
        self?.inputController?.sendOptionsContainerView?.removeFromSuperview()
        if AppConfig.isShareExtension == false {
          self?.inputController?.dismissCitationView()
        }
      }
    }
  }
  
  func pushToSendVideoViewController(videoResource: DPAGMediaResource, mediaSourceType: DPAGSendObjectMediaSourceType, navigationController: UINavigationController?, enableMultiSelection: Bool) {
    let sendVideoController = DPAGApplicationFacadeUI.imageOrVideoSendVC(mediaSourceType: mediaSourceType, mediaResources: [videoResource], sendDelegate: self.sendingDelegate as? DPAGSendAVViewControllerDelegate ?? self, enableMultiSelection: enableMultiSelection)
    sendVideoController.title = self.title
    sendVideoController.draft = self.inputController?.textView?.text
    if navigationController == nil || navigationController == self.navigationController {
      self.navigationController?.pushViewController(sendVideoController, animated: true)
      self.inputSendOptionsView?.reset()
      self.inputController?.sendOptionsContainerView?.removeFromSuperview()
      if AppConfig.isShareExtension == false {
        self.inputController?.dismissCitationView()
      }
    } else {
      navigationController?.dismiss(animated: true) { [weak self] in
        self?.navigationController?.pushViewController(sendVideoController, animated: true)
        self?.inputSendOptionsView?.reset()
        self?.inputController?.sendOptionsContainerView?.removeFromSuperview()
        if AppConfig.isShareExtension == false {
          self?.inputController?.dismissCitationView()
        }
      }
    }
  }
}

extension DPAGChatBaseViewController: DPAGChatStreamSendOptionsViewDelegate {
  func sendOptionSelected(sendOption: DPAGChatStreamSendOptionsViewSendOption) {
    switch sendOption {
      case .closed, .hidden:
        break
      case .opened:
        break
      case .deactivated:
        self.inputSendOptionsView?.deactivate()
      case .highPriority:
        break
      case .selfDestruct:
        break
      case .sendTimed:
        break
    }
    
    self.inputController?.sendOptionSelected(sendOption: sendOption)
  }
}

extension DPAGChatBaseViewController: DPAGChatStreamSendOptionsContentViewDelegate {
  func sendOptionsChanged() {
    self.inputSendOptionsView?.updateButtonTextsWithSendOptions()
  }
}
