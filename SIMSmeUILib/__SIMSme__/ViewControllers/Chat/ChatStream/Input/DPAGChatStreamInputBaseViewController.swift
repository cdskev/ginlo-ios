//
//  DPAGChatStreamInputViewController.swift
// ginlo
//
//  Created by RBU on 14/04/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import AFNetworking
import HPGrowingTextView
import SIMSmeCore
import UIKit

class DPAGChatStreamInputBaseViewController: UIViewController, DPAGChatStreamInputBaseViewControllerProtocol {
  lazy var viewSendOptionsNib = DPAGApplicationFacadeUI.viewChatStreamSendOptionsContent()
  
  @IBOutlet var inputTextContainer: DPAGStackViewContentView! {
    didSet {
      self.inputTextContainer.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
      self.inputTextContainer.tintColor = DPAGColorProvider.shared[.messageSendOptionsTint]
    }
  }
  
  @IBOutlet var inputSelectContentContainer: DPAGStackViewContentView! {
    didSet {}
  }
  
  @IBOutlet var btnSend: UIButton! {
    didSet {
      self.btnSend.accessibilityIdentifier = "btnSend"
      self.btnSend.setImage(DPAGImageProvider.shared[.kImageChatSend], for: .normal)
      self.btnSend.addTarget(self, action: #selector(handleSendMessage), for: .touchUpInside)
      self.btnSend.accessibilityLabel = DPAGLocalizedString("contacts.button.sendMessageToUser")
      self.btnSend.tintColor = DPAGColorProvider.shared[.buttonBackground]
      self.btnSend.backgroundColor = DPAGColorProvider.shared[.buttonTint]
      self.btnSend.layer.cornerRadius = 10
    }
  }
  
  @IBOutlet var btnAdd: UIButton? {
    didSet {
      self.btnAdd?.accessibilityIdentifier = "btnAdd"
      self.btnAdd?.accessibilityLabel = DPAGLocalizedString("chat.button.add.accessibility.label")
      self.btnAdd?.setImage(DPAGImageProvider.shared[.kImageChatAttachment]?.imageWithTintColor(DPAGColorProvider.shared[.labelText]), for: .normal)
      self.btnAdd?.addTarget(self, action: #selector(handleAddAttachment), for: .touchUpInside)
    }
  }
  
  @IBOutlet var textView: HPGrowingTextView? {
    didSet {
      self.textView?.accessibilityIdentifier = "textView"
      self.textView?.internalTextView?.accessibilityIdentifier = "textViewInternal"
      self.textView?.isScrollable = false
      self.textView?.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
      self.textView?.internalTextView?.textColor = DPAGColorProvider.shared[.textFieldText]
      self.textView?.minNumberOfLines = 1
      self.textView?.maxNumberOfLines = 6
      self.textView?.returnKeyType = .default
      self.textView?.font = UIFont.kFontCallout
      self.textView?.delegate = self
      self.textView?.internalTextView.scrollIndicatorInsets = UIEdgeInsets(top: 11, left: 0, bottom: 11, right: 0)
      self.textView?.internalTextView.textContainerInset = UIEdgeInsets(top: 11, left: 5, bottom: 11, right: 5)
      self.textView?.internalTextView.textContainer.lineFragmentPadding = 0
      self.textView?.minHeight = 44
      self.textView?.accessibilityLabel = DPAGLocalizedString("chats.destructionMessageCell.textType")
      self.textView?.internalTextView?.layer.borderWidth = 1.0
      self.textView?.internalTextView?.layer.cornerRadius = 8
      self.textView?.internalTextView?.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
      self.textView?.internalTextView?.layer.borderColor = DPAGColorProvider.shared[.textFieldBackground].cgColor
      self.textView?.internalTextView?.allowsEditingTextAttributes = true
      self.textView?.internalTextView?.font = UIFont.kFontCallout
      if AppConfig.isShareExtension {
        let preferences = DPAGApplicationFacadeShareExt.preferences
        if preferences.isWhiteLabelBuild {
          self.textView?.internalTextView.keyboardAppearance = .dark
        } else {
          self.textView?.internalTextView.keyboardAppearance = DPAGColorProvider.shared.darkMode ? .dark : .light
        }
      } else {
        let preferences = DPAGApplicationFacade.preferences
        if preferences.isWhiteLabelBuild {
          self.textView?.internalTextView.keyboardAppearance = .dark
        } else {
          self.textView?.internalTextView.keyboardAppearance = DPAGColorProvider.shared.darkMode ? .dark : .light
        }
      }
    }
  }
  
  @IBOutlet var textViewHeight: NSLayoutConstraint?
  @IBOutlet var viewSafeArea: UIView!
  @IBOutlet var viewKeyboard: UIView!
  @IBOutlet var viewKeyboardDummy: DPAGStackViewContentView! {
    didSet {
      self.viewKeyboardDummy.isHidden = true
    }
  }
  
  @IBOutlet var constraintKeyboardDummyHeight: NSLayoutConstraint?
  var sendOptionsContainerView: (UIView & DPAGChatStreamSendOptionsContentViewProtocol)?
  var keyboardDidHideCompletion: DPAGCompletion?
  var inputDisabled = false
  var active = true
  var sendOptionsVisible = false
  var isVoiceMediaLoaded = false
  var isKeyboardShown = false
  var autoHideSendOptions = true
  var sendOptionsEnabled = true
  weak var inputDelegate: (DPAGChatStreamInputBaseViewControllerDelegate & DPAGChatStreamSendOptionsContentViewDelegate)?
  var isTransitioningToSize = false
  var sendOptionsSet: Bool {
    ((DPAGSendMessageViewOptions.sharedInstance.sendTimeEnabled ?? false) || (DPAGSendMessageViewOptions.sharedInstance.selfDestructionEnabled ?? false))
  }
  
  weak var viewCitationContentContent: (UIView & DPAGChatStreamCitationViewProtocol)?
  @IBOutlet var viewCitationContent: DPAGStackViewContentView? {
    didSet {
      self.viewCitationContent?.isHidden = true
      if let viewCitationContentContent = DPAGApplicationFacadeUI.viewChatStreamCitationContent() {
        self.viewCitationContent?.addSubview(viewCitationContentContent)
        viewCitationContentContent.translatesAutoresizingMaskIntoConstraints = false
        self.viewCitationContent?.addConstraintsFill(subview: viewCitationContentContent)
        self.viewCitationContentContent = viewCitationContentContent
        self.viewCitationContentContent?.delegate = self
      }
    }
  }
  
  deinit {
    NotificationCenter.default.removeObserver(self)
  }
  
  override func didMove(toParent parent: UIViewController?) {
    super.didMove(toParent: parent)
    if parent == nil {
      self.inputDelegate = nil
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    self.configureGui()
    if AppConfig.isShareExtension == false {
      NotificationCenter.default.addObserver(self, selector: #selector(handleDesignColorsUpdated), name: DPAGStrings.Notification.Application.DESIGN_COLORS_UPDATED, object: nil)
    }
  }
  
  @objc
  func handleDesignColorsUpdated() {
    self.inputTextContainer.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
    self.inputTextContainer.tintColor = DPAGColorProvider.shared[.messageSendOptionsTint]
    self.viewSafeArea.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
    self.textView?.internalTextView?.textColor = DPAGColorProvider.shared[.textFieldText]
    self.textView?.internalTextView?.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
    self.textView?.internalTextView?.layer.borderColor = DPAGColorProvider.shared[.textFieldBackground].cgColor
    self.btnSend.tintColor = DPAGColorProvider.shared[.buttonBackground]
    self.btnSend.backgroundColor = DPAGColorProvider.shared[.buttonTint]
    self.btnAdd?.setImage(DPAGImageProvider.shared[.kImageChatAttachment]?.imageWithTintColor(DPAGColorProvider.shared[.labelText]), for: .normal)
  }
  
  override
  func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    if #available(iOS 13.0, *) {
      if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
        DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
        handleDesignColorsUpdated()
      }
    } else {
      DPAGColorProvider.shared.darkMode = false
    }
  }
  
  func configureGui() {
    self.handleDesignColorsUpdated()
    self.textView?.placeholder = self.inputDelegate?.inputContainerTextPlaceholder() ?? DPAGLocalizedString("chat.text.placeHolder")
    self.textView?.internalTextView?.allowsEditingTextAttributes = true
  }
  
  @objc
  func handleCitationCancel() {
    DPAGSendMessageViewOptions.sharedInstance.messageGuidCitation = nil
    self.inputDelegate?.inputContainerCitationCancel()
    self.updateSendOptionsContainerView(animated: true)
    self.viewCitationContent?.isHidden = true
    UIView.animate(withDuration: TimeInterval(UINavigationController.hideShowBarDuration), delay: 0, options: [.curveEaseInOut], animations: { [weak self] in
      guard let strongSelf = self else { return }
      strongSelf.viewCitationContent?.alpha = 0
      strongSelf.viewCitationContent?.superview?.layoutIfNeeded()
      
    }, completion: nil)
    self.updateButtonStates()
  }
  
  func updateSendButtonState() {
    var enabled = false
    if DPAGHelperEx.isNetworkReachable() {
      if self.textView?.internalTextView.textInputMode?.primaryLanguage != "dictation" {
        if self.btnAdd == nil || ((self.textView?.text?.isEmpty ?? true) == false) {
          enabled = true
        }
      }
    }
    self.btnSend.isEnabled = enabled
  }
  
  func updateAddButtonState() {
    if self.btnAdd != nil {
      let isDictation = (self.textView?.internalTextView.textInputMode?.primaryLanguage == "dictation")
      if AppConfig.isShareExtension {
        let preferences = DPAGApplicationFacadeShareExt.preferences
        self.btnAdd?.isEnabled = DPAGHelperEx.isNetworkReachable() && preferences.canSendMedia && isDictation == false
      } else {
        let preferences = DPAGApplicationFacade.preferences
        self.btnAdd?.isEnabled = DPAGHelperEx.isNetworkReachable() && preferences.canSendMedia && isDictation == false
      }
    }
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    self.addObserverForNotifications()
    self.updateButtonStates()
    self.textView?.isEditable = DPAGHelperEx.isNetworkReachable()
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    DispatchQueue.main.async { [weak self] in
      self?.checkSendOptionsContainerView()
    }
  }
  
  func updateButtonStates() {
    self.updateSendButtonState()
    self.updateAddButtonState()
  }
  
  func addObserverForNotifications() {
    NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardDidHide(_:)), name: UIResponder.keyboardDidHideNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(enterBackground(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(networkReachabilityStatusChanged(_:)), name: .AFNetworkingReachabilityDidChange, object: nil)
  }
  
  @objc
  func enterBackground(_: Notification) {
    if let textView = self.textView, textView.isFirstResponder() {
      textView.resignFirstResponder()
    } else if self.sendOptionsSet {
      self.dismissSendOptionsView(animated: false)
    }
  }
  
  func removeObserverForNotifications() {
    NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
    NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardDidHideNotification, object: nil)
    NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
    NotificationCenter.default.removeObserver(self, name: .AFNetworkingReachabilityDidChange, object: nil)
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
  }
  
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    if let textView = self.textView, textView.isFirstResponder() {
      textView.resignFirstResponder()
    } else if self.sendOptionsSet {
      self.dismissSendOptionsView(animated: animated, completion: {})
    }
    self.removeObserverForNotifications()
  }
  
  @discardableResult
  override func resignFirstResponder() -> Bool {
    let retVal = super.resignFirstResponder()
    if self.textView?.isFirstResponder() ?? false {
      return self.textView?.resignFirstResponder() ?? retVal
    }
    return retVal
  }
  
  @objc
  private func handleAddAttachment() {
    self.inputDelegate?.inputContainerAddAttachment()
  }
  
  @objc
  func handleSendMessage() {
    if (self.inputDelegate?.inputContainerCanExecuteSendMessage() ?? true) == false {
      return
    }
    self.executeSendTapped()
    self.afterSendMessageTapped()
  }
  
  func configureCitation(for decryptedMessage: DPAGDecryptedMessage) {
    self.viewCitationContentContent?.configureCitation(for: decryptedMessage)
  }
  
  func handleCommentMessage(for decryptedMessage: DPAGDecryptedMessage) {
    self.configureCitation(for: decryptedMessage)
    if let messageGuidCitation = DPAGSendMessageViewOptions.sharedInstance.messageGuidCitation {
      self.sendOptionsEnabled = false
      DPAGSendMessageViewOptions.sharedInstance.reset()
      self.sendOptionsContainerView?.reset()
      DPAGSendMessageViewOptions.sharedInstance.messageGuidCitation = messageGuidCitation
      self.updateButtonStates()
      self.textView?.becomeFirstResponder()
    }
  }
  
  func afterSendMessageTapped() {
    self.btnSend.alpha = 1
    self.viewCitationContent?.isHidden = true
    self.viewCitationContent?.alpha = 0
    self.viewCitationContent?.superview?.layoutIfNeeded()
    self.textView?.text = ""
    self.textView?.font = UIFont.kFontCallout
    self.textView?.internalTextView?.font = UIFont.kFontCallout
  }
  
  // MEMOJI: Retrieve the image here and send it as attachment
  func executeSendTapped() {
    if self.textView?.alpha != 0 {
      var memojiToSend: [Data] = []
      var textToSend: String?
      if let attributedTextToSend = self.textView?.internalTextView?.attributedText {
        attributedTextToSend.enumerateAttribute(NSAttributedString.Key.attachment, in: NSRange(location: 0, length: attributedTextToSend.length), options: [], using: {(value, range, _) -> Void in
          if value is NSTextAttachment {
            let attachment: NSTextAttachment? = (value as? NSTextAttachment)
            var image: UIImage?
            
            if (attachment?.image) != nil {
              image = attachment?.image
            } else {
              // swiftlint:disable force_unwrapping
              image = attachment?.image(forBounds: (attachment?.bounds)!, textContainer: nil, characterIndex: range.location)
            }
            
            guard let pasteImage = image else { return }
            guard let pngData = pasteImage.pngData() else { return }
            memojiToSend.append(pngData)
            let newString = NSMutableAttributedString(attributedString: attributedTextToSend)
            newString.replaceCharacters(in: range, with: "")
            self.textView?.internalTextView?.attributedText = newString
            return
          }
        })
      }
      if let ttoSend = self.textView?.text, ttoSend.count > 0 {
        textToSend = ttoSend
        self.textView?.text = ""
      }
      if memojiToSend.count > 0 {
        var mediaArray: [DPAGMediaResource] = []
        for memoji in memojiToSend {
          let newMedia = DPAGMediaResource(type: .image)
          newMedia.mediaContent = memoji
          newMedia.text = textToSend
          mediaArray.append(newMedia)
        }
        if mediaArray.count > 0 {
          self.inputDelegate?.inputContainerSendMemoji(mediaArray, sendMessageOptions: self.getSendOptions())
        }
      } else if let textToSend = textToSend {
        self.inputDelegate?.inputContainerSendText(textToSend)
      }
      let doFocusInput = (DPAGSendMessageViewOptions.sharedInstance.selfDestructionEnabled ?? false)
      if doFocusInput {
        self.textView?.becomeFirstResponder()
      }
    }
  }
  
  func updateViewBeforeMessageWillSend() {
    if let sendOptionsContainerView = self.sendOptionsContainerView {
      sendOptionsContainerView.reset()
    } else {
      DPAGSendMessageViewOptions.sharedInstance.reset()
    }
    self.updateButtonStates()
  }
  
  func updateViewAfterMessageWasSent() {
    self.textView?.text = nil
    if self.sendOptionsVisible || (self.viewCitationContent?.isHidden ?? true) == false {
      self.updateSendOptionsContainerView(animated: true)
    }
  }
  
  func updateInputState(_ inputDisabled: Bool, animated: Bool) {
    if self.inputDisabled == inputDisabled {
      if inputDisabled == false {
        self.inputDelegate?.inputContainerInitDraft()
        if (self.textView?.text?.isEmpty ?? true) == false {
          self.updateButtonStates()
        }
      }
      return
    }
    self.inputDisabled = inputDisabled
    let before = self.inputTextContainer.bounds.size.height
    let blockAnimated = { [weak self] in
      guard let strongSelf = self else { return }
      if inputDisabled {
        strongSelf.view.isHidden = true
        strongSelf.textView?.resignFirstResponder()
        strongSelf.textView?.internalTextView.isUserInteractionEnabled = false
      } else {
        strongSelf.view.isHidden = false
        strongSelf.textView?.internalTextView.isUserInteractionEnabled = true
      }
      strongSelf.view.superview?.layoutIfNeeded()
      strongSelf.inputDelegate?.inputContainerSizeSizeChangedWithDiff(strongSelf.inputTextContainer.bounds.size.height - before)
    }
    let blockCompletion = { [weak self] (_: Bool) in
      if let strongSelf = self {
        strongSelf.inputDelegate?.inputContainerSizeSizeChangedWithDiff(0)
        if inputDisabled == false {
          strongSelf.inputDelegate?.inputContainerInitDraft()
          if (strongSelf.textView?.text?.isEmpty ?? true) == false {
            strongSelf.updateButtonStates()
          }
        }
      }
    }
    if animated {
      UIView.animate(withDuration: TimeInterval(UINavigationController.hideShowBarDuration), animations: blockAnimated, completion: blockCompletion)
    } else {
      blockAnimated()
      blockCompletion(true)
    }
  }
  
  func getSendOptions() -> DPAGSendMessageSendOptions? {
    let retVal = DPAGSendMessageSendOptions(countDownSelfDestruction: DPAGSendMessageViewOptions.sharedInstance.countDownSelfDestruction, dateSelfDestruction: DPAGSendMessageViewOptions.sharedInstance.dateSelfDestruction, dateToBeSend: DPAGSendMessageViewOptions.sharedInstance.dateToBeSend, messagePriorityHigh: DPAGSendMessageViewOptions.sharedInstance.messagePriorityHigh)
    retVal.messageGuidCitation = DPAGSendMessageViewOptions.sharedInstance.messageGuidCitation
    if self.isVoiceMediaLoaded {
      retVal.attachmentIsInternalCopy = true
    }
    return retVal
  }
  
  @objc
  func networkReachabilityStatusChanged(_: Notification?) {
    if self.inputDisabled {
      return
    }
    self.updateButtonStates()
    if DPAGHelperEx.isNetworkReachable() {
      self.textView?.isEditable = true
    } else {
      self.textView?.isEditable = false
      self.textView?.resignFirstResponder()
    }
  }
  
  func handleSwitchHighPriority() {
    DPAGSendMessageViewOptions.sharedInstance.switchHighPriority()
  }
  
  func handleSwitchSelfDestruction() {
    DPAGSendMessageViewOptions.sharedInstance.switchSelfDestruction()
    if DPAGSendMessageViewOptions.sharedInstance.selfDestructionEnabled ?? false, DPAGSendMessageViewOptions.sharedInstance.sendOptionsViewMode == .unknown {
      if DPAGSendMessageViewOptions.sharedInstance.countDownSelfDestruction != nil {
        DPAGSendMessageViewOptions.sharedInstance.sendOptionsViewMode = .selfDestructCountDown
      } else if DPAGSendMessageViewOptions.sharedInstance.dateSelfDestruction != nil {
        DPAGSendMessageViewOptions.sharedInstance.sendOptionsViewMode = .selfDestructDate
      }
    }
    self.updateSendOptionsContainerView(animated: true)
  }
  
  func handleSwitchSendTimed() {
    DPAGSendMessageViewOptions.sharedInstance.switchSendTimed()
    if DPAGSendMessageViewOptions.sharedInstance.sendTimeEnabled ?? false, DPAGSendMessageViewOptions.sharedInstance.sendOptionsViewMode == .unknown {
      DPAGSendMessageViewOptions.sharedInstance.sendOptionsViewMode = .sendTime
    }
    self.updateSendOptionsContainerView(animated: true)
  }
  
  func dismissCitationView() {
    self.viewCitationContent?.isHidden = true
    self.viewCitationContent?.superview?.layoutIfNeeded()
  }
  
  func dismissSendOptionsView(animated: Bool) {
    self.dismissSendOptionsView(animated: animated, completion: nil)
  }
  
  func dismissSendOptionsView(animated: Bool, completion: DPAGCompletion?) {
    let before = self.inputSelectContentContainer.bounds.size.height
    if completion == nil {
      self.textView?.becomeFirstResponder()
    }
    let blockAnimation = { [weak self] in
      guard let strongSelf = self else { return }
      strongSelf.inputSelectContentContainer.isHidden = true
      strongSelf.inputSelectContentContainer.alpha = strongSelf.inputSelectContentContainer.isHidden ? 0 : 1
      strongSelf.inputSelectContentContainer.superview?.layoutIfNeeded()
      strongSelf.inputDelegate?.inputContainerSizeSizeChangedWithDiff(strongSelf.inputSelectContentContainer.bounds.size.height - before)
      strongSelf.inputDelegate?.inputContainerShowsAdditionalView(false)
    }
    let blockCompletion: (Bool) -> Void = { [weak self] _ in
      self?.sendOptionsVisible = false
      completion?()
    }
    if animated {
      UIView.animate(withDuration: TimeInterval(UINavigationController.hideShowBarDuration), delay: 0, options: [.beginFromCurrentState, .layoutSubviews, .curveEaseOut], animations: blockAnimation, completion: blockCompletion)
    } else {
      blockAnimation()
      blockCompletion(true)
    }
  }
  
  var viewSendOptionsNibInstance: (UIView & DPAGChatStreamSendOptionsContentViewProtocol)? {
    self.viewSendOptionsNib
  }
  
  func checkSendOptionsContainerView() {
    if self.sendOptionsContainerView == nil {
      guard let sendOptionsContainerView = self.viewSendOptionsNibInstance else { return }
      self.sendOptionsContainerView = sendOptionsContainerView
      sendOptionsContainerView.delegate = self
    }
    if let sendOptionsContainerView = self.sendOptionsContainerView, sendOptionsContainerView.superview == nil {
      sendOptionsContainerView.setup()
      sendOptionsContainerView.configure()
      self.inputSelectContentContainer.isHidden = true
      self.inputSelectContentContainer.alpha = self.inputSelectContentContainer.isHidden ? 0 : 1
      self.inputSelectContentContainer.removeConstraints(self.inputSelectContentContainer.constraints)
      self.inputSelectContentContainer.addSubview(sendOptionsContainerView)
      self.inputSelectContentContainer.addConstraintsFill(subview: sendOptionsContainerView)
      self.inputSelectContentContainer.superview?.layoutIfNeeded()
    }
  }
  
  func resetSendOptions() {
    if self.sendOptionsSet {
      DPAGSendMessageViewOptions.sharedInstance.reset()
      self.updateSendOptionsContainerView(animated: true)
    }
    self.isVoiceMediaLoaded = false
  }
  
  func updateSendOptionsContainerView(animated _: Bool) {
    self.inputDelegate?.inputContainerShowsAdditionalView(self.sendOptionsSet || self.isKeyboardShown)
    if self.sendOptionsSet {
      if self.textView?.isFirstResponder() ?? false {
        self.textView?.resignFirstResponder()
        return
      }
    } else {
      self.textView?.becomeFirstResponder()
      return
    }
    self.checkSendOptionsContainerView()
    if self.sendOptionsVisible == false {
      let before = self.inputSelectContentContainer.bounds.size.height
      UIView.animate(withDuration: TimeInterval(UINavigationController.hideShowBarDuration), delay: 0, options: [.curveEaseInOut], animations: { [weak self] in
        guard let strongSelf = self else { return }
        strongSelf.sendOptionsContainerView?.configure()
        strongSelf.sendOptionsContainerView?.layoutIfNeeded()
        strongSelf.inputSelectContentContainer.isHidden = false
        strongSelf.inputSelectContentContainer.alpha = strongSelf.inputSelectContentContainer.isHidden ? 0 : 1
        strongSelf.inputSelectContentContainer.superview?.layoutIfNeeded()
        strongSelf.viewSafeArea.backgroundColor = strongSelf.inputSelectContentContainer.isHidden ? DPAGColorProvider.shared[.defaultViewBackground] : DPAGColorProvider.shared[.keyboard]
        strongSelf.inputDelegate?.inputContainerSizeSizeChangedWithDiff(strongSelf.inputSelectContentContainer.bounds.size.height - before)
      }, completion: { [weak self] _ in
        self?.sendOptionsContainerView?.completeConfigure()
        self?.sendOptionsVisible = true
      })
    } else {
      UIView.animate(withDuration: TimeInterval(UINavigationController.hideShowBarDuration), delay: 0, options: [.curveEaseInOut], animations: { [weak self] in
        self?.sendOptionsContainerView?.configure()
        self?.sendOptionsContainerView?.layoutIfNeeded()
        
      }, completion: nil)
    }
  }
  
  override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    self.isTransitioningToSize = true
    coordinator.animate(alongsideTransition: { [weak self] _ in
      if let strongSelf = self {
        if strongSelf.sendOptionsSet {
          let maxHeightFrame = strongSelf.inputDelegate?.inputContainerMaxHeight() ?? strongSelf.view.frame.size.height
          let tvHeight = min(120, max(40, maxHeightFrame - (192 + 40 + 44 + 10)))
          strongSelf.textView?.maxHeight = Int32(tvHeight)
          strongSelf.textView?.refreshHeight()
        }
      }
    }, completion: { [weak self] _ in
      
      self?.isTransitioningToSize = false
    })
  }
}

