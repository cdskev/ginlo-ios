//
//  DPAGChatCellBaseViewController.swift
//  SIMSmeUILib
//
//  Created by Maxime Bentin on 16.09.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import AVKit
import SIMSmeCore
import UIKit

protocol DPAGChatCellBaseViewControllerProtocol: DPAGChatBaseViewControllerProtocol {}

class DPAGChatCellBaseViewController: DPAGChatBaseViewController, DPAGDefaultTransitionerZoomingBase, AVAudioPlayerDelegate, DPAGMediaContentViewDelegate, DPAGChatCellBaseViewControllerProtocol, DPAGViewControllerOrientationFlexible {
    static let sectionHeaderHeight: CGFloat = 24
    var state: DPAGChatStreamState
    var isNewChatStreamWithUnconfirmedContact = false
    var visibleTableHeaders: Set<UIView> = Set()
    var scrollingAnimationCompletion: DPAGCompletion?
    weak var longPressCell: (UITableViewCell & DPAGMessageCellProtocol)?
    var messagesLoading: [String] = []
    var streamGuid: String
    var fileURLTemp: URL?
    var openInController: UIDocumentInteractionController?
    var openInControllerOpensApplication = false
    var shouldUsePreferredSizes = true
    static let SimpleMessageLeftCellIdentifier = "SimpleMessageLeftCell"
    static let SimpleMessageRightCellIdentifier = "SimpleMessageRightCell"
    static let ImageMessageLeftCellIdentifier = "ImageMessageLeftCell"
    static let ImageMessageRightCellIdentifier = "ImageMessageRightCell"
    static let VideoMessageLeftCellIdentifier = "VideoMessageLeftCell"
    static let VideoMessageRightCellIdentifier = "VideoMessageRightCell"
    static let LocationMessageLeftCellIdentifier = "LocationMessageLeftCell"
    static let LocationMessageRightCellIdentifier = "LocationMessageRightCell"
    static let ContactMessageLeftCellIdentifier = "ContactMessageLeftCell"
    static let ContactMessageRightCellIdentifier = "ContactMessageRightCell"
    static let DestructionMessageLeftCellIdentifier = "DestructionMessageLeftCell"
    static let SystemMessageCellIdentifier = "SystemMessageCell"
    static let VoiceMessageLeftCellIdentifier = "VoiceMessageLeftCell"
    static let VoiceMessageRightCellIdentifier = "VoiceMessageRightCell"
    static let FileMessageLeftCellIdentifier = "FileMessageLeftCell"
    static let FileMessageRightCellIdentifier = "FileMessageRightCell"

    lazy var sizingCellLeftFile: (UITableViewCell & DPAGFileMessageCellProtocol)? = { self.tableView.dequeueReusableCell(withIdentifier: DPAGChatStreamBaseViewController.FileMessageLeftCellIdentifier) as? (UITableViewCell & DPAGFileMessageCellProtocol)
    }()

    lazy var sizingCellRightFile: (UITableViewCell & DPAGFileMessageCellProtocol)? = { self.tableView.dequeueReusableCell(withIdentifier: DPAGChatStreamBaseViewController.FileMessageRightCellIdentifier) as? (UITableViewCell & DPAGFileMessageCellProtocol)
    }()

    lazy var sizingCellLeftVoice: (UITableViewCell & DPAGVoiceMessageCellProtocol)? = { self.tableView.dequeueReusableCell(withIdentifier: DPAGChatStreamBaseViewController.VoiceMessageLeftCellIdentifier) as? (UITableViewCell & DPAGVoiceMessageCellProtocol)
    }()

    lazy var sizingCellRightVoice: (UITableViewCell & DPAGVoiceMessageCellProtocol)? = { self.tableView.dequeueReusableCell(withIdentifier: DPAGChatStreamBaseViewController.VoiceMessageRightCellIdentifier) as? (UITableViewCell & DPAGVoiceMessageCellProtocol)
    }()

    lazy var sizingCellLeftContact: (UITableViewCell & DPAGContactMessageCellProtocol)? = { self.tableView.dequeueReusableCell(withIdentifier: DPAGChatStreamBaseViewController.ContactMessageLeftCellIdentifier) as? (UITableViewCell & DPAGContactMessageCellProtocol)
    }()

