//
//  DPAGMessageCell.swift
// ginlo
//
//  Created by RBU on 07/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import SIMSmeCore
import UIKit

public typealias DPAGChatMessageContentSelectedBlock = () -> Void
public typealias DPAGChatMessageContactSelectedBlock = () -> Void
public typealias DPAGChatMessageLinkSelectedBlock = (URL?) -> Void

public protocol DPAGChatStreamMenuDelegate: AnyObject {
    func isLongPressEnabled() -> Bool
    func isEditingEnabled() -> Bool
    func longPress(_ recognizer: UILongPressGestureRecognizer, withCell cell: UITableViewCell & DPAGMessageCellProtocol)

    func menuItemsForCell(_ cell: DPAGMessageCellProtocol) -> [UIMenuItem]
}

public extension DPAGChatStreamMenuDelegate {
    func isLongPressEnabled() -> Bool {
        true
    }

    func isEditingEnabled() -> Bool {
        true
    }
}

public protocol DPAGChatStreamDelegate: UINavigationControllerDelegate, DPAGChatStreamMenuDelegate {
    // @property(nullable, nonatomic,readonly,strong) UINavigationController *navigationController
//    var navigationController: UINavigationController? { get }

    func canSelectContact() -> Bool
    func canSelectContent() -> Bool

    func deleteChatStreamMessage(_ messageGuid: String)
    func commentChatStreamMessage(_ message: DPAGDecryptedMessage)
    func openInfoForMessage(_ message: DPAGDecryptedMessage)
    func selectCitationForMessage(_ message: DPAGDecryptedMessage)

    func askToForwardURL(_ url: URL)
    func askToForwardURL(_ url: URL, message: DPAGDecryptedMessage)
    func openLink(for label: DPAGChatLabel)
    func copyLink(for label: DPAGChatLabel)
    func forwardText(_ forwardingText: String, message: DPAGDecryptedMessage)
    func requestRejoinAVCall(_ message: DPAGDecryptedMessage)

    @discardableResult
    func resignFirstTextResponder() -> Bool

    func didSelectMessageCell(_ cell: DPAGMessageCellProtocol)
    func showOptionsForFailedMessage(_ message: String?, openAction blockOpen: DPAGCompletion?)
    func showProfile()
    func showDetailsForContact(_ contactGuid: String)
    func showDetailsForChannel(_ channelGuid: String)
    func showContactAddForVCard(_ contactToSave: String)
    func showContactAddToPrivateVCard(vcardAccoundID: String, vcardAccountGuid: String, contactToSave: String)

    func showErrorAlertForCellWithMessage(alertConfig: UIViewController.AlertConfigError)

    func didSelectValidLocation(_ message: DPAGDecryptedMessage)
    func didSelectValidText(_ message: DPAGDecryptedMessage)
    func didSelectValidContact(_ message: DPAGDecryptedMessage)
    func didSelectValidSystemMessage(_ message: DPAGDecryptedMessage)
    func didSelectValidImage(_ message: DPAGDecryptedMessage, cell: DPAGMessageCellProtocol)
    func didSelectValidVideo(_ message: DPAGDecryptedMessage, cell: DPAGMessageCellProtocol)
    func didSelectValidFile(_ message: DPAGDecryptedMessage, cell: DPAGMessageCellProtocol)
    func didSelectValidVoiceRec(_ message: DPAGDecryptedMessage, cell: DPAGMessageCellProtocol)
    func openSingleChat(_ message: DPAGDecryptedMessage)

    func loadAttachmentWithMessage(_ decryptedMessage: DPAGDecryptedMessage, cell cellWithProgress: DPAGCellWithProgress?, completion: @escaping ((Data?, String?) -> Void))

    func loadAttachmentImageWithMessage(_ decryptedMessage: DPAGDecryptedMessage, cell cellWithProgress: DPAGCellWithProgress?)
    func loadAttachmentImageWithMessage(_ decryptedMessage: DPAGDecryptedMessage, cell cellWithProgress: DPAGCellWithProgress?, previewImage: UIImage?)
    func loadAttachmentVideoWithMessage(_ decryptedMessage: DPAGDecryptedMessage, cell cellWithProgress: DPAGCellWithProgress?, previewImage: UIImage?)
    func loadAttachmentFileWithMessage(_ decryptedMessage: DPAGDecryptedMessage, cell cellWithProgress: DPAGCellWithProgress?)

    func setUpImageViewWithData(_ data: Data, messageGuid: String, decMessage: DPAGDecryptedMessage, stream streamGuid: String)
    func setUpVideoViewWithData(_ data: Data, messageGuid: String, decMessage: DPAGDecryptedMessage, stream streamGuid: String)
    func setUpVoiceRecViewWithData(_ data: Data, messageGuid: String, decMessage: DPAGDecryptedMessage, stream streamGuid: String)
    func setUpFileViewWithData(_ data: Data, messageGuid: String, decMessage: DPAGDecryptedMessage, stream streamGuid: String, inRect rect: CGRect, inView: UIView)
}