// MARK: - UIKeyboard notification handling

extension DPAGChatStreamInputBaseViewController {
  @objc
  func handleKeyboardWillShow(_ aNotification: Notification) {
    if self.inputDisabled || self.active == false || self.navigationController?.topViewController != self.parent || (self.parent?.presentedViewController != nil && (self.parent?.presentedViewController?.isBeingDismissed ?? false) == false) {
      DPAGLog("skipping keyboard animation")
      return
    }
    let animationInfo = UIKeyboardAnimationInfo(aNotification: aNotification, view: self.view)
    let maxHeightFrame = self.inputDelegate?.inputContainerMaxHeight() ?? self.view.frame.size.height
    let tvHeight = min(120, max(40, maxHeightFrame - (animationInfo.keyboardRectEnd.size.height + 40 + 44 + 10)))
    if self.isKeyboardShown {
      self.constraintKeyboardDummyHeight?.constant = animationInfo.keyboardRectEnd.height - self.view.safeAreaInsets.bottom
      return
    }
    self.isKeyboardShown = true
    self.constraintKeyboardDummyHeight?.constant = animationInfo.keyboardRectEnd.height - self.view.safeAreaInsets.bottom
    let before = self.inputSelectContentContainer.superview?.bounds.size.height ?? 0
    if self.sendOptionsEnabled, self.sendOptionsSet, self.sendOptionsVisible {
      UIView.performWithoutAnimation {
        self.inputSelectContentContainer.isHidden = true
        self.inputSelectContentContainer.alpha = self.inputSelectContentContainer.isHidden ? 0 : 1
        self.viewKeyboardDummy.isHidden = false
        self.viewKeyboardDummy.alpha = 1
        self.viewKeyboard.backgroundColor = DPAGColorProvider.shared[.keyboard]
        self.textView?.maxHeight = Int32(tvHeight)
        self.textView?.refreshHeight()
        self.inputSelectContentContainer.superview?.layoutIfNeeded()
        self.inputDelegate?.inputContainerSizeSizeChangedWithDiff(self.inputSelectContentContainer.bounds.size.height - before)
        self.inputDelegate?.inputContainerShowsAdditionalView(true)
        self.sendOptionsVisible = false
        DPAGSendMessageViewOptions.sharedInstance.sendOptionsViewMode = .unknown
        (self.inputDelegate as? DPAGChatStreamSendOptionsViewDelegate)?.sendOptionSelected(sendOption: .deactivated)
      }
    } else {
      let block = {
        self.inputSelectContentContainer.isHidden = true
        self.inputSelectContentContainer.alpha = self.inputSelectContentContainer.isHidden ? 0 : 1
        self.sendOptionsVisible = false
        if self.inputDelegate?.inputContainerCitationEnabled ?? false {
          self.viewCitationContent?.isHidden = DPAGSendMessageViewOptions.sharedInstance.messageGuidCitation == nil
        }
        self.viewKeyboardDummy.isHidden = false
        self.viewKeyboardDummy.alpha = 1
        self.viewKeyboard.backgroundColor = DPAGColorProvider.shared[.keyboard]
      }
      if self.inputSelectContentContainer.isHidden {
        block()
      } else {
        UIView.performWithoutAnimation(block)
      }
      let blockAnimation = { [weak self] in
        guard let strongSelf = self else { return }
        strongSelf.textView?.maxHeight = Int32(tvHeight)
        strongSelf.textView?.refreshHeight()
        if strongSelf.inputDelegate?.inputContainerCitationEnabled ?? false {
          strongSelf.viewCitationContent?.alpha = DPAGSendMessageViewOptions.sharedInstance.messageGuidCitation == nil ? 0 : 1
          strongSelf.viewCitationContent?.superview?.layoutIfNeeded()
        }
        strongSelf.viewKeyboardDummy?.superview?.layoutIfNeeded()
        strongSelf.inputSelectContentContainer?.superview?.layoutIfNeeded()
        strongSelf.inputDelegate?.inputContainerSizeSizeChangedWithDiff(strongSelf.viewKeyboardDummy.bounds.size.height - before)
      }
      let blockCompletion = { [weak self] (_: Bool) in
        guard let strongSelf = self else { return }
        strongSelf.inputDelegate?.inputContainerShowsAdditionalView(true)
        if strongSelf.sendOptionsEnabled {
          DPAGSendMessageViewOptions.sharedInstance.sendOptionsViewMode = .unknown
          (strongSelf.inputDelegate as? DPAGChatStreamSendOptionsViewDelegate)?.sendOptionSelected(sendOption: .deactivated)
        }
      }
      if animationInfo.animationDuration == 0 {
        blockAnimation()
        blockCompletion(true)
      } else {
        UIView.animate(withDuration: animationInfo.animationDuration, delay: 0, options: UIView.AnimationOptions(curve: animationInfo.animationCurve).union(.beginFromCurrentState), animations: blockAnimation, completion: blockCompletion)
      }
    }
  }
  
