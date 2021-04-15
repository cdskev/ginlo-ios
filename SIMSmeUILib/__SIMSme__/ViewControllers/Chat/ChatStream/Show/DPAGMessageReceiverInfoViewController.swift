//
//  DPAGMessageReceiverInfoViewController.swift
//  SIMSme
//
//  Created by RBU on 11/09/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

protocol DPAGMessageReceiverInfoViewControllerProtocol: DPAGChatCellBaseViewControllerProtocol {}

class DPAGMessageReceiverInfoViewController: DPAGChatCellBaseViewController, DPAGChatStreamInputVoiceViewControllerDelegate, DPAGMessageReceiverInfoViewControllerProtocol {
    fileprivate static let contactCellIdentifier = "InfoContactCell"
    fileprivate static let headerIdentifier = "headerIdentifier"

    let decMessage: DPAGDecryptedMessage

    init(decMessage: DPAGDecryptedMessage, streamGuid: String, streamState: DPAGChatStreamState) {
        self.decMessage = decMessage
        super.init(streamGuid: streamGuid, streamState: streamState)
        self.sendOptionsEnabled = false
        DPAGSendMessageViewOptions.sharedInstance.reset()
        DPAGSendMessageViewOptions.sharedInstance.messageGuidCitation = self.decMessage.messageGuid
        self.navigationItem.title = DPAGLocalizedString("chat.message.info.title")
        NotificationCenter.default.addObserver(self, selector: #selector(handleMessageMetaDataUpdated(_:)), name: DPAGStrings.Notification.Message.METADATA_UPDATED, object: nil)
    }

    deinit {
        DPAGSendMessageViewOptions.sharedInstance.messageGuidCitation = nil
        NotificationCenter.default.removeObserver(self)
    }

    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)
        if parent == nil {
            DPAGSendMessageViewOptions.sharedInstance.messageGuidCitation = nil
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if self.decMessage.messageType == .unknown {
            _ = self.navigationController?.popViewController(animated: true)
        }
    }

    override var inputContainerCitationEnabled: Bool {
        false
    }

    override func titleForSection(_ section: Int) -> String? {
        if section == 0, let messageDate = self.decMessage.messageDate {
            return DPAGFormatter.messageSectionDateRelativ.string(from: messageDate)
        }
        return nil
    }

    override func decryptedMessageForIndexPath(_: IndexPath, returnUnknownDecMessage _: Bool) -> DPAGDecryptedMessage? {
        self.decMessage
    }