    lazy var sizingCellRightContact: (UITableViewCell & DPAGContactMessageCellProtocol)? = { self.tableView.dequeueReusableCell(withIdentifier: DPAGChatStreamBaseViewController.ContactMessageRightCellIdentifier) as? (UITableViewCell & DPAGContactMessageCellProtocol)
    }()

    lazy var sizingCellLeftVideo: (UITableViewCell & DPAGVideoMessageCellProtocol)? = { self.tableView.dequeueReusableCell(withIdentifier: DPAGChatStreamBaseViewController.VideoMessageLeftCellIdentifier) as? (UITableViewCell & DPAGVideoMessageCellProtocol)
    }()

    lazy var sizingCellRightVideo: (UITableViewCell & DPAGVideoMessageCellProtocol)? = { self.tableView.dequeueReusableCell(withIdentifier: DPAGChatStreamBaseViewController.VideoMessageRightCellIdentifier) as? (UITableViewCell & DPAGVideoMessageCellProtocol)
    }()

    lazy var sizingCellLeftLocation: (UITableViewCell & DPAGLocationMessageCellProtocol)? = { self.tableView.dequeueReusableCell(withIdentifier: DPAGChatStreamBaseViewController.LocationMessageLeftCellIdentifier) as? (UITableViewCell & DPAGLocationMessageCellProtocol)
    }()

    lazy var sizingCellRightLocation: (UITableViewCell & DPAGLocationMessageCellProtocol)? = { self.tableView.dequeueReusableCell(withIdentifier: DPAGChatStreamBaseViewController.LocationMessageRightCellIdentifier) as? (UITableViewCell & DPAGLocationMessageCellProtocol)
    }()

    lazy var sizingCellLeftImage: (UITableViewCell & DPAGImageMessageCellProtocol)? = { self.tableView.dequeueReusableCell(withIdentifier: DPAGChatStreamBaseViewController.ImageMessageLeftCellIdentifier) as? (UITableViewCell & DPAGImageMessageCellProtocol)
    }()

    lazy var sizingCellRightImage: (UITableViewCell & DPAGImageMessageCellProtocol)? = { self.tableView.dequeueReusableCell(withIdentifier: DPAGChatStreamBaseViewController.ImageMessageRightCellIdentifier) as? (UITableViewCell & DPAGImageMessageCellProtocol)
    }()

    lazy var sizingCellLeftDestruction: (UITableViewCell & DPAGDestructionMessageCellProtocol)? = { self.tableView.dequeueReusableCell(withIdentifier: DPAGChatStreamBaseViewController.DestructionMessageLeftCellIdentifier) as? (UITableViewCell & DPAGDestructionMessageCellProtocol)
    }()

    lazy var sizingCellLeftSimple: (UITableViewCell & DPAGSimpleMessageCellProtocol)? = { self.tableView.dequeueReusableCell(withIdentifier: DPAGChatStreamBaseViewController.SimpleMessageLeftCellIdentifier) as? (UITableViewCell & DPAGSimpleMessageCellProtocol)
    }()

    lazy var sizingCellRightSimple: (UITableViewCell & DPAGSimpleMessageCellProtocol)? = { self.tableView.dequeueReusableCell(withIdentifier: DPAGChatStreamBaseViewController.SimpleMessageRightCellIdentifier) as? (UITableViewCell & DPAGSimpleMessageCellProtocol)
    }()

    lazy var sizingCellSystem: (UITableViewCell & DPAGSystemMessageCellProtocol)? = { self.tableView.dequeueReusableCell(withIdentifier: DPAGChatStreamBaseViewController.SystemMessageCellIdentifier) as? (UITableViewCell & DPAGSystemMessageCellProtocol)
    }()

    init(streamGuid: String, streamState: DPAGChatStreamState) {
        self.state = streamState
        self.streamGuid = streamGuid
        super.init(style: .plain)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.inputController?.view.isHidden = (self.state != .write)
    }

    func nibForSimpleMessageLeft() -> UINib {
        DPAGApplicationFacadeUI.cellMessageSimpleLeftNib()
    }

    func nibForImageMessageLeft() -> UINib {
        DPAGApplicationFacadeUI.cellMessageImageLeftNib()
    }

    func nibForDestructionMessageLeft() -> UINib {
        DPAGApplicationFacadeUI.cellMessageDestructionLeftNib()
    }