  @objc
  func handleKeyboardWillHide(_ aNotification: Notification?) {
    if self.active == false {
      DPAGLog("skipping keyboard animation")
      return
    }
    let animationInfo = UIKeyboardAnimationInfo(aNotification: aNotification, view: self.view)
    if self.sendOptionsSet, DPAGSendMessageViewOptions.sharedInstance.sendOptionsViewMode != .unknown {
      UIView.performWithoutAnimation {
        self.checkSendOptionsContainerView()
        self.sendOptionsContainerView?.configure()
        if self.inputDelegate?.inputContainerCitationEnabled ?? false {
          self.viewCitationContent?.isHidden = DPAGSendMessageViewOptions.sharedInstance.messageGuidCitation == nil
          self.viewCitationContent?.alpha = DPAGSendMessageViewOptions.sharedInstance.messageGuidCitation == nil ? 0 : 1
        }
        self.inputSelectContentContainer.isHidden = DPAGSendMessageViewOptions.sharedInstance.sendOptionsViewMode == .unknown
        self.inputSelectContentContainer.alpha = self.inputSelectContentContainer.isHidden ? 0 : 1
        self.viewKeyboardDummy.isHidden = true
        self.viewKeyboardDummy.alpha = 0
        self.viewKeyboard.backgroundColor = .clear
        self.inputSelectContentContainer.superview?.layoutIfNeeded()
      }
    }
    let before = self.viewKeyboardDummy.bounds.size.height
    let blockAnimation = { [weak self] in
      if let strongSelf = self {
        strongSelf.viewKeyboardDummy.isHidden = true
        strongSelf.viewKeyboardDummy.alpha = 0
        strongSelf.viewKeyboard.backgroundColor = .clear
        strongSelf.viewKeyboardDummy.superview?.layoutIfNeeded()
        strongSelf.viewSafeArea.backgroundColor = strongSelf.inputSelectContentContainer.isHidden ? DPAGColorProvider.shared[.defaultViewBackground] : DPAGColorProvider.shared[.keyboard]
        strongSelf.inputDelegate?.inputContainerSizeSizeChangedWithDiff((strongSelf.inputSelectContentContainer.isHidden ? 0 : strongSelf.inputSelectContentContainer.bounds.height) - before)
      }
    }
    let blockCompletion = { [weak self] (_: Bool) in
      if let strongSelf = self {
        strongSelf.constraintKeyboardDummyHeight?.constant = 0
        if strongSelf.sendOptionsSet {
          strongSelf.sendOptionsVisible = DPAGSendMessageViewOptions.sharedInstance.sendOptionsViewMode != .unknown
          strongSelf.inputDelegate?.inputContainerShowsAdditionalView(strongSelf.sendOptionsVisible)
        } else {
          strongSelf.inputDelegate?.inputContainerShowsAdditionalView(false)
        }
        strongSelf.isKeyboardShown = false
      }
    }
    if animationInfo.animationDuration == 0 {
      blockAnimation()
      blockCompletion(true)
    } else {
      UIView.animate(withDuration: animationInfo.animationDuration, delay: 0, options: UIView.AnimationOptions(curve: animationInfo.animationCurve).union(.beginFromCurrentState), animations: blockAnimation, completion: blockCompletion)
    }
  }
  