extension DPAGChatStreamDelegate {
    func openInfoForMessage(_: DPAGDecryptedMessage) {}
}

public protocol DPAGChatStreamCell: AnyObject {
    func setCellContactLabel(_ contactLabel: String?, textColor: UIColor?)
    func setCellContactLabelAttributed(_ contactLabel: NSAttributedString?, textColor: UIColor?)
    func setCellDate(_ dateLabel: String?)
    func setCellDateColor(_ dateColor: UIColor?)

    func setChatStreamCellState(_ state: DPAGChatStreamCellState)

    func setCellContentSelectedAction(_ block: @escaping DPAGChatMessageContentSelectedBlock)
    func setCellContactSelectedAction(_ block: @escaping DPAGChatMessageContactSelectedBlock)

    func zoomingViewForNavigationTransition() -> UIView?
}

public protocol DPAGChatStreamCellLeft {}

protocol DPAGChatStreamCellRight {}

public protocol DPAGMessageCellProtocol: DPAGChatStreamCell {
    var decryptedMessage: DPAGDecryptedMessage { get }

    var streamMenuDelegate: DPAGChatStreamMenuDelegate? { get set }
    var streamDelegate: DPAGChatStreamDelegate? { get set }

    var isLoadingAttachment: Bool { get set }
    var isHidden: Bool { get }

    func configureCellWithMessage(_ decryptedMessage: DPAGDecryptedMessage, forHeightMeasurement: Bool)

    func canPerformForward() -> Bool
    func canPerformCopy() -> Bool
    func canRejoinAVCall() -> Bool
    func canPerformComment() -> Bool

    func openSingleChatForSelectedCell()
    func deleteSelectedCell()
    func forwardSelectedCell()
    func rejoinAVCall()
    func copySelectedCell()
    func commentSelectedCell()
    func infoSelectedCell()
}

class ISOOutlinedLabel: UILabel {

    override func drawText(in rect: CGRect) {

        let strokeTextAttributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.strokeColor: UIColor.white,
            NSAttributedString.Key.foregroundColor: UIColor.black,
            NSAttributedString.Key.strokeWidth: -3
        ]

        self.attributedText = NSAttributedString(string: self.text ?? "", attributes: strokeTextAttributes)
        super.drawText(in: rect)
    }
}

class DPAGMessageCell: UITableViewCell, DPAGMessageCellProtocol {
    static let DPAGChatStreamBaseMessageViewControllerCellAlphaWhileSending: CGFloat = 0.5
    var isChannelCell = false
    var contactSelectedBlock: DPAGChatMessageContactSelectedBlock?
    var contentSelectedBlock: DPAGChatMessageContentSelectedBlock?

    var decryptedMessage: DPAGDecryptedMessage = DPAGDecryptedMessage(messageGuid: "unknown", contentType: DPAGMessageContentType.plain.stringRepresentation)

    @IBOutlet weak var viewAvatar: UIImageView!
    {
        didSet {
            self.viewAvatar.layer.cornerRadius = self.viewAvatar.frame.size.height / 2.0
            self.viewAvatar.layer.masksToBounds = true
        }
    }

    @IBOutlet var viewBubble: UIView! {
        didSet {
            self.viewBubble?.isUserInteractionEnabled = true
            self.viewBubble?.isAccessibilityElement = true
            self.viewBubble?.accessibilityIdentifier = "Bubble"
        }
    }

    @IBOutlet var viewBubbleFrame: UIView! {
        didSet {
            self.viewBubbleFrame.layer.cornerRadius = 8
            self.viewBubbleFrame.layer.masksToBounds = true
            self.viewBubbleFrame?.backgroundColor = self is DPAGChatStreamCellLeft ? DPAGColorProvider.shared[.chatDetailsBubbleNotMine] : DPAGColorProvider.shared[.chatDetailsBubbleMine]
        }
    }
    
    @IBOutlet var viewBubbleImage: UIView? {
        didSet {
            self.viewBubbleImage?.backgroundColor = self is DPAGChatStreamCellLeft ? DPAGColorProvider.shared[.chatDetailsBubbleNotMine] : DPAGColorProvider.shared[.chatDetailsBubbleMine]
        }
    }