    override func configureTableView() {
        super.configureTableView()
        self.tableView.register(self.nibForSimpleMessageLeft(), forCellReuseIdentifier: DPAGChatStreamBaseViewController.SimpleMessageLeftCellIdentifier)
        self.tableView.register(DPAGApplicationFacadeUI.cellMessageSimpleRightNib(), forCellReuseIdentifier: DPAGChatStreamBaseViewController.SimpleMessageRightCellIdentifier)
        self.tableView.register(self.nibForImageMessageLeft(), forCellReuseIdentifier: DPAGChatStreamBaseViewController.ImageMessageLeftCellIdentifier)
        self.tableView.register(DPAGApplicationFacadeUI.cellMessageImageRightNib(), forCellReuseIdentifier: DPAGChatStreamBaseViewController.ImageMessageRightCellIdentifier)
        self.tableView.register(DPAGApplicationFacadeUI.cellMessageVideoLeftNib(), forCellReuseIdentifier: DPAGChatStreamBaseViewController.VideoMessageLeftCellIdentifier)
        self.tableView.register(DPAGApplicationFacadeUI.cellMessageVideoRightNib(), forCellReuseIdentifier: DPAGChatStreamBaseViewController.VideoMessageRightCellIdentifier)
        self.tableView.register(DPAGApplicationFacadeUI.cellMessageLocationLeftNib(), forCellReuseIdentifier: DPAGChatStreamBaseViewController.LocationMessageLeftCellIdentifier)
        self.tableView.register(DPAGApplicationFacadeUI.cellMessageLocationRightNib(), forCellReuseIdentifier: DPAGChatStreamBaseViewController.LocationMessageRightCellIdentifier)
        self.tableView.register(DPAGApplicationFacadeUI.cellMessageContactLeftNib(), forCellReuseIdentifier: DPAGChatStreamBaseViewController.ContactMessageLeftCellIdentifier)
        self.tableView.register(DPAGApplicationFacadeUI.cellMessageContactRightNib(), forCellReuseIdentifier: DPAGChatStreamBaseViewController.ContactMessageRightCellIdentifier)
        self.tableView.register(self.nibForDestructionMessageLeft(), forCellReuseIdentifier: DPAGChatStreamBaseViewController.DestructionMessageLeftCellIdentifier)
        self.tableView.register(DPAGApplicationFacadeUI.cellMessageVoiceLeftNib(), forCellReuseIdentifier: DPAGChatStreamBaseViewController.VoiceMessageLeftCellIdentifier)
        self.tableView.register(DPAGApplicationFacadeUI.cellMessageVoiceRightNib(), forCellReuseIdentifier: DPAGChatStreamBaseViewController.VoiceMessageRightCellIdentifier)
        self.tableView.register(DPAGApplicationFacadeUI.cellMessageFileLeftNib(), forCellReuseIdentifier: DPAGChatStreamBaseViewController.FileMessageLeftCellIdentifier)
        self.tableView.register(DPAGApplicationFacadeUI.cellMessageFileRightNib(), forCellReuseIdentifier: DPAGChatStreamBaseViewController.FileMessageRightCellIdentifier)
        self.tableView.register(DPAGApplicationFacadeUI.cellMessageSystemNib(), forCellReuseIdentifier: DPAGChatStreamBaseViewController.SystemMessageCellIdentifier)
        self.tableView.separatorStyle = .none
        self.tableView.allowsMultipleSelectionDuringEditing = true
        self.tableView.register(DPAGApplicationFacadeUI.viewChatStreamSectionNib(), forHeaderFooterViewReuseIdentifier: "header")
        let headerView = UIView(frame: CGRect(origin: .zero, size: CGSize(width: self.view.frame.width, height: 16)))
        self.tableView.tableHeaderView = headerView
    }

    func tableView(_ tableView: UITableView, cellForSimpleTextMessage decMessage: DPAGDecryptedMessage, forIndexPath indexPath: IndexPath) -> UITableViewCell {
        let cell = self.tableView(tableView, createCellForSimpleTextMessage: decMessage, forIndexPath: indexPath)
        return cell
    }

