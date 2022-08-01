//
//  DPAGChatStreamBaseViewController.swift
// ginlo
//
//  Created by RBU on 11/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import AVFoundation
import CoreData
import Photos
import SIMSmeCore
import UIKit

class DPAGChatStreamBaseViewController: DPAGChatCellBaseViewController, NSFetchedResultsControllerDelegate, DPAGChatStreamInputVoiceViewControllerDelegate, DPAGChatStreamBaseViewControllerProtocol {
  private weak var backgroundViewCustomImage: UIImageView?
  var navigationSeparator: UIView?
  
  var cameFromChatList = true
  private var wroteMessage = false
  
  private var isFirstAppear = true
  var scrollToEnd = true
  // var newMessagesCount: Int = 0
  
  private var session: AVCaptureSession?
  private weak var videoView: UIView?
  
  var imgCache: [String: UIImage] = [:]
  var showMessageGuid: String?
  
  var timedMessagesCount = 0
  
  weak var navigationTitle: UILabel?
  weak var navigationProcessDescription: UILabel?
  weak var navigationProcessActivityIndicator: UIActivityIndicatorView?
  
  var navigationItemTitle: String?
  var navigationItemTitleView: UIView?
  var navigationItemButtonsNoEditRight: [UIBarButtonItem]?
  var avCallButton: UIBarButtonItem?
  
  var silentHelper = SetSilentHelper(chatType: .group)
  fileprivate var silentStateObservation: NSKeyValueObservation?
  
  lazy var fetchedResultsControllerMessages: DPAGFetchedResultsControllerChatStream = DPAGFetchedResultsControllerChatStream(streamGuid: self.streamGuid) { [weak self] changes, messages in
    guard let strongSelf = self, strongSelf.isViewLoaded else {
      self?.messages = messages
      return
    }
    strongSelf.handleChangedTable(changes: changes, messages: messages)
  }
  