    @IBOutlet var viewBubbleImageAvatar: UIView? {
        didSet {
            self.viewBubbleImageAvatar?.backgroundColor = self is DPAGChatStreamCellLeft ? DPAGColorProvider.shared[.chatDetailsBubbleNotMine] : DPAGColorProvider.shared[.chatDetailsBubbleMine]

            if let view = self.viewBubbleImageAvatar {
                let maskPath = CGMutablePath()
                let radius: CGFloat = 24
                let yFloor = view.frame.height - 4

                maskPath.move(to: CGPoint(x: 0, y: yFloor))
                maskPath.addLine(to: CGPoint(x: radius, y: yFloor))
                maskPath.addArc(center: CGPoint(x: radius, y: yFloor - radius), radius: radius, startAngle: CGFloat(Double.pi / 2), endAngle: CGFloat(Double.pi), clockwise: false)
                maskPath.addLine(to: CGPoint(x: 0, y: yFloor))

                // Create the shape layer and set its path
                let maskLayer = CAShapeLayer()

                maskLayer.frame = view.bounds
                maskLayer.path = maskPath

                // Set the newly created shape layer as the mask for the image view's layer
                view.layer.mask = maskLayer

                if self is DPAGChatStreamCellLeft {
                    view.transform = CGAffineTransform(scaleX: -1, y: 1)
                }
            }
        }
    }

    @IBOutlet var labelInfo: ISOOutlinedLabel? {
        didSet {
            self.labelInfo?.text = nil
        }
    }

    @IBOutlet var viewLabelSender: DPAGStackViewContentView? {
        didSet {
            self.viewLabelSender?.isHidden = true
        }
    }

    @IBOutlet var labelSender: UILabel? {
        didSet {
            self.labelSender?.textColor = chatTextColor()
            self.labelSender?.lineBreakMode = .byTruncatingHead
            self.labelSender?.text = nil
        }
    }

    @IBOutlet var viewBubbleContent: UIView? {
        didSet {}
    }

    @IBOutlet var viewStatus: UIImageView? {
        didSet {
            self.viewStatus?.isAccessibilityElement = true
        }
    }

    @IBOutlet private var viewCitationFrame: DPAGCitationCellView? {
        didSet {
            self.viewCitationFrame?.isHidden = true
        }
    }

    @IBOutlet var statusStackView: UIStackView!

    var isLoadingAttachment = false

    weak var streamMenuDelegate: DPAGChatStreamMenuDelegate?
    weak var streamDelegate: DPAGChatStreamDelegate? {
        didSet {
            self.streamMenuDelegate = self.streamDelegate
        }
    }