    func tableView(_ tableView: UITableView, cellForSystemTextMessage _: DPAGDecryptedMessage, forIndexPath indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: DPAGChatStreamBaseViewController.SystemMessageCellIdentifier, for: indexPath)
        return cell
    }

    func tableView(_ tableView: UITableView, cellForVideoMessage decMessage: DPAGDecryptedMessage, forIndexPath indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: decMessage.isOwnMessage ? DPAGChatStreamBaseViewController.VideoMessageRightCellIdentifier : DPAGChatStreamBaseViewController.VideoMessageLeftCellIdentifier, for: indexPath)
        return cell
    }

    func tableView(_: UITableView, cellForVoiceRecMessage decMessage: DPAGDecryptedMessage, forIndexPath indexPath: IndexPath) -> UITableViewCell {
        let cell = self.tableView.dequeueReusableCell(withIdentifier: decMessage.isOwnMessage ? DPAGChatStreamBaseViewController.VoiceMessageRightCellIdentifier : DPAGChatStreamBaseViewController.VoiceMessageLeftCellIdentifier, for: indexPath)
        return cell
    }

    func cellForHeightForFileMessage(_ decMessage: DPAGDecryptedMessage) -> (UITableViewCell & DPAGMessageCellProtocol)? {
        decMessage.isOwnMessage ? sizingCellRightFile : sizingCellLeftFile
    }

    func cellForHeightForVoiceMessage(_ decMessage: DPAGDecryptedMessage) -> (UITableViewCell & DPAGMessageCellProtocol)? {
        decMessage.isOwnMessage ? sizingCellRightVoice : sizingCellLeftVoice
    }

    func cellForHeightForSystemMessage(_: DPAGDecryptedMessage) -> (UITableViewCell & DPAGMessageCellProtocol)? {
        self.sizingCellSystem
    }

    func cellForHeightForContactMessage(_ decMessage: DPAGDecryptedMessage) -> (UITableViewCell & DPAGMessageCellProtocol)? {
        decMessage.isOwnMessage ? sizingCellRightContact : sizingCellLeftContact
    }

    func cellForHeightForVideoMessage(_ decMessage: DPAGDecryptedMessage) -> (UITableViewCell & DPAGMessageCellProtocol)? {
        decMessage.isOwnMessage ? sizingCellRightVideo : sizingCellLeftVideo
    }

    func cellForHeightForLocationMessage(_ decMessage: DPAGDecryptedMessage) -> (UITableViewCell & DPAGMessageCellProtocol)? {
        decMessage.isOwnMessage ? sizingCellRightLocation : sizingCellLeftLocation
    }

    func createHeightCellForImageTextMessage(_ decMessage: DPAGDecryptedMessage) -> (UITableViewCell & DPAGMessageCellProtocol)? {
        decMessage.isOwnMessage ? sizingCellRightImage : sizingCellLeftImage
    }

    func cellForHeightForImageMessage(_ decMessage: DPAGDecryptedMessage) -> (UITableViewCell & DPAGMessageCellProtocol)? {
        self.createHeightCellForImageTextMessage(decMessage)
    }

    func cellForHeightForDestructiveMessage(_: DPAGDecryptedMessage) -> (UITableViewCell & DPAGMessageCellProtocol)? {
        sizingCellLeftDestruction
    }

    func createHeightCellForSimpleTextMessage(_ decMessage: DPAGDecryptedMessage) -> (UITableViewCell & DPAGMessageCellProtocol)? {
        decMessage.isOwnMessage ? sizingCellRightSimple : sizingCellLeftSimple
    }

    func cellForHeightForSimpleTextMessage(_ decMessage: DPAGDecryptedMessage) -> (UITableViewCell & DPAGMessageCellProtocol)? {
        self.createHeightCellForSimpleTextMessage(decMessage)
    }

    func scrollingAnimationCompletionBlock(for indexPath: IndexPath) -> DPAGCompletion {
        let retVal = { [weak self] in
            let cell = self?.tableView.cellForRow(at: indexPath)
            cell?.layer.cornerRadius = 26
            cell?.layer.masksToBounds = true
            UIView.animate(withDuration: TimeInterval(0.1), delay: 0, options: [.curveLinear, .allowUserInteraction], animations: { [weak cell] in
                cell?.backgroundColor = DPAGColorProvider.shared[.chatDetailsBubbleBackgroundShortSelection1]
            }, completion: { _ in
                UIView.animate(withDuration: TimeInterval(0.65), delay: 0, options: [.curveLinear, .allowUserInteraction], animations: { [weak cell] in
                    cell?.backgroundColor = DPAGColorProvider.shared[.chatDetailsBubbleBackgroundShortSelection2]
                }, completion: { _ in
                    UIView.animate(withDuration: TimeInterval(1), delay: 0, options: [.curveLinear, .allowUserInteraction], animations: { [weak cell] in
                        cell?.backgroundColor = UIColor.clear
                    }, completion: { [weak cell] _ in
                        cell?.layer.cornerRadius = 0
                    })
                })
            })
        }
        return retVal
    }

    func decryptedMessageForIndexPath(_: IndexPath, returnUnknownDecMessage _: Bool = false) -> DPAGDecryptedMessage? {
        nil
    }

    override var canBecomeFirstResponder: Bool {
        true
    }

    // MARK: - Menu controller

    func hasMessageInfo() -> Bool {
        true
    }

    func menuItemsForCell(_ cell: DPAGMessageCellProtocol) -> [UIMenuItem] {
        var retVal: [UIMenuItem] = []
        if DPAGApplicationFacade.preferences.isCommentingEnabled, cell.decryptedMessage.contentType != .oooStatusMessage, cell.decryptedMessage.contentType != .avCallInvitation, cell.decryptedMessage.isSelfDestructive == false, self.isEditingEnabled(), (cell.decryptedMessage is DPAGDecryptedMessageChannel) == false, (self.inputController?.inputDisabled ?? true) == false {
            retVal.append(UIMenuItem(title: DPAGLocalizedString("chat.message.action.comment"), action: #selector(commentSelectedCell)))
        }
        if cell.decryptedMessage.contentType == .avCallInvitation {
            retVal.append(UIMenuItem(title: DPAGLocalizedString("chat.message.action.rejoinAVCall"), action: #selector(rejoinAVCall)))
        }
        if cell.canPerformForward(), DPAGHelperEx.isNetworkReachable() {
            retVal.append(UIMenuItem(title: DPAGLocalizedString("chat.message.action.forward"), action: #selector(forwardSelectedCell)))
        }
        if cell.canPerformCopy(), !DPAGApplicationFacade.preferences.isCopyPasteDisabled {
            retVal.append(UIMenuItem(title: DPAGLocalizedString("chat.message.action.copy"), action: #selector(copySelectedCell)))
        }
        retVal.append(UIMenuItem(title: DPAGLocalizedString("chat.message.action.delete"), action: #selector(deleteSelectedCell)))
        if cell.decryptedMessage.isSystemGenerated == false {
            if let decryptedMessage = cell.decryptedMessage as? DPAGDecryptedMessageGroup {
                if decryptedMessage.isOwnMessage == false, decryptedMessage.contactReadOnly == false {
                    retVal.append(UIMenuItem(title: String(format: DPAGLocalizedString("chat.message.action.open_single_chat"), decryptedMessage.contactName ?? "Unknown"), action: #selector(openSingleChatForSelectedCell)))
                }
                if self.hasMessageInfo(), decryptedMessage.groupType != .restricted, decryptedMessage.recipients.count > 0 {
                    retVal.append(UIMenuItem(title: DPAGLocalizedString("chat.message.action.info"), action: #selector(infoSelectedCell)))
                }
            } else if let decryptedMessage = cell.decryptedMessage as? DPAGDecryptedMessagePrivate {
                if self.hasMessageInfo(), decryptedMessage.isSystemChat == false {
                    retVal.append(UIMenuItem(title: DPAGLocalizedString("chat.message.action.info"), action: #selector(infoSelectedCell)))
                }
            }
        }
        return retVal
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if sender is UIMenuController {
            return self.longPressCell?.canPerformAction(action, withSender: sender) ?? false
        }
        return super.canPerformAction(action, withSender: sender)
    }

    @objc
    func rejoinAVCall() {
        self.longPressCell?.rejoinAVCall()
    }

    @objc
    func copySelectedCell() {
        self.longPressCell?.copySelectedCell()
    }

    @objc
    func openSingleChatForSelectedCell() {
        self.longPressCell?.openSingleChatForSelectedCell()
    }

    @objc
    func deleteSelectedCell() {
        self.longPressCell?.deleteSelectedCell()
    }

    @objc
    func forwardSelectedCell() {
        self.longPressCell?.forwardSelectedCell()
    }

    @objc
    func commentSelectedCell() {
        self.longPressCell?.commentSelectedCell()
    }

    @objc
    func openLinkInSelectedCell() {
        if let longPressCell = self.longPressCell as? DPAGSimpleMessageCellProtocol {
            longPressCell.openLinkInSelectedCell()
        } else if let longPressCell = self.longPressCell as? DPAGImageMessageCellProtocol {
            longPressCell.openLinkInSelectedCell()
        }
    }

    @objc
    func copyLinkInSelectedCell() {
        if let longPressCell = self.longPressCell as? DPAGSimpleMessageCellProtocol {
            longPressCell.copyLinkInSelectedCell()
        } else if let longPressCell = self.longPressCell as? DPAGImageMessageCellProtocol {
            longPressCell.copyLinkInSelectedCell()
        }
    }

    @objc
    func infoSelectedCell() {
        self.longPressCell?.infoSelectedCell()
    }

    func openInfoForMessage(_: DPAGDecryptedMessage) {}

    func indexPathForMessage(_: String) -> IndexPath? {
        nil
    }

    func zoomingViewForNavigationTransitionInView(_ inView: UIView, mediaResource: DPAGMediaResource?) -> CGRect {
        if let attachment = mediaResource?.attachment, let idxPath = self.indexPathForMessage(attachment.messageGuid), let cell = self.tableView.cellForRow(at: idxPath) as? DPAGChatStreamCell, let view = cell.zoomingViewForNavigationTransition() {
            if cell is DPAGTextMessageWithImagePreviewCellProtocol, let imageView = view as? UIImageView, let image = imageView.image {
                return inView.convert(AVMakeRect(aspectRatio: image.size, insideRect: imageView.bounds), from: imageView)
            }
            return inView.convert(view.frame, from: view.superview)
        }
        return .null
    }

    func deleteAttachment(_ decryptedAttachment: DPAGDecryptedAttachment) {
        // Delete message
        self.deleteChatStreamMessage(decryptedAttachment.messageGuid)
        // Delete attachment
        DPAGAttachmentWorker.removeEncryptedAttachment(guid: decryptedAttachment.attachmentGuid)
    }

    override func nameForFileOpen() -> String {
        var persons = "noname"
        if let decStream = DPAGApplicationFacade.cache.decryptedStream(streamGuid: self.streamGuid, in: nil), let streamName = decStream.name {
            persons = streamName
        }
        return persons
    }

    func openFileData(_ data: Data, fileName: String, inRect: CGRect, inView: UIView) {
        let fileURLTemp = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(fileName)
        self.fileURLTemp = fileURLTemp
        if FileManager.default.fileExists(atPath: fileURLTemp.path) {
            do {
                try FileManager.default.removeItem(at: fileURLTemp)
            } catch {
                DPAGLog(error)
            }
        }
        try? data.write(to: fileURLTemp, options: [.atomic])
        self.openInController = UIDocumentInteractionController(url: fileURLTemp)
        self.openInController?.delegate = self
        self.openInControllerOpensApplication = false
        if self.openInController?.presentPreview(animated: true) == false {
            if self.openInController?.presentOpenInMenu(from: inRect, in: inView, animated: true) == false {
                do {
                    try FileManager.default.removeItem(at: fileURLTemp)
                } catch {
                    DPAGLog(error)
                }
                self.fileURLTemp = nil
                self.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: "chat.message.fileOpen.error.noAppToOpenInFound.message"))
            }
        }
    }

    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        self
    }
    
    func updateInputStateAnimated(_ animated: Bool, canShowAlert: Bool = true, forceDisabled: Bool = false) {
        let force = self.isNewChatStreamWithUnconfirmedContact
        self.updateInputStateAnimated(animated, forceDisabled: forceDisabled, forceEnabledIfNotConfirmed: force, canShowAlert: canShowAlert)
    }

    func updateInputStateIfInputDisabledAndForceDisabled(_: Bool, forceEnabledIfNotConfirmed: Bool) {
        self.updateInputStateIfInputDisabledAndForceDisabled(forceEnabledIfNotConfirmed, forceEnabledIfNotConfirmed: forceEnabledIfNotConfirmed, canShowAlert: true)
    }

    func updateInputStateIfInputDisabledAndForceDisabled(_ forceDisabled: Bool, forceEnabledIfNotConfirmed: Bool, canShowAlert: Bool) {
        var inputDisabled = true
        if let stream = DPAGApplicationFacade.cache.decryptedStream(streamGuid: self.streamGuid) {
            if forceDisabled == false {
                inputDisabled = (self.state != .write)
                if let streamPrivate = stream as? DPAGDecryptedStreamPrivate, let contactGuidCache = streamPrivate.contactGuid, let contact = DPAGApplicationFacade.cache.contact(for: contactGuidCache) {
                    if contact.isBlocked && canShowAlert && contact.isDeleted == false {
                        self.presentErrorAlert(alertConfig: AlertConfigError(titleIdentifier: "chat.single.alert.title.contact_blocked", messageIdentifier: "chat.single.alert.message.contact_blocked"))
                    }
                    self.state = contact.streamState
                    inputDisabled = inputDisabled || self.state != .write || ((contact.isConfirmed == false && !forceEnabledIfNotConfirmed) || contact.isBlocked || contact.isDeleted || contact.isReadOnly)
                } else if let streamGroup = stream as? DPAGDecryptedStreamGroup {
                    inputDisabled = inputDisabled || (streamGroup.streamState != .write)
                }
            }
        }
        if inputDisabled {
            self.updateInputStateAnimated(false, forceDisabled: forceDisabled, forceEnabledIfNotConfirmed: forceEnabledIfNotConfirmed)
        }
    }

    func updateInputStateAnimated(_ animated: Bool, forceDisabled: Bool, forceEnabledIfNotConfirmed: Bool, canShowAlert: Bool = true) {
        var inputDisabled = true
        if let stream = DPAGApplicationFacade.cache.decryptedStream(streamGuid: self.streamGuid) {
            if forceDisabled == false {
                inputDisabled = (self.state != .write)
                if let streamPrivate = stream as? DPAGDecryptedStreamPrivate, let contactGuidCache = streamPrivate.contactGuid, let contact = DPAGApplicationFacade.cache.contact(for: contactGuidCache) {
                    if contact.isBlocked && canShowAlert && contact.isDeleted == false {
                        self.presentErrorAlert(alertConfig: AlertConfigError(titleIdentifier: "chat.single.alert.title.contact_blocked", messageIdentifier: "chat.single.alert.message.contact_blocked"))
                    }
                    self.state = contact.streamState
                    inputDisabled = inputDisabled || self.state != .write || ((contact.isConfirmed == false && !forceEnabledIfNotConfirmed) || contact.isBlocked || contact.isDeleted || contact.isReadOnly)
                    if inputDisabled {
                        DPAGLog("Message input box is disabled. Contact confirmed: \(contact.isConfirmed). Contact blocked: \(contact.isBlocked). Contact read only: \(contact.isReadOnly). Contact deleted: \(contact.isDeleted)")
                    }
                } else if let streamGroup = stream as? DPAGDecryptedStreamGroup {
                    inputDisabled = inputDisabled || (streamGroup.streamState != .write)
                    if !inputDisabled, let ownAccountGuid = DPAGApplicationFacade.cache.account?.guid, let group = DPAGApplicationFacade.cache.group(for: streamGuid), group.groupType == .announcement && !group.adminGuids.contains(ownAccountGuid) {
                        inputDisabled = true
                    }
                }
            }
            if !inputDisabled && self.inputController == nil {
                self.initInputController()
            }
            self.inputController?.updateInputState(inputDisabled, animated: animated)
            if inputDisabled {
                self.inputSendOptionsView?.reset()
            }
            self.showsInputController = !inputDisabled
        }
    }
}

extension DPAGChatCellBaseViewController: UIDocumentInteractionControllerDelegate {
    func documentInteractionControllerDidDismissOpenInMenu(_: UIDocumentInteractionController) {
        if self.openInControllerOpensApplication == false, let fileURLTemp = self.fileURLTemp {
            do {
                try FileManager.default.removeItem(at: fileURLTemp)
            } catch {
                DPAGLog(error)
            }
            self.fileURLTemp = nil
        }
    }

    func documentInteractionController(_: UIDocumentInteractionController, willBeginSendingToApplication _: String?) {
        self.openInControllerOpensApplication = true
    }

    func documentInteractionController(_: UIDocumentInteractionController, didEndSendingToApplication _: String?) {
        if let fileURLTemp = self.fileURLTemp {
            do {
                try FileManager.default.removeItem(at: fileURLTemp)
            } catch {
                DPAGLog(error)
            }
            self.fileURLTemp = nil
        }
    }
}