  private func handleChangedTable(changes: [DPAGFetchedResultsControllerChange], messages: [[DPAGDecryptedMessage]]) {
    var hasNewRows = false
    var hasDeletedRows = false
    var hasMovedRows = false
    var scrollToEnd = false
    for change in changes {
      if let changedRow = change as? DPAGFetchedResultsControllerRowChange {
        hasNewRows = hasNewRows || (changedRow.changeType == .insert)
        hasDeletedRows = hasDeletedRows || (changedRow.changeType == .delete)
        hasMovedRows = hasMovedRows || (changedRow.changeType == .move)
      } else if let changedSection = change as? DPAGFetchedResultsControllerSectionChange {
        hasNewRows = hasNewRows || (changedSection.changeType == .insert)
        hasDeletedRows = hasDeletedRows || (changedSection.changeType == .delete)
        hasMovedRows = hasMovedRows || (changedSection.changeType == .move)
      }
    }
    scrollToEnd = self.scrollToEnd || hasNewRows
    self.scrollToEnd = false
    if changes.isEmpty {
      self.tableView.isScrollEnabled = false
      self.tableView.isContentOffsetEnabled = false
      self.messages = messages
      self.tableView.reloadData()
      DispatchQueue.main.async { [weak self] in
        // animation has finished
        self?.tableView.isContentOffsetEnabled = true
        self?.tableView.isScrollEnabled = true
        if scrollToEnd {
          self?.scrollTableViewToBottomAnimated(true)
        }
      }
    } else {
      let changesWithoutReload = changes.filter { (change) -> Bool in
        change.changeType != .update || (change is DPAGFetchedResultsControllerRowChange) == false
      }
      let changesReload = changes.filter { (change) -> Bool in
        (change is DPAGFetchedResultsControllerRowChange) && change.changeType == .update
      }
      if changesReload.isEmpty == false {
        self.messages = messages
        for change in changesReload {
          guard let changeRow = change as? DPAGFetchedResultsControllerRowChange else { continue }
          guard changeRow.changedIndexPath.section < messages.count else { continue }
          guard changeRow.changedIndexPath.row < messages[changeRow.changedIndexPath.section].count else { continue }
          let decMessage = messages[changeRow.changedIndexPath.section][changeRow.changedIndexPath.row]
          (self.tableView.cellForRow(at: changeRow.changedIndexPath) as? DPAGMessageCellProtocol)?.configureCellWithMessage(decMessage, forHeightMeasurement: false)
        }
      }
      if changesWithoutReload.isEmpty == false {
        self.tableView.isScrollEnabled = hasNewRows == false
        self.tableView.isContentOffsetEnabled = hasNewRows == false
        let block = {
          self.messages = messages
          for change in changes {
            if let changedRow = change as? DPAGFetchedResultsControllerRowChange {
              self.handleChangedTableRow(changedRow: changedRow)
            } else if let changedSection = change as? DPAGFetchedResultsControllerSectionChange {
              self.handleChangedTableSection(changedSection: changedSection)
            }
          }
        }
        self.tableView.performBatchUpdates(block) { [weak self] _ in
          self?.tableView.isContentOffsetEnabled = true
          self?.tableView.isScrollEnabled = true
          if scrollToEnd {
            self?.scrollTableViewToBottomAnimated(true)
          }
        }
      }
    }
    if hasNewRows {
      self.performBlockInBackground { [weak self] in
        self?.updateNewMessagesCountAndBadge()
      }
      let chatsListVC = DPAGSimsMeController.sharedInstance.chatsListViewController
      if chatsListVC.isViewLoaded, chatsListVC.tableView.numberOfSections > 0, chatsListVC.tableView.numberOfRows(inSection: 0) > 0 {
        chatsListVC.tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: false)
      }
    }
  }
  
  private func handleChangedTableRow(changedRow: DPAGFetchedResultsControllerRowChange) {
    switch changedRow.changeType {
      case .update:
        if let indexPathsForVisibleRows = self.tableView.indexPathsForVisibleRows, indexPathsForVisibleRows.contains(changedRow.changedIndexPath) {
          self.tableView.reloadRows(at: [changedRow.changedIndexPath], with: .none)
        }
      case .insert:
        self.tableView.insertRows(at: [changedRow.changedIndexPath], with: .none)
      case .delete:
        self.tableView.deleteRows(at: [changedRow.changedIndexPath], with: .automatic)
      case .move:
        if let changedIndexPathMovedTo = changedRow.changedIndexPathMovedTo {
          if changedIndexPathMovedTo == changedRow.changedIndexPath {
            self.tableView.reloadRows(at: [changedRow.changedIndexPath], with: .none)
          } else {
            self.tableView.deleteRows(at: [changedRow.changedIndexPath], with: .automatic)
            self.tableView.insertRows(at: [changedIndexPathMovedTo], with: .bottom)
          }
        }
      @unknown default:
        DPAGLog("Switch with unknown value: \(changedRow.changeType.rawValue)", level: .warning)
    }
  }
  
  private func handleChangedTableSection(changedSection: DPAGFetchedResultsControllerSectionChange) {
    switch changedSection.changeType {
      case .update:
        self.tableView.reloadSections(IndexSet(integer: changedSection.changedSection), with: .none)
      case .insert:
        self.tableView.insertSections(IndexSet(integer: changedSection.changedSection), with: .none)
      case .delete:
        self.tableView.deleteSections(IndexSet(integer: changedSection.changedSection), with: .automatic)
      case .move:
        break
      @unknown default:
        DPAGLog("Switch with unknown value: \(changedSection.changeType.rawValue)", level: .warning)
    }
  }
  
  var fetchedResultsController: DPAGFetchedResultsControllerChatStreamBase {
    self.fetchedResultsControllerMessages
  }
  
  lazy var fetchedResultsControllerTimedMessages: DPAGFetchedResultsControllerCounterTimedMessages = DPAGFetchedResultsControllerCounterTimedMessages(streamGuid: self.streamGuid) { [weak self] timedMessagesCount, _ in
    guard let strongSelf = self else { return }
    strongSelf.timedMessagesCount = timedMessagesCount
    strongSelf.updateRightBarButtonItems(timedMessagesCount: timedMessagesCount)
  }
  
  func updateRightBarButtonItems(timedMessagesCount: Int) {
    let barButtonItems = self.getAllRightBarButtonItems(timedMessagesCount: timedMessagesCount)
    if tableView.isEditing == false {
      navigationItem.rightBarButtonItems = barButtonItems
    } else {
      navigationItemButtonsNoEditRight = barButtonItems
    }
    labelTimedMessages?.text = timedMessagesCount > 0 ? "\(timedMessagesCount)" : nil
  }
  
  func shouldAddVoipButtons() -> Bool {
    AppConfig.isVoipActive && self.showsInputController
  }
  
  func getAllRightBarButtonItems(timedMessagesCount: Int) -> [UIBarButtonItem] {
    var result = [self.getRightBarButtonItem()]
    if timedMessagesCount > 0, wasDeleted == false, let barButtonMessagesToSend = barButtonMessagesToSend {
      result.append(barButtonMessagesToSend)
    }
    if shouldAddVoipButtons() && AVAudioSession.sharedInstance().isInputAvailable {
      result.append(self.prepareAVCallButton())
    }
    return result
  }
  
  private func prepareAVCallButton() -> UIBarButtonItem {
    let audioButton = UIBarButtonItem(image: DPAGImageProvider.shared[.kPhoneFill], style: .plain, target: self, action: #selector(initiateAVCall))
    audioButton.accessibilityIdentifier = "chat.start.call.audio"
    self.avCallButton = audioButton
    return audioButton
  }
  
  func getRightBarButtonItem() -> UIBarButtonItem {
    self.rightBarButtonItem ?? UIBarButtonItem(customView: UIView(frame: CGRect(origin: .zero, size: DPAGImageProvider.kSizeBarButton)))
  }
  
  var fileToSend: URL?
  var mediaToSend: DPAGMediaResource?
  
  private var showData = true
  var messages: [[DPAGDecryptedMessage]] = []
  private var updateViewSema = DispatchSemaphore(value: 1)
  private var updateViewSema2 = DispatchSemaphore(value: 1)
  var isAtEndOfScreen: Bool = false
  var reloadOnAppear: Bool = false
  private var shouldScrollToBottom = true
  
  private static let soundIdMessageSent: SystemSoundID? = {
    // Do not play a sound in the simulator
    // This is known to cause leaks and exceptions
    if AppConfig.isSimulator {
      return nil
    } else {
      if let urlSoundMessageSent = Bundle(for: DPAGChatStreamBaseViewController.self).url(forResource: "send_sound", withExtension: "mp3", subdirectory: nil) {
        var soundID: SystemSoundID = 0
        if AudioServicesCreateSystemSoundID(urlSoundMessageSent as CFURL, &soundID) == noErr {
          return soundID
        }
      }
      return nil
    }
  }()
  
  override init(streamGuid: String, streamState: DPAGChatStreamState) {
    super.init(streamGuid: streamGuid, streamState: streamState)
    DPAGLog("Conversation init")
    self.initViewController()
    self.silentHelper.chatIdentifier = streamGuid
  }
  
  func initViewController() {
    DPAGSendMessageViewOptions.sharedInstance.messageGuidCitation = nil
  }
  
  deinit {
    // AudioServicesDisposeSystemSoundID(DPAGChatStreamBaseViewController.soundIdMessageSent)
    self.silentStateObservation?.invalidate()
    DPAGLog("Conversation deinit: Freeing Locks")
    let timeUp = DispatchTime.now() + Double(Int64(1 * NSEC_PER_SEC)) / Double(NSEC_PER_SEC)
    if self.updateViewSema.wait(timeout: timeUp) != .success {
      DPAGLog("Timed Out Free Update Semaphore")
    }
    self.updateViewSema.signal()
    if self.updateViewSema2.wait(timeout: timeUp) != .success {
      DPAGLog("Timed Out Free Update Semaphore")
    }
    self.updateViewSema2.signal()
  }
  
  func createModel() {
    self.messages = self.fetchedResultsController.load()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    self.removeActivityIndicator()
    if DPAGApplicationFacadeUI.newMessageNotifier.isReceivingInitialMessagesProcessRunning {
      self.receivingMessagesStarted(nil)
    }
    self.registerForNewMessageNotification()
    if DPAGApplicationFacade.preferences.cameraBackgroundEnabled {
      self.setUpInvisibleScreen()
    }
    if self.reloadOnAppear {
      self.reloadOnAppear = false
      self.tableView.reloadData()
    }
    // Wenn die App aus dem Hintergrund neu vorgeholt wird, kann der Cache noch leer sein ...
    if DPAGApplicationFacade.cache.decryptedStream(streamGuid: self.streamGuid) == nil {
      _ = DPAGApplicationFacade.cache.decryptedStream(streamGuid: self.streamGuid, in: nil)
    }
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    self.performBlockInBackground { [weak self] in
      self?.updateNewMessagesCountAndBadge()
    }
    if (self.inputController?.inputDisabled ?? true) == false {
      if let fileToSend = self.fileToSend {
        var sendFile = true
        let fileExtension = fileToSend.pathExtension
        if let contentMimeType = DPAGHelper.mimeType(forExtension: fileExtension) {
          if DPAGHelperEx.isVideoContentMimeType(contentMimeType) {
            let asset = AVURLAsset(url: fileToSend)
            if CMTimeGetSeconds(asset.duration) > DPAGApplicationFacade.preferences.maxLengthForSentVideos {
              self.editVideo(mediaURL: fileToSend)
              sendFile = false
            } else if asset.isPlayable {
              if DPAGApplicationFacade.preferences.alreadyAskedForMic == false {
                DPAGApplicationFacade.preferences.alreadyAskedForMic = true
              }
              let mediaResource = DPAGMediaResource(type: .video)
              mediaResource.mediaUrl = fileToSend
              self.pushToSendVideoViewController(videoResource: mediaResource, mediaSourceType: .file, navigationController: self.navigationController, enableMultiSelection: false)
              sendFile = false
            }
          } else if DPAGHelperEx.isImageContentMimeType(contentMimeType) {
            let mediaResource = DPAGMediaResource(type: .image)
            mediaResource.mediaUrl = fileToSend
            self.pushToSendImageViewController(imageResource: mediaResource, mediaSourceType: .file, navigationController: self.navigationController, enableMultiSelection: false)
            sendFile = false
          }
        }
        if sendFile, DPAGSendAVViewController.checkFileSize(fileToSend, showAlertVC: self, cleanUpFile: true) != nil {
          let sendOptions = DPAGSendMessageSendOptions(countDownSelfDestruction: nil, dateSelfDestruction: nil, dateToBeSend: nil, messagePriorityHigh: false)
          sendOptions.attachmentIsInternalCopy = false
          self.sendFileWithWorker(fileToSend, sendMessageOptions: sendOptions)
        }
        self.fileToSend = nil
      } else if let mediaToSend = self.mediaToSend {
        var message = DPAGLocalizedString("chat.message.fileOpen.willSendTo.message")
        let persons = DPAGApplicationFacade.cache.decryptedStream(streamGuid: self.streamGuid)?.name ?? "noname"
        var fileSize = ""
        if let fileSizeStr = mediaToSend.additionalData?.fileSize, let fileSizeNum = Int64(fileSizeStr) {
          fileSize = DPAGFormatter.fileSize.string(fromByteCount: fileSizeNum)
        } else if let fileSizeNum = mediaToSend.additionalData?.fileSizeNum {
          fileSize = DPAGFormatter.fileSize.string(fromByteCount: fileSizeNum.int64Value)
        }
        message = String(format: message, mediaToSend.additionalData?.fileName ?? "noname", fileSize, persons)
        let actionCancel = UIAlertAction(titleIdentifier: "res.cancel", style: .cancel, handler: { [weak self] _ in
          self?.mediaToSend = nil
          
        })
        let actionOK = UIAlertAction(titleIdentifier: "res.ok", style: .default, handler: { [weak self] _ in
          if let strongSelf = self, let mediaToSend = strongSelf.mediaToSend {
            let sendOptions = DPAGSendMessageSendOptions(countDownSelfDestruction: nil, dateSelfDestruction: nil, dateToBeSend: nil, messagePriorityHigh: false)
            sendOptions.attachmentIsInternalCopy = false
            strongSelf.sendMediaWithWorker(mediaToSend, sendMessageOptions: sendOptions)
            strongSelf.mediaToSend = nil
          }
        })
        self.presentAlert(alertConfig: AlertConfig(titleIdentifier: "chat.message.fileOpen.willSendTo.title", messageIdentifier: message, cancelButtonAction: actionCancel, otherButtonActions: [actionOK]))
      }
    }
    if let messageGuidToScrollTo = self.showMessageGuid {
      self.showMessageGuid = nil
      if let indexPath = self.indexPathForMessage(messageGuidToScrollTo) {
        if self.tableView.cellForRow(at: indexPath) != nil {
          self.scrollingAnimationCompletionBlock(for: indexPath)()
        } else {
          self.scrollingAnimationCompletion = self.scrollingAnimationCompletionBlock(for: indexPath)
        }
        self.tableView.scrollToRow(at: indexPath, at: UITableView.ScrollPosition.none, animated: true)
      }
    } else if self.shouldScrollToBottom {
      self.shouldScrollToBottom = false
      DispatchQueue.main.async { [weak self] in
        self?.tableView.isContentOffsetEnabled = true
        self?.tableView.isScrollEnabled = true
        self?.scrollTableViewToBottomAnimated(false)
      }
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.setupSilentHelper()
  }
  
  func setupSilentHelper() {
    self.silentStateObservation = self.silentHelper.observe(\.silentStateChange, options: [.new]) { [weak self] _, _ in
      self?.onSilentStateChanged()
    }
  }
  
  func onSilentStateChanged() {
    // Does nothing in superclass
  }
  
  func addConfidenceView() {
    guard self.navigationSeparator == nil else { return }
    let navigationSeparator = UIView()
    self.view.addSubview(navigationSeparator)
    navigationSeparator.backgroundColor = UIColor.clear
    navigationSeparator.isOpaque = true
    navigationSeparator.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([navigationSeparator.constraintHeight(4)])
    self.stackViewTableView?.insertArrangedSubview(navigationSeparator, at: 0)
    self.extendedLayoutIncludesOpaqueBars = false
    self.navigationSeparator = navigationSeparator
  }
  
  override func appWillResignActive() {
    if (self.inputController?.inputDisabled ?? true) == false {
      let streamGuid = self.streamGuid
      let draft = self.inputController?.textView?.text ?? ""
      self.performBlockInBackground {
        DPAGApplicationFacade.contactsWorker.saveDraft(draft: draft, forStream: streamGuid)
      }
    }
    if let navigationController = self.presentedViewController as? UINavigationController, navigationController.topViewController is DPAGMediaDetailViewControllerProtocol {
      self.dismiss(animated: false) {}
    }
    // Wegen Frage zur Diktierfunktion kann Tastatur hier nicht weggeschaltet werden
    // self.inputController?.textView?.resignFirstResponder()
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    let streamGuid = self.streamGuid
    let draft = self.inputController?.textView?.text ?? ""
    if (self.inputController?.inputDisabled ?? true) == false {
      self.performBlockInBackground {
        DPAGApplicationFacade.contactsWorker.saveDraft(draft: draft, forStream: streamGuid)
      }
    }
    self.unregisterForNewMessageNotification()
    if let session = self.session, session.isRunning {
      session.stopRunning()
      self.videoView?.removeFromSuperview()
    }
    self.cameFromChatList = false
    DPAGProgressHUD.sharedInstance.hide(true)
  }
  
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    self.inputController?.textView?.resignFirstResponder()
  }
  
  func setup() {
    self.setChatBackground()
  }
  
  override func indexPathForMessage(_ messageGuid: String) -> IndexPath? {
    for i in 0 ..< self.messages.count {
      for j in 0 ..< self.messages[i].count {
        let msg = self.messages[i][j]
        if messageGuid == msg.messageGuid {
          return IndexPath(row: j, section: i)
        }
      }
    }
    return nil
  }
  
  var labelTimedMessages: DPAGLabelBadge?
  var barButtonMessagesToSend: UIBarButtonItem?
  var barButtonCancelEdit: UIBarButtonItem?
  
  @objc
  func showMessagesToSend() {
    if self.streamGuid.hasPrefix(.group) || self.streamGuid.hasPrefix(.streamGroup) {
      let nextVC = DPAGApplicationFacadeUI.chatGroupTimedMessagesStreamVC(streamGuid: self.streamGuid, streamState: .readOnly)
      nextVC.createModel()
      self.navigationController?.pushViewController(nextVC, animated: true)
    } else {
      let nextVC = DPAGApplicationFacadeUI.chatTimedMessagesStreamVC(streamGuid: self.streamGuid, streamState: .readOnly)
      nextVC.createModel()
      self.navigationController?.pushViewController(nextVC, animated: true)
    }
  }
  
  // Called on viewWillAppear
  override func configureNavBar() {
    super.configureNavBar()
    let actInd = UIActivityIndicatorView(style: .white)
    let labelTitle = UILabel()
    let labelDesc = UILabel()
    self.navigationProcessActivityIndicator = actInd
    self.navigationProcessDescription = labelDesc
    self.navigationTitle = labelTitle
    let barButton = self.rightBarButtonItem ?? UIBarButtonItem(customView: UIView(frame: CGRect(origin: .zero, size: DPAGImageProvider.kSizeBarButton)))
    self.navigationItem.titleView = self.configureActivityIndicatorNavigationBarViewWithTitleLabel(labelTitle, descLabel: labelDesc, activityIndicator: actInd)
    let btn = DPAGButtonExtendedHitArea(type: .custom)
    btn.setImage(DPAGImageProvider.shared[.kImageChatSendTimed], for: .normal)
    btn.tintColor = DPAGColorProvider.shared[.buttonDestructiveTintNoBackground]
    btn.imageView?.contentMode = .scaleAspectFit
    btn.addTarget(self, action: #selector(showMessagesToSend), for: .touchUpInside)
    let labelTimedMessages = DPAGLabelBadge(frame: CGRect(x: 0, y: 0, width: DPAGConstantsGlobal.kBadgeSize, height: DPAGConstantsGlobal.kBadgeSize))
    btn.addSubview(labelTimedMessages)
    self.labelTimedMessages = labelTimedMessages
    labelTimedMessages.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      btn.constraintTrailing(subview: labelTimedMessages, padding: -7),
      btn.constraintBottom(subview: labelTimedMessages, padding: -3)
    ])
    labelTimedMessages.backgroundColor = DPAGColorProvider.shared[.alertDestructiveBackground]
    labelTimedMessages.textColor = DPAGColorProvider.shared[.alertDestructiveTint]
    btn.frame = CGRect(x: 0, y: 0, width: 40, height: 30)
    let barBtnToSend = UIBarButtonItem(customView: btn)
    barBtnToSend.accessibilityIdentifier = "barButtonMessagesToSend"
    self.barButtonMessagesToSend = barBtnToSend
    self.navigationItem.rightBarButtonItems = [barButton]
    self.barButtonCancelEdit = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelEdit))
    self.fetchedResultsControllerTimedMessages.load()
  }
  
  override
  func handleDesignColorsUpdated() {
    super.handleDesignColorsUpdated()
    self.labelTimedMessages?.backgroundColor = DPAGColorProvider.shared[.alertDestructiveBackground]
    self.labelTimedMessages?.textColor = DPAGColorProvider.shared[.alertDestructiveTint]
    if let rightBarButtonItems = self.navigationItem.rightBarButtonItems {
      for item in rightBarButtonItems {
        item.tintColor = DPAGColorProvider.shared[.buttonDestructiveTintNoBackground]
      }
    }
    setChatBackground()
  }
  
  var rightBarButtonItem: UIBarButtonItem?
  
  func setChatBackground() {
    if DPAGApplicationFacade.preferences.cameraBackgroundEnabled {
      return
    }
    var customBackgroundImage: UIImage?
    var customBackgroundImageLS: UIImage?
    if let imagePath = UserDefaults.standard.object(forKey: DPAGStrings.SIMS_CHAT_BACKGROUND_IMAGE_PATH) as? String {
      customBackgroundImage = DPAGUIHelper.backgroundImage(imagePath: imagePath)
    }
    if let imagePathLS = UserDefaults.standard.object(forKey: DPAGStrings.SIMS_CHAT_BACKGROUND_IMAGE_PATH_LS) as? String {
      customBackgroundImageLS = DPAGUIHelper.backgroundImage(imagePath: imagePathLS)
    }
    if customBackgroundImage != nil {
      if self.backgroundViewCustomImage == nil {
        let backgroundViewCustomImage = UIImageView(frame: self.view.bounds)
        self.view.insertSubview(backgroundViewCustomImage, at: 0)
        self.backgroundViewCustomImage = backgroundViewCustomImage
        self.backgroundViewCustomImage?.contentMode = .scaleAspectFill
        self.backgroundViewCustomImage?.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        self.backgroundViewCustomImage?.backgroundColor = .clear
        self.backgroundViewCustomImage?.clipsToBounds = true
      }
      self.tableView.backgroundColor = .clear
      if customBackgroundImageLS != nil {
        let isPortrait = self.view.frame.height > self.view.frame.width
        if isPortrait {
          self.backgroundViewCustomImage?.image = customBackgroundImage
        } else {
          self.backgroundViewCustomImage?.image = customBackgroundImageLS
        }
      } else {
        self.backgroundViewCustomImage?.image = customBackgroundImage
      }
    } else {
      self.view.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
    }
  }
  
  func setUpInvisibleScreen() {
    guard let device = AVCaptureDevice.default(for: .video) else { return }
    let session = AVCaptureSession()
    session.sessionPreset = AVCaptureSession.Preset.medium
    self.session = session
    let captureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
    let rectWindow = UIScreen.main.bounds
    let maxSize = max(rectWindow.size.width, rectWindow.size.height)
    captureVideoPreviewLayer.frame = CGRect(x: 0, y: 0, width: maxSize, height: maxSize)
    captureVideoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
    let viewBackground = UIView()
    viewBackground.frame = CGRect(x: 0, y: 0, width: maxSize, height: maxSize)
    viewBackground.autoresizingMask = UIView.AutoresizingMask()
    viewBackground.layer.addSublayer(captureVideoPreviewLayer)
    self.tableView.backgroundView = viewBackground
    do {
      let input = try AVCaptureDeviceInput(device: device)
      if session.canAddInput(input) == false {
        DPAGLog("Can't setup an invisible screen. Reason: The AV input can't be added to the session.")
        self.videoView = nil
      } else {
        session.addInput(input)
        session.startRunning()
        self.videoView = viewBackground
      }
    } catch let error as NSError {
      DPAGLog("Can't setup an invisible screen. Reason: %@", error.localizedDescription)
      self.videoView = nil
    }
    let orientation = AppConfig.statusBarOrientation()
    self.updateVideoToOrientation(orientation)
  }
  
  override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    coordinator.animate(alongsideTransition: { [weak self] _ in
      guard let strongSelf = self else { return }
      let orientation = AppConfig.statusBarOrientation()
      strongSelf.updateVideoToOrientation(orientation)
      strongSelf.updateCustomBackgroundToOrientation(orientation)
      if strongSelf.isAtEndOfScreen {
        strongSelf.scrollTableViewToBottomAnimated(false)
      }
    }, completion: nil)
    if size.width > size.height {
      switch DPAGSendMessageViewOptions.sharedInstance.sendOptionsViewMode {
        case .selfDestructCountDown, .sendTime, .selfDestructDate:
          self.inputController?.textView?.becomeFirstResponder()
        case .highPriority, .unknown:
          break
      }
    }
  }
  
  func updateCustomBackgroundToOrientation(_ io: UIInterfaceOrientation) {
    if self.backgroundViewCustomImage == nil {
      return
    }
    guard let imagePathLS = UserDefaults.standard.object(forKey: DPAGStrings.SIMS_CHAT_BACKGROUND_IMAGE_PATH_LS) as? String else { return }
    if let imagePath = io.isPortrait ? UserDefaults.standard.object(forKey: DPAGStrings.SIMS_CHAT_BACKGROUND_IMAGE_PATH) as? String : imagePathLS {
      if let customBackgroundImage = DPAGUIHelper.backgroundImage(imagePath: imagePath) {
        self.backgroundViewCustomImage?.image = customBackgroundImage
      }
    }
  }
  
  func updateVideoToOrientation(_ io: UIInterfaceOrientation) {
    if self.videoView != nil {
      let myrect = self.view.frame
      let mypoint = CGPoint(x: myrect.origin.x + (myrect.size.width / 2), y: myrect.origin.y + (myrect.size.height / 2))
      self.videoView?.center = mypoint
      self.videoView?.autoresizingMask = UIView.AutoresizingMask()
      switch io {
        case .portrait:
          self.videoView?.transform = CGAffineTransform.identity
        case .portraitUpsideDown:
          self.videoView?.transform = CGAffineTransform(rotationAngle: CGFloat(Double.pi))
        case .landscapeLeft:
          self.videoView?.transform = CGAffineTransform(rotationAngle: CGFloat(Double.pi / 2))
        case .landscapeRight:
          self.videoView?.transform = CGAffineTransform(rotationAngle: -CGFloat(Double.pi / 2))
        default:
          break
      }
    }
  }
  
  override func decryptedMessageForIndexPath(_ indexPath: IndexPath, returnUnknownDecMessage: Bool = false) -> DPAGDecryptedMessage? {
    if indexPath.section >= self.messages.count {
      return nil
    }
    var sectionContent = self.messages[indexPath.section]
    if indexPath.row >= sectionContent.count {
      return nil
    }
    let decMessage = sectionContent[indexPath.row]
    guard decMessage.messageType == .unknown else { return decMessage }
    guard returnUnknownDecMessage == false else {
      // returning unknown decMessage on purpose
      return decMessage
    }
    guard decMessage.messageGuid.isEmpty == false else {
      return decMessage
    }
    guard let messageNew = DPAGApplicationFacade.cache.refreshDecryptedMessage(messageGuid: decMessage.messageGuid) else {
      return decMessage
    }
    sectionContent[indexPath.row] = messageNew
    self.messages[indexPath.section] = sectionContent
    return messageNew
  }
  
  override func handleMessageWasSent() {
    super.handleMessageWasSent()
    if DPAGApplicationFacade.preferences.skipPlayingSendAudio == false, let soundIdMessageSent = DPAGChatStreamBaseViewController.soundIdMessageSent {
      AudioServicesPlaySystemSound(soundIdMessageSent)
    }
  }
  
  func updateViewBeforeMessageWillSend() {
    if self.wroteMessage == false {
      self.wroteMessage = true
    }
    self.inputController?.updateViewBeforeMessageWillSend()
    self.inputSendOptionsView?.reset()
  }
  
  func updateViewAfterMessageWasSent() {
    self.inputController?.sendOptionsEnabled = true
    self.inputController?.updateViewAfterMessageWasSent()
  }
  
  func updateNewMessagesCountAndBadge() {}
  
  func updateNewMessagesCountAndBadge(_: Int) {
    DPAGApplicationFacade.messageWorker.markStreamMessagesAsRead(streamGuid: self.streamGuid)
    self.isFirstAppear = false
    DPAGApplicationFacade.messageWorker.createCachedMessages(forStream: self.streamGuid)
  }
  
  func registerForNewMessageNotification() {
    NotificationCenter.default.addObserver(self, selector: #selector(DPAGChatStreamBaseViewController.updateWithNewMessages), name: DPAGStrings.Notification.ContactsSync.FINISHED, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(DPAGChatStreamBaseViewController.receivingMessagesStarted(_:)), name: DPAGStrings.Notification.ReceivingNewMessages.STARTED, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(DPAGChatStreamBaseViewController.receivingMessagesFailed(_:)), name: DPAGStrings.Notification.ReceivingNewMessages.FAILED, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(DPAGChatStreamBaseViewController.receivingMessagesFinished(_:)), name: DPAGStrings.Notification.ReceivingNewMessages.FINISHED, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(DPAGChatStreamBaseViewController.receivedSignificantTimeChangeNotification(_:)), name: UIApplication.significantTimeChangeNotification, object: nil)
  }
  
  func unregisterForNewMessageNotification() {
    NotificationCenter.default.removeObserver(self, name: DPAGStrings.Notification.ContactsSync.FINISHED, object: nil)
    NotificationCenter.default.removeObserver(self, name: DPAGStrings.Notification.ReceivingNewMessages.STARTED, object: nil)
    NotificationCenter.default.removeObserver(self, name: DPAGStrings.Notification.ReceivingNewMessages.FAILED, object: nil)
    NotificationCenter.default.removeObserver(self, name: DPAGStrings.Notification.ReceivingNewMessages.FINISHED, object: nil)
    NotificationCenter.default.removeObserver(self, name: UIApplication.significantTimeChangeNotification, object: nil)
  }
  
  @objc
  func receivedSignificantTimeChangeNotification(_: Notification) {
    self.fetchedResultsControllerMessages.receivedSignificantTimeChangeNotification()
  }
  
  @objc
  func updateWithNewMessages() {
    self.performBlockOnMainThread { [weak self] in
      self?.tableView.reloadData()
    }
  }
  
  func addActivityIndicator(identifier: String) {
    self.performBlockOnMainThread { [weak self] in
      self?.navigationProcessDescription?.text = DPAGLocalizedString(identifier)
      self?.navigationProcessActivityIndicator?.startAnimating()
      self?.navigationTitle?.isHidden = true
    }
  }
  
  func removeActivityIndicator() {
    self.performBlockOnMainThread { [weak self] in
      self?.navigationProcessDescription?.text = ""
      self?.navigationProcessActivityIndicator?.stopAnimating()
      self?.navigationTitle?.isHidden = false
    }
  }
  
  @objc
  func receivingMessagesStarted(_: Notification?) {
    self.addActivityIndicator(identifier: "refresh.loading.label")
  }
  
  @objc
  func receivingMessagesFailed(_: Notification?) {
    self.removeActivityIndicator()
  }
  
  @objc
  func receivingMessagesFinished(_: Notification?) {
    self.performBlockOnMainThread { [weak self] in
      if DPAGApplicationFacadeUI.newMessageNotifier.isReceivingInitialMessagesProcessRunning == false {
        self?.removeActivityIndicator()
      }
    }
  }
  
  override var title: String? {
    didSet {
      self.performBlockOnMainThread {
        self.navigationItem.title = self.title
        self.navigationTitle?.text = self.title
      }
    }
  }
  
  override func inputContainerInitDraft() {
    super.inputContainerInitDraft()
    var initDraft = true
    if let text = self.inputController?.textView?.text {
      initDraft = text.isEmpty
    }
    if initDraft {
      self.inputController?.textView?.text = DPAGApplicationFacade.contactsWorker.loadDraft(forStream: self.streamGuid)
    }
  }
  
  func inputContainerIsVoiceEnabled() -> Bool {
    DPAGSendMessageViewOptions.sharedInstance.messageGuidCitation == nil
  }
  
  override func inputContainerSendVoiceRec(_ data: Data) {
    if !self.wroteMessage {
      self.wroteMessage = true
    }
    super.inputContainerSendVoiceRec(data)
  }
  
  override func inputContainerSendText(_ textToSend: String) {
    if !self.wroteMessage {
      self.wroteMessage = true
    }
    // Draft zuruecksetzen
    DPAGApplicationFacade.contactsWorker.resetDraft(forStream: self.streamGuid)
    super.inputContainerSendText(textToSend)
  }
  
  override func isProximityMonitoringEnabled() -> Bool {
    super.isProximityMonitoringEnabled() && (self.state != .readOnly) && (self.streamGuid.isSystemChatGuid == false)
  }
  
  override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    super.scrollViewWillBeginDragging(scrollView)
    self.scrollToEnd = false
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    if self.scrollToEnd, self.isFirstAppear {
      self.scrollTableViewToBottomAnimated(false)
    }
  }
  
  // MARK: - table view overrides
  
  override func titleForSection(_ section: Int) -> String? {
    self.fetchedResultsController.sectionNameforSection(section)
  }
  
  @objc
  func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
    self.titleForSection(section)
  }
  
  @objc
  func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
    var retVal: Int = 0
    tryC {
      retVal = self.messages[section].count
    }
    .catch { error in
      DPAGLog(error)
    }
    .finally {}
    return retVal
  }
  
  @objc(numberOfSectionsInTableView:)
  func numberOfSections(in _: UITableView) -> Int {
    if self.showData == false {
      DPAGLog("chatStream numberOfSections not showing data", level: .error)
      return 0
    }
    var retVal: Int = 0
    tryC {
      retVal = self.messages.count
    }
    .catch { error in
      DPAGLog(error)
    }
    .finally {}
    return retVal
  }
  
  @objc
  func initiateVideoCall() {
    self.initiateCall(isVideo: true)
  }
  
  @objc
  func initiateAudioCall() {
    self.initiateCall(isVideo: false)
  }
  
  @objc
  func initiateAVCall() {
    var options: [AlertOption]
    let startAudioOption = AlertOption(title: DPAGLocalizedString("chat.button.avcall.startAudioCall"), style: .default, image: DPAGImageProvider.shared[.kPhone], textAlignment: CATextLayerAlignmentMode.center, accesibilityIdentifier: "chat.button.audioCall.accessibility.label", handler: { [weak self] in
      guard let strongSelf = self else { return }
      strongSelf.initiateCall(isVideo: false)
    })
    let startVideoOption = AlertOption(title: DPAGLocalizedString("chat.button.avcall.startVideoCall"), style: .default, image: DPAGImageProvider.shared[.kVideo], textAlignment: CATextLayerAlignmentMode.center, accesibilityIdentifier: "chat.button.videoCall.accessibility.label", handler: { [weak self] in
      guard let strongSelf = self else { return }
      strongSelf.initiateCall(isVideo: true)
    })
    let rejectOption = AlertOption(title: DPAGLocalizedString("res.cancel"), style: .cancel, textAlignment: CATextLayerAlignmentMode.center)
    if AppConfig.isVoipVideoAllowed {
      options = [startAudioOption, startVideoOption, rejectOption]
    } else {
      options = [startAudioOption, rejectOption]
    }
    let alertController = UIAlertController.controller(options: options.compactMap { $0 }, titleKey: nil, withStyle: .actionSheet, accessibilityIdentifier: nil, barButtonItem: self.avCallButton)
    self.presentAlertController(alertController)
  }
  
  private func initiateCall(isVideo: Bool) {
    guard AppConfig.isVoipActive else { return }
    switch AVAudioSession.sharedInstance().recordPermission {
      case .granted:
        self.initiateCallWithAudioPermission(isVideo: isVideo)
      case .denied:
        self.presentMissingAudioPermissionForCall(isVideo: isVideo)
      case .undetermined:
        self.requestAudioPermissionForCall(isVideo: isVideo)
      @unknown default:
        self.requestAudioPermissionForCall(isVideo: isVideo)
    }
  }
  
  private func requestAudioPermissionForCall(isVideo: Bool) {
    AVAudioSession.sharedInstance().requestRecordPermission {
      if $0 == true {
        self.initiateCallWithAudioPermission(isVideo: isVideo)
      }
    }
  }
  
  private func presentMissingAudioPermissionForCall(isVideo: Bool) {
    let messageIdentifier: String
    if isVideo {
      messageIdentifier = "noMicrophoneVideoCallView.title.titleTextView"
    } else {
      messageIdentifier = "noMicrophoneAudioCallView.title.titleTextView"
    }
    let actionSettings = UIAlertAction(titleIdentifier: "noContactsView.alert.settings", style: .default, handler: { _ in
      if let url = URL(string: UIApplication.openSettingsURLString) {
        AppConfig.openURL(url)
      }
    })
    self.presentAlert(alertConfig: UIViewController.AlertConfig(messageIdentifier: messageIdentifier, cancelButtonAction: .cancelDefault, otherButtonActions: [actionSettings]))
  }
  
  private func initiateCallWithAudioPermission(isVideo: Bool) {
    showOutgoingCall(isVideo: isVideo)
  }
  
  private func getOwnAVUserInfo() -> String? {
    var avUserInfo: String = ""
    guard let account = DPAGApplicationFacade.cache.account else { return nil }
    let contact = DPAGApplicationFacade.cache.contact(for: account.guid)
    if let firstname = contact?.firstName, let lastname = contact?.lastName {
      avUserInfo = firstname + " " + lastname + " (\(contact?.accountID ?? ""))"
    } else if let nickname = contact?.nickName {
      avUserInfo = nickname + " (\(contact?.accountID ?? ""))"
    } else if let accountID = contact?.accountID {
      avUserInfo = accountID
    }
    return avUserInfo
  }
  
  private func showOutgoingCall(isVideo: Bool) {
    guard presentedViewController == nil else { return }
    let roomName = DPAGFunctionsGlobal.uuid()
    let roomPass = DPAGFunctionsGlobal.uuid()
    let vc = AVCallViewController(room: roomName, password: roomPass, server: "", localUser: getOwnAVUserInfo(), isVideo: isVideo, isOutgoingCall: true)
    vc.modalTransitionStyle = .crossDissolve
    vc.modalPresentationStyle = .fullScreen
    sendCallInvitation(room: roomName, password: roomPass, server: vc.defaultServer)
    present(vc, animated: true)
  }
}