    @IBOutlet private var viewSendOptionValues: DPAGSendOptionsCellView? {
        didSet {
            self.viewSendOptionValues?.isHidden = true
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        self.configContentViews()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // Make sure the contentView does a layout pass here so that its subviews have their frames set, which we
        // need to use to set the preferredMaxLayoutWidth below.
        self.contentView.setNeedsLayout()
        self.contentView.layoutIfNeeded()

        // Set the preferredMaxLayoutWidth of the mutli-line bodyLabel based on the evaluated width of the label's frame,
        // as this will allow the text to wrap correctly, and as a result allow the label to take on the correct height.

        if let labelInfo = self.labelInfo {
            labelInfo.preferredMaxLayoutWidth = labelInfo.frame.width
        }
        if let labelSender = self.labelSender {
            labelSender.preferredMaxLayoutWidth = labelSender.frame.width
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public

    func configContentViews() {
        NotificationCenter.default.addObserver(self, selector: #selector(updateFonts), name: UIContentSizeCategory.didChangeNotification, object: nil)

        self.backgroundColor = .clear
        self.contentView.backgroundColor = .clear

        let tapGr = UITapGestureRecognizer(target: self, action: #selector(citationSelected))

        tapGr.numberOfTapsRequired = 1
        tapGr.cancelsTouchesInView = false

        self.viewCitationFrame?.addGestureRecognizer(tapGr)
        self.viewCitationFrame?.isUserInteractionEnabled = true

        self.updateFonts()
    }

    func zoomingViewForNavigationTransition() -> UIView? {
        self.viewBubble
    }

    @objc
    func updateFonts() {
        self.labelSender?.font = UIFont.kFontSubheadline
        self.viewCitationFrame?.updateFonts()
    }

    func configureCellWithMessage(_ decryptedMessage: DPAGDecryptedMessage, forHeightMeasurement: Bool) {
        self.selectionStyle = .none
        self.isLoadingAttachment = false
        self.decryptedMessage = decryptedMessage
        if decryptedMessage is DPAGDecryptedMessageChannel {
            self.viewBubbleFrame?.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
        }
        self.viewSendOptionValues?.isHidden = decryptedMessage.isHighPriorityMessage == false
        self.viewSendOptionValues?.configureCellWithMessage(decryptedMessage, forHeightMeasurement: forHeightMeasurement)
        self.contentView.alpha = decryptedMessage.sendingState == .sending ? DPAGMessageCell.DPAGChatStreamBaseMessageViewControllerCellAlphaWhileSending : 1
        if decryptedMessage.sendingState == .sentFailed {
            self.setCellDate(DPAGLocalizedString("attention"))
            self.setCellDateColor(DPAGColorProvider.shared[.messageCellSendingFailedAlert])
        } else {
            if let messageDate = decryptedMessage.messageDate {
                self.setCellDate(messageDate.timeLabel)
            } else {
                self.setCellDate("")
            }
            self.setCellDateColor(nil)
        }
        if (decryptedMessage.isSelfDestructive && decryptedMessage.isOwnMessage) || decryptedMessage.sendOptions?.dateToBeSend != nil {
            self.viewSendOptionValues?.isHidden = false
        }
        self.configureCitation()
        if decryptedMessage.isOwnMessage {
            if forHeightMeasurement == false {
                let state = decryptedMessage.statusCode
                self.setChatStreamCellState(state)
                if decryptedMessage.sendingState == .sentFailed {
                    self.setCellContactSelectedAction { [weak self] in
                        if let strongSelf = self {
                            strongSelf.streamDelegate?.showOptionsForFailedMessage(decryptedMessage.messageGuid, openAction: nil)
                        }
                    }
                } else {
                    self.setCellContactSelectedAction { [weak self] in
                        if let strongSelf = self {
                            strongSelf.streamDelegate?.showProfile()
                        }
                    }
                }
            }
        } else {
            if decryptedMessage.messageType == .channel {
                if let decryptedMessageChannel = decryptedMessage as? DPAGDecryptedMessageChannel {
                    if forHeightMeasurement == false {
                        self.viewBubbleFrame?.backgroundColor = DPAGColorProvider.shared[.chatDetailsBubbleChannel]
                        self.viewBubbleImage?.backgroundColor = DPAGColorProvider.shared[.chatDetailsBubbleChannel]
                        self.viewBubbleImageAvatar?.backgroundColor = DPAGColorProvider.shared[.chatDetailsBubbleChannel]
                        self.isChannelCell = true
                        self.setCellContactSelectedAction { [weak self] in
                            self?.didSelectMessageWithValidBlock { [weak self] in
                                self?.streamDelegate?.showDetailsForChannel(decryptedMessageChannel.channelGuid)
                            }
                        }
                    }
                    if let section = decryptedMessageChannel.section {
                        let rangePipe = (section as NSString).range(of: "|")
                        if rangePipe.location != NSNotFound {
                            let sectionAttributed = NSMutableAttributedString(string: section)
                            sectionAttributed.addAttribute(.foregroundColor, value: decryptedMessageChannel.colorChatMessageSection ?? DPAGColorProvider.shared[.channelChatMessageSection], range: NSRange(location: rangePipe.location + 1, length: sectionAttributed.length - rangePipe.location - 1))
                            self.setCellContactLabelAttributed(sectionAttributed, textColor: decryptedMessageChannel.colorChatMessageSectionPre ?? DPAGColorProvider.shared[.channelChatMessageSectionPre])
                        } else {
                            self.setCellContactLabel(section, textColor: decryptedMessageChannel.colorChatMessageSection ?? DPAGColorProvider.shared[.channelChatMessageSection])
                        }
                    } else {
                        self.setCellContactLabel(decryptedMessage.isSelfDestructive ? nil : "", textColor: decryptedMessageChannel.colorChatMessageSection ?? DPAGColorProvider.shared[.channelChatMessageSectionPre])
                    }
                }
            } else if decryptedMessage.messageType == .private, let decryptedMessagePrivate = decryptedMessage as? DPAGDecryptedMessagePrivate {
                if forHeightMeasurement == false {
                    if decryptedMessagePrivate.isSystemChat {
                        if let cellSimple = self as? DPAGSimpleMessageCellProtocol, decryptedMessage.isOwnMessage == false {
                            cellSimple.setLinkSelectedAction({ selectedURL in
                                if let selectedURL = selectedURL {
                                    AppConfig.openURL(selectedURL)
                                }
                            })
                        }
                    } else {
                        self.setAvatarForPrivateContact(decryptedMessagePrivate)
                        self.setCellContactSelectedAction { [weak self] in
                            self?.didSelectMessageWithValidBlock { [weak self] in
                                self?.streamDelegate?.showDetailsForContact(decryptedMessage.fromAccountGuid)
                            }
                        }
                    }
                }
                if decryptedMessage.contentType == .oooStatusMessage {
                    self.setCellContactLabel(DPAGLocalizedString("cell.oooStatus.nickname"), textColor: DPAGColorProvider.shared[.messageCellOOOStatusMessage]) // #INSECURE
                } else {
                    self.setCellContactLabel(nil, textColor: nil)
                }
            } else if decryptedMessage.messageType == .group, let decryptedMessageGroup = decryptedMessage as? DPAGDecryptedMessageGroup {
                if decryptedMessage.contentType != .textRSS {
                    self.setCellContactLabel(decryptedMessageGroup.contactName, textColor: decryptedMessageGroup.textColorNick)
                } else {
                    self.setCellContactLabel(nil, textColor: nil)
                }

                if forHeightMeasurement == false {
                    self.setAvatarForGroupContact(decryptedMessageGroup)
                    self.setCellContactSelectedAction { [weak self] in
                        self?.didSelectMessageWithValidBlock { [weak self] in
                            self?.streamDelegate?.showDetailsForContact(decryptedMessage.fromAccountGuid)
                        }
                    }
                }
            }
        }
    }

    func setAvatarForPrivateContact(_ decMessagePrivate: DPAGDecryptedMessagePrivate) {
        if let viewAvatar = self.viewAvatar {
            if decMessagePrivate.isSystemChat {
                viewAvatar.image = DPAGImageProvider.shared[.kImageChatSystemLogo]
                viewAvatar.layer.cornerRadius = 0
            } else {
                if let contactGuid = decMessagePrivate.contactGuid, let contact = DPAGApplicationFacade.cache.contact(for: contactGuid) {
                    viewAvatar.image = contact.image(for: .chat)
                    viewAvatar.layer.cornerRadius = viewAvatar.frame.size.height / 2.0
                }
            }
        }
    }

    func setAvatarForGroupContact(_ decMessageGroup: DPAGDecryptedMessageGroup) {
        if let viewAvatar = self.viewAvatar {
            if let contactGuid = decMessageGroup.contactGuid, let contact = DPAGApplicationFacade.cache.contact(for: contactGuid) {
                viewAvatar.image = contact.image(for: .chat)
                viewAvatar.layer.cornerRadius = viewAvatar.frame.size.height / 2.0
            }
        }
    }

    func configureCitation() {
        self.viewCitationFrame?.configureCitation(citationContent: self.decryptedMessage.citationContent)
        if self.decryptedMessage.citationContent != nil {
            self.viewCitationFrame?.isHidden = false
        } else {
            self.viewCitationFrame?.isHidden = true
        }
    }

    func didSelectMessageWithValidBlock(_ blockValidMessageSelected: DPAGCompletion?) {
        let hasSendingFailed = self.decryptedMessage.sendingState == DPAGMessageState.sentFailed

        if hasSendingFailed {
            self.streamDelegate?.showOptionsForFailedMessage(self.decryptedMessage.messageGuid, openAction: blockValidMessageSelected)
            return
        }

        if self.decryptedMessage.isSelfDestructive, !self.decryptedMessage.isOwnMessage {
            if DPAGApplicationFacade.messageWorker.isDestructiveMessageValid(messageGuid: self.decryptedMessage.messageGuid, sendOptions: self.decryptedMessage.sendOptions) == false {
                return
            }
        }

        self.streamDelegate?.didSelectMessageCell(self)

        blockValidMessageSelected?()
    }

    func setCellContactLabel(_ contactLabel: String?, textColor: UIColor?) {
        self.viewLabelSender?.isHidden = contactLabel == nil
        self.labelSender?.attributedText = nil
        self.labelSender?.text = contactLabel
        self.labelSender?.textColor = textColor ?? chatTextColor()
    }

    func setCellContactLabelAttributed(_ contactLabel: NSAttributedString?, textColor: UIColor?) {
        self.viewLabelSender?.isHidden = contactLabel == nil
        self.labelSender?.textColor = textColor ?? chatTextColor()
        self.labelSender?.text = nil
        self.labelSender?.attributedText = contactLabel
    }

    func setCellDate(_ dateLabel: String?) {
        self.labelInfo?.text = dateLabel
    }

    func setCellDateColor(_ dateColor: UIColor?) {
        // self.labelInfo?.textColor = dateColor ?? DPAGColorProvider.shared[.chatDetailsBackgroundContrast]
    }

    func setChatStreamCellState(_ state: DPAGChatStreamCellState) {
        guard let statusImageAndTintColor = state.statusImageAndTintColor() else {
            self.viewStatus?.image = nil
            return
        }

        self.viewStatus?.image = statusImageAndTintColor.image
        self.viewStatus?.accessibilityIdentifier = statusImageAndTintColor.accessibilityIdentifier

        if let tintColor = statusImageAndTintColor.tintColor {
            self.viewStatus?.tintColor = tintColor
        }
    }

    func setLongPressGestureRecognizerForView(_ lpView: UIView?) {
        guard let view = lpView else {
            return
        }

        if let gestureRecognizers = view.gestureRecognizers {
            for gr in gestureRecognizers where gr is UILongPressGestureRecognizer {
                view.removeGestureRecognizer(gr)
            }
        }
        let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPress(_:)))

        view.addGestureRecognizer(recognizer)
    }

    func setCellContactSelectedAction(_ block: @escaping DPAGChatMessageContactSelectedBlock) {
        if let gestureRecognizers = self.statusStackView?.gestureRecognizers {
            for gr in gestureRecognizers where gr is UITapGestureRecognizer {
                self.statusStackView?.removeGestureRecognizer(gr)
            }
        }

        self.contactSelectedBlock = block

        let tapGrFailed = UITapGestureRecognizer(target: self, action: #selector(contactSelected))

        tapGrFailed.numberOfTapsRequired = 1
        tapGrFailed.cancelsTouchesInView = false

        self.statusStackView?.addGestureRecognizer(tapGrFailed)
        self.statusStackView?.isUserInteractionEnabled = true
    }

    @objc
    func contactSelected() {
        if self.streamDelegate?.canSelectContact() ?? true {
            self.contactSelectedBlock?()
        }
    }

    func setCellContentSelectedAction(_ block: @escaping DPAGChatMessageContentSelectedBlock) {
        guard let viewSelected = self.zoomingViewForNavigationTransition() else {
            return
        }

        if let gestureRecognizers = viewSelected.gestureRecognizers {
            for gr in gestureRecognizers where gr is UITapGestureRecognizer {
                viewSelected.removeGestureRecognizer(gr)
            }
        }
        self.contentSelectedBlock = block

        let tapGr = UITapGestureRecognizer(target: self, action: #selector(contentSelected))

        tapGr.numberOfTapsRequired = 1
        tapGr.cancelsTouchesInView = false

        viewSelected.isUserInteractionEnabled = true
        viewSelected.addGestureRecognizer(tapGr)
    }

    @objc
    func contentSelected() {
        if self.streamDelegate?.canSelectContent() ?? true {
            self.contentSelectedBlock?()
        }
    }

    @objc
    func citationSelected() {
        self.streamDelegate?.selectCitationForMessage(self.decryptedMessage)
    }

    func showErrorAlertCheck(alertConfig: UIViewController.AlertConfigError) {
        self.streamDelegate?.showErrorAlertForCellWithMessage(alertConfig: alertConfig)
    }

    func didSelectValidImage() {
        if self.decryptedCheckedMessage() {
            return
        }
        self.streamDelegate?.didSelectValidImage(self.decryptedMessage, cell: self)
    }

    func didSelectValidLocation() {
        self.streamDelegate?.didSelectValidLocation(self.decryptedMessage)
    }

    func didSelectValidText() {
        if self.decryptedCheckedMessage() {
            return
        }

        self.streamDelegate?.didSelectValidText(self.decryptedMessage)
    }

    func didSelectValidVideo() {
        if self.decryptedCheckedMessage() {
            return
        }
        self.streamDelegate?.didSelectValidVideo(self.decryptedMessage, cell: self)
    }

    func didSelectValidFile() {
        if self.decryptedCheckedMessage() {
            return
        }
        self.streamDelegate?.didSelectValidFile(self.decryptedMessage, cell: self)
    }

    func didSelectValidContact() {
        if self.decryptedCheckedMessage() {
            return
        }

        self.streamDelegate?.didSelectValidContact(self.decryptedMessage)
    }

    func decryptedCheckedMessage() -> Bool {
        var decryptedMessageNew: DPAGDecryptedMessage?

        // Force Message Checking
        if self.decryptedMessage.attachmentHash == nil, self.decryptedMessage.messageType != .channel {
            decryptedMessageNew = DPAGApplicationFacade.cache.refreshDecryptedMessage(messageGuid: self.decryptedMessage.messageGuid)

            if decryptedMessageNew == nil {
                return true
            }
        }

        let decryptedMessageChecked = decryptedMessageNew ?? self.decryptedMessage

        if DPAGApplicationFacade.preferences.isBaMandant == false {
            var ownMessage = false

            if decryptedMessageChecked.isOwnMessage, decryptedMessageChecked.attachmentGuid?.hasPrefix(.attachment) ?? false {
                ownMessage = true
            }

            if decryptedMessageChecked.attachmentGuid != nil, decryptedMessageChecked.isReadServerAttachment, ownMessage, AttachmentHelper.attachmentAlreadySavedForGuid(decryptedMessageChecked.attachmentGuid) == false {
                self.showErrorAlertCheck(alertConfig: UIViewController.AlertConfigError(messageIdentifier: "chats.attachment.deleted"))
                return true
            }
        }

        self.decryptedMessage = decryptedMessageChecked

        return false
    }

    func chatTextColor() -> UIColor {
        DPAGColorProvider.shared[.chatDetailsBubbleMineContrast]
    }

    // MARK: - Menu controller

    @objc
    func longPress(_ recognizer: UILongPressGestureRecognizer) {
        if recognizer.state == .began, self.streamMenuDelegate?.isLongPressEnabled() ?? false {
            self.streamMenuDelegate?.longPress(recognizer, withCell: self)

            let menu = UIMenuController.shared
            let retVal = self.menuItems()

            menu.menuItems = retVal

            if let recognizerView = recognizer.view, let recognizerSuperview = recognizerView.superview {
                let targetRect = recognizerView.frame

                menu.setTargetRect(targetRect, in: recognizerSuperview)
            }
            menu.setMenuVisible(true, animated: true)

            NotificationCenter.default.addObserver(self, selector: #selector(menuDidHide(_:)), name: UIMenuController.didHideMenuNotification, object: nil)
        }

        // [recognizer setCancelsTouchesInView:![cell isKindOfClass:[DPAGSimpleMessageCell class]]]
    }

    @objc
    func menuDidHide(_: Notification) {
        let menu = UIMenuController.shared

        menu.menuItems = nil

        NotificationCenter.default.removeObserver(self, name: UIMenuController.didHideMenuNotification, object: nil)
    }

    func canPerformForward() -> Bool {
        DPAGApplicationFacade.preferences.canSendMedia
    }

    func canPerformCopy() -> Bool {
        false
    }

    func canRejoinAVCall() -> Bool {
        self.decryptedMessage.contentType == .avCallInvitation
    }
    
    func canPerformComment() -> Bool {
        true
    }

    func canPerformInfo() -> Bool {
        decryptedMessage.isOwnMessage
    }

    func menuItems() -> [UIMenuItem] {
        self.streamMenuDelegate?.menuItemsForCell(self) ?? []
    }

    @objc
    func openSingleChatForSelectedCell() {
        self.streamDelegate?.openSingleChat(self.decryptedMessage)
    }

    @objc
    func deleteSelectedCell() {
        self.streamDelegate?.deleteChatStreamMessage(self.decryptedMessage.messageGuid)
    }

    @objc
    func forwardSelectedCell() {}

    @objc
    func rejoinAVCall() {
        self.streamDelegate?.requestRejoinAVCall(self.decryptedMessage)
    }
    
    @objc
    func copySelectedCell() {}

    @objc
    func commentSelectedCell() {
        self.streamDelegate?.commentChatStreamMessage(self.decryptedMessage)
    }

    @objc
    func infoSelectedCell() {
        self.streamDelegate?.openInfoForMessage(self.decryptedMessage)
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if sender is UIMenuController {
            switch action {
            case #selector(copySelectedCell):
                return self.canPerformCopy()
            case #selector(rejoinAVCall):
                return self.canRejoinAVCall()
            case #selector(forwardSelectedCell):
                return self.canPerformForward()
            case #selector(deleteSelectedCell):
                return true
            case #selector(commentSelectedCell):
                return self.canPerformComment()
            case #selector(openSingleChatForSelectedCell):
                return true
            case #selector(infoSelectedCell):
                return self.canPerformInfo()
            default:
                break
            }
        }
        return super.canPerformAction(action, withSender: sender)
    }
    
    @objc
    func handleDesignColorsUpdated() {
        if self.isChannelCell {
            self.viewBubbleFrame?.backgroundColor = DPAGColorProvider.shared[.chatDetailsBubbleChannel]
            self.viewBubbleImage?.backgroundColor = DPAGColorProvider.shared[.chatDetailsBubbleChannel]
            self.viewBubbleImageAvatar?.backgroundColor = DPAGColorProvider.shared[.chatDetailsBubbleChannel]
        } else {
            self.viewBubbleFrame?.backgroundColor = self is DPAGChatStreamCellLeft ? DPAGColorProvider.shared[.chatDetailsBubbleNotMine] : DPAGColorProvider.shared[.chatDetailsBubbleMine]
            self.viewBubbleImage?.backgroundColor = self is DPAGChatStreamCellLeft ? DPAGColorProvider.shared[.chatDetailsBubbleNotMine] : DPAGColorProvider.shared[.chatDetailsBubbleMine]
            self.viewBubbleImageAvatar?.backgroundColor = self is DPAGChatStreamCellLeft ? DPAGColorProvider.shared[.chatDetailsBubbleNotMine] : DPAGColorProvider.shared[.chatDetailsBubbleMine]
        }
    }
    
    open override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.handleDesignColorsUpdated()
                self.setNeedsLayout()
                self.layoutIfNeeded()
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }
}

class DPAGCellProgressViewLarge: UIView {
    var fillImage: UIImage?
    fileprivate var backgroundImage: UIImage?

    var path = UIBezierPath()

    var progressValue: Double = 0

    override func awakeFromNib() {
        super.awakeFromNib()

        self.backgroundColor = .clear
        self.path = UIBezierPath()
        self.isUserInteractionEnabled = false
        self.progressValue = 0
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.backgroundImage = UIImage.circleImage(size: frame.size, colorFill: DPAGColorProvider.shared[.attachmentDownloadProgressBackground], colorBorder: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        self.backgroundImage = UIImage.circleImage(size: frame.size, colorFill: DPAGColorProvider.shared[.attachmentDownloadProgressBackground], colorBorder: nil)
    }

    func setProgress(_ value: Double) {
        self.progressValue = value

        if value != 0 {
            let path = UIBezierPath(arcCenter: CGPoint(x: self.frame.size.width / 2, y: self.frame.size.height / 2), radius: (self.frame.size.width / 2) - 1, startAngle: CGFloat(-(Double.pi / 2)), endAngle: CGFloat((2 * Double.pi * value) - (Double.pi / 2)), clockwise: true)

            path.lineWidth = 2

            self.path = path
        }

        self.setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        // Drawing code
        super.draw(rect)

        if let backgroundImage = self.backgroundImage {
            backgroundImage.draw(in: rect)
        }
        if let fillImage = self.fillImage {
            DPAGColorProvider.shared[.attachmentDownloadProgressTint].setFill()
            fillImage.draw(in: rect)
        }

        if self.progressValue != 0 {
            DPAGColorProvider.shared[.attachmentDownloadProgressTint].setStroke()
            self.path.stroke()
        }
    }
}

class DPAGCellProgressViewLargeChannel: UIView {
    var fillImage: UIImage?
    fileprivate var backgroundImage: UIImage?

    var path = UIBezierPath()

    var progressValue: Double = 0

    override func awakeFromNib() {
        super.awakeFromNib()

        self.backgroundColor = .clear
        self.path = UIBezierPath()
        self.isUserInteractionEnabled = false
        self.progressValue = 0
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.backgroundImage = UIImage.circleImage(size: frame.size, colorFill: DPAGColorProvider.shared[.attachmentDownloadProgressBackground], colorBorder: nil)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        self.backgroundImage = UIImage.circleImage(size: frame.size, colorFill: DPAGColorProvider.shared[.attachmentDownloadProgressBackground], colorBorder: nil)
    }

    func setProgress(_ value: Double) {
        self.progressValue = value

        if value != 0 {
            let path = UIBezierPath(arcCenter: CGPoint(x: self.frame.size.width / 2, y: self.frame.size.height / 2), radius: (self.frame.size.width / 2) - 1, startAngle: CGFloat(-(Double.pi / 2)), endAngle: CGFloat((2 * Double.pi * value) - (Double.pi / 2)), clockwise: true)

            path.lineWidth = 2

            self.path = path
        }

        self.setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        // Drawing code
        super.draw(rect)

        if let backgroundImage = self.backgroundImage {
            backgroundImage.draw(in: rect)
        }
        if let fillImage = self.fillImage {
            DPAGColorProvider.shared[.attachmentDownloadProgressTint].setFill()
            fillImage.draw(in: rect)
        }

        if self.progressValue != 0 {
            DPAGColorProvider.shared[.attachmentDownloadProgressTint].setStroke()
            self.path.stroke()
        }
    }
}

class DPAGCellProgressView: UIView {
    fileprivate var path: UIBezierPath?
    fileprivate var pathBackground: UIBezierPath?

    fileprivate(set) var progressValue: Double = 0

    override func awakeFromNib() {
        super.awakeFromNib()

        self.backgroundColor = .clear
        self.isUserInteractionEnabled = false
        self.path = nil
        self.pathBackground = UIBezierPath(arcCenter: CGPoint(x: self.frame.size.width / 2, y: self.frame.size.height / 2), radius: ((self.frame.size.width * 5 / 8) / 2) - 2, startAngle: 0, endAngle: CGFloat(2 * Double.pi), clockwise: true)
        self.pathBackground?.lineWidth = 3
        self.progressValue = 0
    }

    func setProgress(_ value: Double) {
        self.progressValue = value

        if value != 0 {
            let path = UIBezierPath(arcCenter: CGPoint(x: self.frame.size.width / 2, y: self.frame.size.height / 2), radius: ((self.frame.size.width * 5 / 8) / 2) - 2, startAngle: CGFloat(-(Double.pi / 2)), endAngle: CGFloat((2 * Double.pi * value) - (Double.pi / 2)), clockwise: true)

            path.lineWidth = 3

            self.path = path
        }

        self.setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        // Drawing code
        super.draw(rect)

        DPAGColorProvider.shared[.attachmentDownloadProgressTint].setStroke()
        self.pathBackground?.stroke()

        if self.progressValue > 0, self.path != nil {
            DPAGColorProvider.shared[.attachmentDownloadProgressTint].setStroke()
            self.path?.stroke()
        }
    }
}