  @objc
  func handleKeyboardDidHide(_: Notification?) {
    self.keyboardDidHideCompletion?()
    self.keyboardDidHideCompletion = nil
  }
}

extension DPAGChatStreamInputBaseViewController: DPAGChatStreamSendOptionsContentViewDelegate {
  func sendOptionsChanged() {
    self.inputDelegate?.sendOptionsChanged()
  }
}

extension DPAGChatStreamInputBaseViewController: HPGrowingTextViewDelegate {
  func growingTextView(_: HPGrowingTextView?, willChangeHeight heightFL: Float) {
    let height = CGFloat(heightFL)
    let diff = height - (self.textViewHeight?.constant ?? 0)
    self.textViewHeight?.constant = height
    self.inputTextContainer.setNeedsLayout()
    self.inputTextContainer.superview?.layoutIfNeeded()
    self.inputDelegate?.inputContainerSizeSizeChangedWithDiff(-diff)
  }
  
  func growingTextView(_ growingTextView: HPGrowingTextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
    if text == "\n" {
      if growingTextView.returnKeyType != .default {
        growingTextView.resignFirstResponder()
        return false
      }
    }
    return growingTextView.text != nil ? (growingTextView.text.count - range.length + text.count < 4_000) : true
  }
  
  func growingTextViewDidChange(_: HPGrowingTextView?) {
    self.updateButtonStates()
    self.inputDelegate?.inputContainerTextViewDidChange()
  }
}

extension DPAGChatStreamInputBaseViewController: DPAGChatStreamSendOptionsViewDelegate {
  func sendOptionSelected(sendOption: DPAGChatStreamSendOptionsViewSendOption) {
    switch sendOption {
      case .closed, .hidden:
        if DPAGSendMessageViewOptions.sharedInstance.selfDestructionEnabled ?? (DPAGSendMessageViewOptions.sharedInstance.sendTimeEnabled ?? false) {
          self.textView?.becomeFirstResponder()
        }
      case .opened, .deactivated:
        break
      case .highPriority:
        self.handleSwitchHighPriority()
      case .selfDestruct:
        self.handleSwitchSelfDestruction()
      case .sendTimed:
        self.handleSwitchSendTimed()
    }
  }
}