    override func menuItemsForCell(_ cell: DPAGMessageCellProtocol) -> [UIMenuItem] {
        var retVal: [UIMenuItem] = []
        if cell.decryptedMessage.contentType == .avCallInvitation {
            retVal.append(UIMenuItem(title: DPAGLocalizedString("chat.message.action.rejoinAVCall"), action: #selector(rejoinAVCall)))
        }
        if cell.canPerformCopy() {
            retVal.append(UIMenuItem(title: DPAGLocalizedString("chat.message.action.copy"), action: #selector(copySelectedCell)))
        }
        retVal.append(UIMenuItem(title: DPAGLocalizedString("chat.message.action.delete"), action: #selector(deleteSelectedCell)))
        if cell.canPerformForward(), DPAGHelperEx.isNetworkReachable() {
            retVal.append(UIMenuItem(title: DPAGLocalizedString("chat.message.action.forward"), action: #selector(forwardSelectedCell)))
        }
        return retVal
    }

    override func tableView(_: UITableView, willDisplayHeaderView _: UIView, forSection _: Int) {}

    @objc
    func handleMessageMetaDataUpdated(_: Notification) {}

    override func pushToSendImageViewController(imageResource: DPAGMediaResource, mediaSourceType: DPAGSendObjectMediaSourceType, navigationController: UINavigationController?, enableMultiSelection _: Bool) {
        super.pushToSendImageViewController(imageResource: imageResource, mediaSourceType: mediaSourceType, navigationController: navigationController, enableMultiSelection: false)
    }

    override func pushToSendVideoViewController(videoResource: DPAGMediaResource, mediaSourceType: DPAGSendObjectMediaSourceType, navigationController: UINavigationController?, enableMultiSelection _: Bool) {
        super.pushToSendVideoViewController(videoResource: videoResource, mediaSourceType: mediaSourceType, navigationController: navigationController, enableMultiSelection: false)
    }

    override func inputContainerTextPlaceholder() -> String? {
        DPAGLocalizedString("chat.text.placeHolder.comment")
    }

    func inputContainerIsVoiceEnabled() -> Bool {
        false
    }

    override func isProximityMonitoringEnabled() -> Bool {
        false
    }

    override func sendTextWithWorker(_ text: String, sendMessageOptions sendOptions: DPAGSendMessageSendOptions?) {
        self.inputController?.textView?.resignFirstResponder()

        super.sendTextWithWorker(text, sendMessageOptions: sendOptions)
    }
}

protocol DPAGMessageReceiverInfoPrivateViewControllerProtocol: DPAGMessageReceiverInfoViewControllerProtocol {}

class DPAGMessageReceiverInfoPrivateViewController: DPAGMessageReceiverInfoViewController, DPAGMessageReceiverInfoPrivateViewControllerProtocol {
    enum Sections: Int, CaseCountable {
        case message, dates
    }

    var dateRead: Date?
    var dateDownloaded: Date?
    var dateSent: Date?
    var contactObject: DPAGContact?

    override init(decMessage: DPAGDecryptedMessage, streamGuid: String, streamState: DPAGChatStreamState) {
        super.init(decMessage: decMessage, streamGuid: streamGuid, streamState: streamState)
        self.showsInputController = false
        if DPAGApplicationFacade.preferences.isCommentingEnabled, streamState == .write, decMessage.isSelfDestructive == false {
            if let contactGuid = (DPAGApplicationFacade.cache.decryptedStream(streamGuid: streamGuid) as? DPAGDecryptedStreamPrivate)?.contactGuid, let contact = DPAGApplicationFacade.cache.contact(for: contactGuid) {
                self.showsInputController = (contact.streamState == .write)
            }
        }
        self.loadData()
    }

    override func handleMessageMetaDataUpdated(_ aNotification: Notification) {
        if let messageGuid = aNotification.userInfo?[DPAGStrings.Notification.Message.METADATA_UPDATED__USERINFO_KEY__MESSAGE_GUID] as? String {
            if messageGuid == self.decMessage.messageGuid {
                self.loadData()
                self.performBlockOnMainThread { [weak self] in
                    self?.tableView.reloadData()
                }
            }
        }
    }

    private func loadData() {
        if let receiver = self.decMessage.recipients.first, let contact = DPAGApplicationFacade.cache.contact(for: receiver.contactGuid) {
            self.contactObject = contact
            self.dateRead = receiver.dateRead
            self.dateDownloaded = receiver.dateDownloaded
        } else if let contact = DPAGApplicationFacade.cache.contact(for: self.decMessage.fromAccountGuid) {
            self.contactObject = contact
            self.dateRead = self.decMessage.dateReadLocal ?? self.decMessage.dateReadServer
            self.dateDownloaded = self.decMessage.dateDownloaded
        }
        self.dateSent = self.decMessage.dateSendServer ?? self.decMessage.dateSendLocal
    }

    func getRecipients() -> [String] {
        var recipients: [String] = []
        if let contactGuid = (DPAGApplicationFacade.cache.decryptedStream(streamGuid: self.streamGuid) as? DPAGDecryptedStreamPrivate)?.contactGuid {
            recipients = [contactGuid]
        }
        return recipients
    }

    override func configureTableView() {
        super.configureTableView()
        self.tableView.separatorStyle = .singleLine
        self.tableView.separatorColor = DPAGColorProvider.shared[.tableSeparator]
    }

    override func handleDesignColorsUpdated() {
        self.tableView.separatorColor = DPAGColorProvider.shared[.tableSeparator]
    }

    override func configureNavBar() {}

    override func indexPathForMessage(_: String) -> IndexPath? {
        IndexPath(row: 0, section: Sections.message.rawValue)
    }

    @objc(tableView:heightForRowAtIndexPath:)
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == Sections.message.rawValue {
            return super.tableView(tableView, heightForRowAt: indexPath)
        }
        return UITableView.automaticDimension
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == Sections.message.rawValue {
            return super.tableView(tableView, heightForHeaderInSection: section)
        }
        return 20
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == Sections.message.rawValue {
            return super.tableView(tableView, viewForHeaderInSection: section)
        }
        return nil
    }

    override func tableView(_: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
    }

    @objc(tableView:cellForRowAtIndexPath:)
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == Sections.message.rawValue {
            return super.tableView(tableView, cellForRowAt: indexPath)
        }
        var cell: UITableViewCell?
        cell = tableView.dequeueReusableCell(withIdentifier: DPAGMessageReceiverInfoViewController.contactCellIdentifier)
        if cell == nil {
            cell = UITableViewCell(style: .value1, reuseIdentifier: DPAGMessageReceiverInfoViewController.contactCellIdentifier)
            cell?.selectionStyle = .none
            cell?.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
            cell?.contentView.backgroundColor = UIColor.clear
        }
        var image: UIImage?
        var imageTintColor: UIColor?
        var title: String?
        var date: Date?
        let blockRead = {
            image = DPAGImageProvider.shared[.kImageSendStateRead]
            imageTintColor = DPAGColorProvider.shared[.imageSendStateReadTint]
            title = DPAGLocalizedString("settings.aboutSimsme.readLabel")
            date = self.dateRead
            cell?.accessibilityIdentifier = "dateRead"
        }
        let blockDownloaded = {
            image = DPAGImageProvider.shared[.kImageSendStateReceived]
            title = DPAGLocalizedString("settings.aboutSimsme.receivedLabel")
            date = self.dateDownloaded
            cell?.accessibilityIdentifier = "dateDownloaded"
        }
        let blockSent = {
            image = DPAGImageProvider.shared[.kImageSendStateSent]
            title = DPAGLocalizedString("settings.aboutSimsme.sentLabel")
            date = self.dateSent
            cell?.accessibilityIdentifier = "dateSent"
        }
        if indexPath.row == 0 {
            if self.dateRead != nil {
                blockRead()
            } else if self.dateDownloaded != nil {
                blockDownloaded()
            } else {
                blockSent()
            }
        } else if indexPath.row == 1 {
            if self.dateRead != nil {
                if self.dateDownloaded != nil {
                    blockDownloaded()
                } else {
                    blockSent()
                }
            } else {
                blockSent()
            }
        } else {
            blockSent()
        }
        let attachment = NSTextAttachment()
        attachment.image = image
        let info = NSMutableAttributedString()
        info.append(NSAttributedString(string: " "))
        info.append(NSAttributedString(attachment: attachment))
        if let tintColor = imageTintColor {
            info.addAttribute(.foregroundColor, value: tintColor, range: NSRange(location: 0, length: 2))
        }
        info.append(NSAttributedString(string: " "))
        info.append(NSAttributedString(string: title ?? "-", attributes: [.font: UIFont.kFontHeadline, .foregroundColor: DPAGColorProvider.shared[.labelText]]))
        cell?.textLabel?.attributedText = info
        if let date = date {
            let dateInfo = NSMutableAttributedString()
            dateInfo.append(NSAttributedString(string: DPAGFormatter.messageSectionDateRelativ.string(from: date), attributes: [.foregroundColor: DPAGColorProvider.shared[.labelText]]))
            dateInfo.append(NSAttributedString(string: " "))
            dateInfo.append(NSAttributedString(string: date.timeLabel, attributes: [.foregroundColor: DPAGColorProvider.shared[.labelText]]))
            cell?.detailTextLabel?.attributedText = dateInfo
        }
        return cell ?? super.tableView(tableView, cellForRowAt: indexPath)
    }
}

extension DPAGMessageReceiverInfoPrivateViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        Sections.caseCount
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Sections.forIndex(section) {
            case .message:
                return 1
            case .dates:
                return (self.dateRead != nil ? 1 : 0) + (self.dateDownloaded != nil ? 1 : 0) + (self.dateSent != nil ? 1 : 0)
        }
    }
}

extension DPAGMessageReceiverInfoPrivateViewController: UITableViewDelegate {}

protocol DPAGMessageReceiverInfoGroupViewControllerProtocol: DPAGMessageReceiverInfoViewControllerProtocol {}

class DPAGMessageReceiverInfoGroupViewController: DPAGMessageReceiverInfoViewController, DPAGMessageReceiverInfoGroupViewControllerProtocol {
    enum Sections: Int, CaseCountable {
        case message, read, download, sent
    }

    private struct ReceiverInfo {
        let receiverRead: [DPAGMessageRecipient]
        let receiverSent: [DPAGMessageRecipient]
        let receiverDownload: [DPAGMessageRecipient]
        let dateSent: Date?
    }

    var receiverRead: [DPAGMessageRecipient] = []
    var receiverDownload: [DPAGMessageRecipient] = []
    var receiverSent: [DPAGMessageRecipient] = []
    var dateSent: Date?

    override init(decMessage: DPAGDecryptedMessage, streamGuid: String, streamState: DPAGChatStreamState) {
        super.init(decMessage: decMessage, streamGuid: streamGuid, streamState: streamState)
        self.showsInputController = false
        if DPAGApplicationFacade.preferences.isCommentingEnabled, decMessage.isSelfDestructive == false {
            if let group = DPAGApplicationFacade.cache.group(for: streamGuid) {
                self.showsInputController = (group.streamState == .write)
            }
        }
        let receiverInfo = self.loadData()
        self.receiverRead = receiverInfo.receiverRead
        self.receiverSent = receiverInfo.receiverSent
        self.receiverDownload = receiverInfo.receiverDownload
        self.dateSent = receiverInfo.dateSent
    }

    override func handleMessageMetaDataUpdated(_ aNotification: Notification) {
        if let messageGuid = aNotification.userInfo?[DPAGStrings.Notification.Message.METADATA_UPDATED__USERINFO_KEY__MESSAGE_GUID] as? String {
            if messageGuid == self.decMessage.messageGuid {
                let receiverInfo = self.loadData()
                self.performBlockOnMainThread { [weak self] in
                    self?.receiverRead = receiverInfo.receiverRead
                    self?.receiverSent = receiverInfo.receiverSent
                    self?.receiverDownload = receiverInfo.receiverDownload
                    self?.dateSent = receiverInfo.dateSent
                    self?.tableView.reloadData()
                }
            }
        }
    }

    private func loadData() -> ReceiverInfo {
        var receiverRead: [DPAGMessageRecipient] = []
        var receiverSent: [DPAGMessageRecipient] = []
        var receiverDownload: [DPAGMessageRecipient] = []
        for receiver in self.decMessage.recipients {
            if let contact = DPAGApplicationFacade.cache.contact(for: receiver.contactGuid) {
                receiver.contact = contact

                if receiver.dateRead != nil {
                    receiverRead.append(receiver)
                } else if receiver.dateDownloaded != nil {
                    receiverDownload.append(receiver)
                } else {
                    receiverSent.append(receiver)
                }
            }
        }
        let receiverSort = { (rcv1: DPAGMessageRecipient, rcv2: DPAGMessageRecipient) -> Bool in
            if let displayName1 = rcv1.contact?.displayName {
                if let displayName2 = rcv2.contact?.displayName {
                    return displayName1 < displayName2
                }
                return false
            }
            return true
        }
        receiverRead.sort(by: receiverSort)
        receiverDownload.sort(by: receiverSort)
        receiverSent.sort(by: receiverSort)
        return ReceiverInfo(receiverRead: receiverRead, receiverSent: receiverSent, receiverDownload: receiverDownload, dateSent: self.decMessage.dateSendServer ?? self.decMessage.dateSendLocal)
    }

    func getRecipients() -> [String] {
        [self.streamGuid]
    }

    override func configureTableView() {
        super.configureTableView()
        self.tableView.register(DPAGApplicationFacadeUI.cellChatInfoContactNib(), forCellReuseIdentifier: DPAGMessageReceiverInfoViewController.contactCellIdentifier)
    }

    override func configureNavBar() {}

    override func indexPathForMessage(_: String) -> IndexPath? {
        IndexPath(row: 0, section: Sections.message.rawValue)
    }

    func translateSection(_ section: Sections) -> Sections {
        switch section {
            case .message:
                return section
            case .read:
                if self.receiverRead.count > 0 {
                    return section
                }
                if self.receiverDownload.count > 0 {
                    return .download
                }
                return .sent
            case .download:
                if self.receiverRead.count > 0 {
                    if self.receiverDownload.count > 0 {
                        return section
                    }
                    return .sent
                }
                if self.receiverDownload.count > 0 {
                    return .sent
                }
                return section
            case .sent:
                return section
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Sections.forIndex(indexPath.section) {
            case .message:
                return super.tableView(tableView, cellForRowAt: indexPath)
            default:
                if let cell = tableView.dequeueReusableCell(withIdentifier: DPAGMessageReceiverInfoViewController.contactCellIdentifier, for: indexPath) as? (UITableViewCell & DPAGChatInfoContactTableViewCellProtocol) {
                    let receiver: DPAGMessageRecipient
                    let date: Date?
                    switch self.translateSection(Sections.forIndex(indexPath.section)) {
                        case .read:
                            receiver = self.receiverRead[indexPath.row]
                            date = receiver.dateRead
                            cell.accessibilityIdentifier = "dateRead"
                        case .download:
                            receiver = self.receiverDownload[indexPath.row]
                            date = receiver.dateDownloaded
                            cell.accessibilityIdentifier = "dateDownloaded"
                        default:
                            receiver = self.receiverSent[indexPath.row]
                            date = self.dateSent
                            cell.accessibilityIdentifier = "dateSent"
                    }
                    cell.configureCell(withReceiver: receiver, date: date)
                    return cell
            }
            return super.tableView(tableView, cellForRowAt: indexPath)
        }
    }

    @objc(tableView:heightForRowAtIndexPath:)
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == Sections.message.rawValue {
            return super.tableView(tableView, heightForRowAt: indexPath)
        }
        return UITableView.automaticDimension
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == Sections.message.rawValue {
            return super.tableView(tableView, heightForHeaderInSection: section)
        }
        return 51
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == Sections.message.rawValue {
            return super.tableView(tableView, viewForHeaderInSection: section)
        }
        let headerView = UIView()
        let headerLabel = UILabel()
        headerView.backgroundColor = self.view.backgroundColor
        headerLabel.backgroundColor = UIColor.clear
        headerView.addSubview(headerLabel)
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        NSLayoutConstraint.activate([
            headerView.constraintTop(subview: headerLabel, padding: 20),
            headerView.constraintLeading(subview: headerLabel, padding: 15),
            headerView.constraintTrailing(subview: headerLabel, padding: 15),
            headerView.constraintBottom(subview: headerLabel, padding: 10)
        ])
        let image: UIImage?
        var imageTintColor: UIColor?
        let title: String
        switch self.translateSection(Sections.forIndex(section)) {
            case .read:
                image = DPAGImageProvider.shared[.kImageSendStateRead]
                imageTintColor = DPAGColorProvider.shared[.imageSendStateReadTint]
                title = DPAGLocalizedString("settings.aboutSimsme.readLabel")
                headerView.accessibilityIdentifier = "settings.aboutSimsme.readLabel"
            case .download:
                image = DPAGImageProvider.shared[.kImageSendStateReceived]
                title = DPAGLocalizedString("settings.aboutSimsme.receivedLabel")
                headerView.accessibilityIdentifier = "settings.aboutSimsme.receivedLabel"
            default:
                image = DPAGImageProvider.shared[.kImageSendStateSent]
                title = DPAGLocalizedString("settings.aboutSimsme.sentLabel")
                headerView.accessibilityIdentifier = "settings.aboutSimsme.sentLabel"
        }
        let attachment = NSTextAttachment()
        attachment.image = image
        let headerTitle = NSMutableAttributedString()
        headerTitle.append(NSAttributedString(string: " "))
        headerTitle.append(NSAttributedString(attachment: attachment))
        if let tintColor = imageTintColor {
            headerTitle.addAttribute(.foregroundColor, value: tintColor, range: NSRange(location: 0, length: 2))
        }
        headerTitle.append(NSAttributedString(string: " "))
        headerTitle.append(NSAttributedString(string: title, attributes: [.font: UIFont.kFontHeadline, .foregroundColor: DPAGColorProvider.shared[.labelText]]))
        headerLabel.attributedText = headerTitle
        return headerView
    }
}

extension DPAGMessageReceiverInfoGroupViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        Sections.caseCount - (self.receiverSent.count == 0 ? 1 : 0) - (self.receiverDownload.count == 0 ? 1 : 0) - (self.receiverRead.count == 0 ? 1 : 0)
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch self.translateSection(Sections.forIndex(section)) {
            case .message:
                return 1
            case .read:
                return self.receiverRead.count
            case .download:
                return self.receiverDownload.count
            case .sent:
                return self.receiverSent.count
        }
    }
}

extension DPAGMessageReceiverInfoGroupViewController: UITableViewDelegate
{
    
}
