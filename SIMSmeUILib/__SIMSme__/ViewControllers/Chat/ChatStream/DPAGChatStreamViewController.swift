//
//  DPAGChatStreamViewController.swift
// ginlo
//
//  Created by RBU on 10/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import AVFoundation
import SIMSmeCore
import UIKit

protocol DPAGChatStreamViewControllerProtocol {}

class DPAGChatStreamViewController: DPAGChatStreamBaseViewController, DPAGChatStreamViewControllerProtocol, DPAGSendingDelegate, UITableViewDataSource, UITableViewDelegate, DPAGNavigationViewControllerStyler {
    private var tempDeviceGuid: String?
    private var tempDevicePublicKey: String?
    private var hasTempDevice = false

    private weak var contactButton: DPAGBarButton?

    // Schreibt Status
    var lastSendRefDate: Date?
    var lastText: String?

    var lastOnlineState: String?
    var lastOnlineTime: String?
    var lastOnlineCheckTime: Date?
    var lastOnlineTryCheckTime: Date?
    var lastOnlineOooState: String?

    weak var navigationOnlineStatus: UILabel?
    var lastVisibleOnlineState: String?

    var showStatusAnimated = true

    var canUpdateOnlineState: Bool = false

    init(stream streamGuid: String, streamState: DPAGChatStreamState, startChatWithUnconfirmedContact isNewChatStreamWithUnconfirmedContact: Bool) {
        super.init(streamGuid: streamGuid, streamState: streamState)
        self.silentHelper.chatType = .single
        self.isNewChatStreamWithUnconfirmedContact = isNewChatStreamWithUnconfirmedContact

        self.sendingDelegate = self
    }

    convenience init(stream streamGuid: String, streamState: DPAGChatStreamState) {
        self.init(stream: streamGuid, streamState: streamState, startChatWithUnconfirmedContact: false)
    }

    override init(streamGuid: String, streamState: DPAGChatStreamState) {
        super.init(streamGuid: streamGuid, streamState: streamState)
        self.silentHelper.chatType = .single
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        NotificationCenter.default.addObserver(self, selector: #selector(contactChanged(_:)), name: DPAGStrings.Notification.Contact.CHANGED, object: nil)
        var colorConfidence: UIColor?
        var contactGuid: String?
        if let stream = DPAGApplicationFacade.cache.decryptedStream(streamGuid: self.streamGuid) as? DPAGDecryptedStreamPrivate, let contactGuidCache = stream.contactGuid, let contact = DPAGApplicationFacade.cache.contact(for: contactGuidCache) {
            contactGuid = contact.guid
            // TODO: Create Image
            if (contactGuid?.isSystemChatGuid ?? false) == false, contact.isDeleted == false {
                let contactButton = DPAGBarButton()
                contactButton.frame = CGRect(origin: .zero, size: DPAGImageProvider.kSizeBarButton)
                let imgContact = contact.image(for: .chat)
                if contact.isDeleted == false, let imgContact = imgContact {
                    contactButton.imageViewCentered.image = imgContact.circleImageUsingConfidenceColor(UIColor.confidenceStatusToColor(contact.confidence, isActive: true), thickness: 8)
                } else {
                    contactButton.imageViewCentered.image = imgContact
                }
                contactButton.tintColor = DPAGColorProvider.shared[.navigationBarTint]
                contactButton.addTarget(self, action: #selector(showDetailsForContactStream), for: .touchUpInside)
                let rightBarbuttonItem = UIBarButtonItem(customView: contactButton)
                rightBarbuttonItem.accessibilityLabel = DPAGLocalizedString("chat_details.accessibility.label")
                rightBarbuttonItem.accessibilityIdentifier = "chat_details"
                self.contactButton = contactButton
                self.rightBarButtonItem = rightBarbuttonItem
            }
            if contact.isDeleted == false {
                colorConfidence = UIColor.confidenceStatusToColor(contact.confidence)
            }
            if contact.isDeleted == true {
                self.wasDeleted = true
            }
        }
        self.setup()
        self.performBlockInBackground { [weak self] in
            self?.loadTitle()
        }
        if let colorConfidence = colorConfidence, colorConfidence != UIColor.clear {
            self.addConfidenceView()
        }
        if let contactGuid = contactGuid {
            self.performBlockInBackground {
                let withProfil = DPAGApplicationFacade.preferences.needsProfileSynchronization(forProfileGuid: contactGuid)
                DPAGApplicationFacade.updateKnownContactsWorker.getAccountInfo(accountGuid: contactGuid, withProfile: withProfil, withTempDevice: true) { responseObject, _, errorMessage in
                    if errorMessage == nil, let dictAccount = responseObject as? [String: Any], let dictAccountInfo = dictAccount[DPAGStrings.JSON.Account.OBJECT_KEY] as? [String: Any], let contactGuid = dictAccountInfo[DPAGStrings.JSON.Account.GUID] as? String {
                        if withProfil {
                            let notificationToSend = DPAGApplicationFacade.contactsWorker.updateContact(contactGuid: contactGuid, withAccountJson: dictAccountInfo)
                            DPAGApplicationFacade.preferences.setProfileSynchronizationDone(forProfileGuid: contactGuid)
                            if let notificationToSend = notificationToSend {
                                NotificationCenter.default.post(name: notificationToSend, object: nil)
                            }
                        }
                        if let tempDeviceGuid = dictAccountInfo["tempDeviceGuid"] as? String, let tempDevicePublicKey = dictAccountInfo["publicKeyTempDevice"] as? String, let pkSign256TempDevice = dictAccountInfo["pkSign256TempDevice"] as? String {
                            if let contact = DPAGApplicationFacade.cache.contact(for: contactGuid) {
                                // Signatur des Temp Devices prüfen
                                do {
                                    self.hasTempDevice = try CryptoHelperVerifier.verifyData256(data: tempDevicePublicKey, withSignature: pkSign256TempDevice, forPublicKey: contact.publicKey)
                                } catch {
                                    DPAGLog(error)
                                }
                                if self.hasTempDevice {
                                    self.tempDeviceGuid = tempDeviceGuid
                                    self.tempDevicePublicKey = tempDevicePublicKey
                                }
                            }
                        } else {
                            self.hasTempDevice = false
                        }
                        if let pushSilentTillStr = dictAccountInfo[DPAGStrings.JSON.Account.PUSH_SILENT_TILL] as? String {
                            self.silentHelper.currentSilentState = SetSilentHelper.silentStateFor(silentDate: DPAGFormatter.dateServer.date(from: pushSilentTillStr))
                        }
                    }
                }
            }
        }
    }

    override func onSilentStateChanged() {
        self.performBlockOnMainThread { [weak self] in
            self?.refreshContactButton()
        }
    }

    func refreshContactButton() {
        guard let contactButton = self.contactButton else { return }
        guard case SilentState.none = self.silentHelper.currentSilentState else {
            contactButton.imageViewCentered.image = DPAGImageProvider.shared[.kImageBarButtonNavContactSilent]
            contactButton.imageViewCentered.tintColor = DPAGColorProvider.shared[.muteActive]
            return
        }
        if let stream = DPAGApplicationFacade.cache.decryptedStream(streamGuid: self.streamGuid) as? DPAGDecryptedStreamPrivate, let contactGuidCache = stream.contactGuid, let contact = DPAGApplicationFacade.cache.contact(for: contactGuidCache) {
            let contactGuid: String? = contact.guid
            if (contactGuid?.isSystemChatGuid ?? false) == false, contact.isDeleted == false {
                contactButton.imageViewCentered.image = contact.image(for: .chat)
                contactButton.imageViewCentered.tintColor = DPAGColorProvider.shared[.navigationBarTint]
                return
            }
            
        }
        contactButton.imageViewCentered.image = DPAGImageProvider.shared[.kImageBarButtonNavContact]
        contactButton.imageViewCentered.tintColor = DPAGColorProvider.shared[.navigationBarTint]
    }

    func getOnlineText() -> String {
        // Wenn der Onlinestatus älter als 60 Sekunden sind, dann lieber nichts anzeigen
        if self.lastOnlineCheckTime?.addingMinutes(1).isInPast == true {
            return ""
        }
        if self.lastOnlineOooState == "ooo" {
            return DPAGLocalizedString("chat.onlineState.ooo")
        }
        if self.lastOnlineState == "writing" {
            return DPAGLocalizedString("chat.onlineState.writing")
        }
        if self.lastOnlineState == "online" {
            return DPAGLocalizedString("chat.onlineState.online")
        }
        if let lastOnlineTimeString = self.lastOnlineTime, let date = DPAGFormatter.dateServer.date(from: lastOnlineTimeString) {
            if date.isToday() {
                return String(format: DPAGLocalizedString("chat.onlineState.wasOnlineToday"), date.timeLabel)
            }
            if date.isYesterday() {
                return String(format: DPAGLocalizedString("chat.onlineState.wasOnlineYesterday"), date.timeLabel)
            }
            // weniger als eine Woche
            if date.addingDays(7).isInPast == false {
                return String(format: DPAGLocalizedString("chat.onlineState.wasOnlineLastWeek"), date.dateLabelWithoutYear)
            }
        }
        return ""
    }

    func loadTitle() {
        if let stream = DPAGApplicationFacade.cache.decryptedStream(streamGuid: self.streamGuid) as? DPAGDecryptedStreamPrivate, let contactGuidCache = stream.contactGuid, let contact = DPAGApplicationFacade.cache.contact(for: contactGuidCache) {
            let status = self.getOnlineText()
            self.lastVisibleOnlineState = status
            self.performBlockOnMainThread {
                self.title = contact.displayName
                if status.count == 0 {
                    self.navigationOnlineStatus?.text = ""
                    self.navigationOnlineStatus?.isHidden = true
                } else {
                    if self.showStatusAnimated {
                        self.showStatusAnimated = false
                        self.navigationOnlineStatus?.text = " "
                        self.navigationOnlineStatus?.alpha = 0.3
                        UIView.animate(withDuration: 0.3, animations: {
                            self.navigationOnlineStatus?.isHidden = false
                        }, completion: { _ in
                            UIView.animate(withDuration: 0.3, animations: {
                                self.navigationOnlineStatus?.text = status
                                self.navigationOnlineStatus?.alpha = 1.0
                            }, completion: nil)
                        })
                    } else {
                        self.navigationOnlineStatus?.text = status
                        self.navigationOnlineStatus?.alpha = 1.0
                        self.navigationOnlineStatus?.isHidden = false
                    }
                }
            }
        }
    }

    override func addActivityIndicator(identifier _: String) {
        // Keinen ActivityIndicator im Einzelchat wegen Online Status
    }

    override func removeActivityIndicator() {
        // Keinen ActivityIndicator im Einzelchat wegen Online Status
    }

    private var navBarLabelTitle: UILabel?
    private var navBarDetailLabel: UILabel?
    func configureNavBarWithDetail(_ labelTitle: UILabel, detailLabel: UILabel) -> UIView {
        labelTitle.accessibilityIdentifier = "navigationTitle"
        labelTitle.textAlignment = .center
        labelTitle.lineBreakMode = .byTruncatingMiddle
        labelTitle.textColor = self.navigationController?.navigationBar.tintColor ?? DPAGColorProvider.shared[.navigationBarTint]
        labelTitle.font = UIFont(descriptor: labelTitle.font.fontDescriptor.withSymbolicTraits(.traitBold) ?? labelTitle.font.fontDescriptor, size: labelTitle.font.pointSize)
        labelTitle.setContentCompressionResistancePriority(.required, for: .vertical)
        labelTitle.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        self.navBarLabelTitle = labelTitle
        detailLabel.accessibilityIdentifier = "onlineStatusTitle"
        detailLabel.textAlignment = .center
        detailLabel.lineBreakMode = .byTruncatingMiddle
        detailLabel.textColor = self.navigationController?.navigationBar.tintColor ?? DPAGColorProvider.shared[.navigationBarTint]
        detailLabel.font = UIFont(descriptor: labelTitle.font.fontDescriptor.withSymbolicTraits(.traitItalic) ?? labelTitle.font.fontDescriptor, size: 11.0)
        detailLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        detailLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        self.navBarDetailLabel = detailLabel
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.distribution = .equalSpacing
        stackView.alignment = .center
        stackView.spacing = 0
        stackView.addArrangedSubview(labelTitle)
        stackView.addArrangedSubview(detailLabel)
        stackView.translatesAutoresizingMaskIntoConstraints = true
        stackView.autoresizingMask = [.flexibleWidth]
        if let navigationBar = navigationController?.navigationBar {
			_ = stackView.widthAnchor.constraint(equalToConstant: navigationBar.frame.size.width - 40)
        }
        return stackView
    }

    override
    func handleDesignColorsUpdated() {
        super.handleDesignColorsUpdated()
        self.contactButton?.tintColor = DPAGColorProvider.shared[.navigationBarTint]
        if let rightBarButtonItems = self.navigationItem.rightBarButtonItems {
            for item in rightBarButtonItems {
                item.tintColor = DPAGColorProvider.shared[.navigationBarTint]
            }
        }
        self.navBarLabelTitle?.textColor = self.navigationController?.navigationBar.tintColor ?? DPAGColorProvider.shared[.navigationBarTint]
        self.navBarDetailLabel?.textColor = self.navigationController?.navigationBar.tintColor ?? DPAGColorProvider.shared[.navigationBarTint]
    }

    /// Called on viewWillAppear
    override func configureNavBar() {
        super.configureNavBar()
        let labelTitle = UILabel()
        let labelDesc = UILabel()
        self.navigationOnlineStatus = labelDesc
        self.navigationTitle = labelTitle
        // Wenn die Navigationbar neu gebaut wird ...
        self.navigationTitle?.text = self.title
        self.navigationOnlineStatus?.text = self.lastVisibleOnlineState
        self.navigationItem.titleView = self.configureNavBarWithDetail(labelTitle, detailLabel: labelDesc)
    }

    override func viewFirstAppear(_ animated: Bool) {
        super.viewFirstAppear(animated)
        if self.state != .write {
            self.updateInputStateAnimated(false, canShowAlert: false)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        var colorConfidence = UIColor.clear
        if let stream = DPAGApplicationFacade.cache.decryptedStream(streamGuid: self.streamGuid) as? DPAGDecryptedStreamPrivate, let contactGuidCache = stream.contactGuid, let contact = DPAGApplicationFacade.cache.contact(for: contactGuidCache) {
            self.title = contact.displayName
            self.navigationTitle?.text = contact.displayName
            if contact.isDeleted == false {
                self.performBlockInBackground {
                    let responseBlock: DPAGServiceResponseBlock = { [weak self] responseObject, _, errorMessage in
                        guard let strongSelf = self else { return }
                        if errorMessage != nil, errorMessage == "service.ERR-0007" {
                            DPAGApplicationFacade.contactsWorker.deleteContact(withStreamGuid: strongSelf.streamGuid)
                            strongSelf.performBlockOnMainThread { [weak self] in
                                self?.updateInputStateAnimated(true, forceDisabled: true)
                            }
                        } else if let dictResponse = responseObject as? [String: Any], let dictAccountInfo = dictResponse[DPAGStrings.JSON.Account.OBJECT_KEY] as? [String: Any], dictAccountInfo[DPAGStrings.JSON.Account.GUID] as? String != nil {
                            let readOnlyBefore = contact.isReadOnly
                            _ = DPAGApplicationFacade.contactsWorker.updateContact(contactGuid: contact.guid, withAccountJson: dictAccountInfo)
                            if readOnlyBefore != contact.isReadOnly {
                                self?.updateInputStateAnimated(true, forceDisabled: false)
                            }
                            let silentTillStr = dictAccountInfo[DPAGStrings.JSON.Account.PUSH_SILENT_TILL] as? String ?? ""
                            let silentTillDate = DPAGFormatter.dateServer.date(from: silentTillStr)
                            strongSelf.silentHelper.currentSilentState = SetSilentHelper.silentStateFor(silentDate: silentTillDate)
                            DPAGApplicationFacade.preferences.setProfileSynchronizationDone(forProfileGuid: contact.guid)
                        }
                    }
                    DPAGApplicationFacade.updateKnownContactsWorker.getAccountInfo(accountGuid: contact.guid, withProfile: true, withTempDevice: true, response: responseBlock)
                }
                colorConfidence = UIColor.confidenceStatusToColor(contact.confidence)
            }
        }
        self.transitionCoordinator?.animate(alongsideTransition: { [weak self] _ in
            if let strongSelf = self, let navigationController = strongSelf.navigationController as? (UINavigationController & DPAGNavigationControllerProtocol) {
                strongSelf.navigationSeparator?.backgroundColor = colorConfidence
                strongSelf.navigationProcessActivityIndicator?.color = navigationController.navigationBar.tintColor
                strongSelf.navigationProcessDescription?.textColor = navigationController.navigationBar.tintColor
                strongSelf.navigationTitle?.textColor = navigationController.navigationBar.tintColor
            }
        }, completion: { [weak self] context in
            guard let strongSelf = self else { return }
            if context.isCancelled == false {
                strongSelf.updateInputStateAnimated(animated, forceDisabled: false, forceEnabledIfNotConfirmed: strongSelf.isNewChatStreamWithUnconfirmedContact, canShowAlert: true)
            }
        })
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        var colorConfidence = UIColor.clear
        if let stream = DPAGApplicationFacade.cache.decryptedStream(streamGuid: self.streamGuid) as? DPAGDecryptedStreamPrivate, let contactGuidCache = stream.contactGuid, let contact = DPAGApplicationFacade.cache.contact(for: contactGuidCache), contact.isDeleted == false {
            colorConfidence = UIColor.confidenceStatusToColor(contact.confidence)
            if !self.wasDeleted, DPAGApplicationFacade.preferences.publicOnlineStateEnabled {
                self.canUpdateOnlineState = true
                self.perform(#selector(DPAGChatStreamViewController.updateOnlineState), with: nil, afterDelay: 0.1)
            }
        }
        if let navigationController = self.navigationController as? (UINavigationController & DPAGNavigationControllerProtocol) {
            self.navigationSeparator?.backgroundColor = colorConfidence
            self.navigationProcessActivityIndicator?.color = navigationController.navigationBar.tintColor
            self.navigationProcessDescription?.textColor = navigationController.navigationBar.tintColor
            self.navigationTitle?.textColor = navigationController.navigationBar.tintColor
        }
        if !self.wasDeleted, DPAGApplicationFacade.preferences.publicOnlineStateEnabled {
            self.canUpdateOnlineState = true
            self.perform(#selector(updateOnlineState), with: nil, afterDelay: 0.1)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.stopOnlineStateCheck()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            self?.navigationItem.rightBarButtonItem?.customView?.setNeedsLayout()
        })
    }

    override func appWillResignActive() {
        self.stopOnlineStateCheck()
        super.appWillResignActive()
    }

    override func appDidBecomeActive() {
        super.appDidBecomeActive()
        if !self.wasDeleted, DPAGApplicationFacade.preferences.publicOnlineStateEnabled {
            self.canUpdateOnlineState = true
            perform(#selector(DPAGChatStreamViewController.updateOnlineState), with: nil, afterDelay: 0.1)
        }
    }

    func stopOnlineStateCheck() {
        self.lastOnlineState = nil
        self.lastOnlineTime = nil
        self.lastOnlineTryCheckTime = nil
        self.navigationOnlineStatus?.isHidden = true
        self.canUpdateOnlineState = false
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(DPAGChatStreamViewController.updateOnlineState), object: nil)
    }

    @objc
    func contactChanged(_ aNotification: Notification) {
        if let contactGuid = aNotification.userInfo?[DPAGStrings.Notification.Contact.CHANGED__USERINFO_KEY__CONTACT_GUID] as? String {
            if let stream = DPAGApplicationFacade.cache.decryptedStream(streamGuid: self.streamGuid) as? DPAGDecryptedStreamPrivate, let contactGuidCache = stream.contactGuid, let contact = DPAGApplicationFacade.cache.contact(for: contactGuidCache) {
                if contactGuid == contact.guid {
                    self.imgCache.removeValue(forKey: contactGuid)
                    self.performBlockOnMainThread { [weak self] in
                        let colorConfidence = UIColor.confidenceStatusToColor(contact.confidence)
                        UIView.animate(withDuration: TimeInterval(UINavigationController.hideShowBarDuration), animations: { [weak self] in
                            self?.navigationSeparator?.backgroundColor = colorConfidence
                        })
                        self?.tableView.reloadData()
                        self?.title = contact.displayName
                        self?.navigationTitle?.text = contact.displayName
                        self?.updateInputStateAnimated(true)
                    }
                }
            }
        }
    }

    func getRecipients() -> [DPAGSendMessageRecipient] {
        var recipients: [DPAGSendMessageRecipient] = []
        if let contactGuid = (DPAGApplicationFacade.cache.decryptedStream(streamGuid: self.streamGuid) as? DPAGDecryptedStreamPrivate)?.contactGuid {
            let recipient = DPAGSendMessageRecipient(recipientGuid: contactGuid)
            if self.hasTempDevice {
                if let guid = self.tempDeviceGuid, let publickey = self.tempDevicePublicKey {
                    recipient.setTempDevice(guid: guid, publicKey: publickey)
                }
            }
            recipients = [recipient]
        }
        return recipients
    }

    func sendIsWriting() {
        self.performBlockInBackground { [weak self] in
            guard let strongSelf = self else { return }
            if let contactGuid = (DPAGApplicationFacade.cache.decryptedStream(streamGuid: strongSelf.streamGuid) as? DPAGDecryptedStreamPrivate)?.contactGuid {
                DPAGApplicationFacade.profileWorker.setIsWriting(accountGuid: contactGuid) { [weak self] _, errorCode, _ in
                    if errorCode == nil {
                        self?.lastSendRefDate = Date()
                    }
                }
            }
        }
    }

    func sendResetWriting() {
        self.performBlockInBackground { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.lastSendRefDate = nil
            if let contactGuid = (DPAGApplicationFacade.cache.decryptedStream(streamGuid: strongSelf.streamGuid) as? DPAGDecryptedStreamPrivate)?.contactGuid {
                DPAGApplicationFacade.profileWorker.resetIsWriting(accountGuid: contactGuid) { _, _, _ in
                }
            }
        }
    }

    override func inputContainerTextViewDidChange() {
        super.inputContainerTextViewDidChange()
        if !DPAGApplicationFacade.preferences.publicOnlineStateEnabled {
            return
        }
        if !(self.inputController?.textView?.isFirstResponder() ?? false) {
            return
        }
        let text = self.inputController?.textView?.text

        if self.lastText == text {
            return
        }
        let textEmpty = text?.isEmpty ?? true
        if textEmpty {
            if self.lastSendRefDate != nil, (self.lastSendRefDate?.timeIntervalSinceNow.isLess(than: -10.0) ?? false) == false {
                self.sendResetWriting()
                self.lastSendRefDate = nil
            }
            return
        }
        self.lastText = text
        if self.lastSendRefDate == nil {
            self.lastSendRefDate = Date()
            self.sendIsWriting()
        } else if (self.lastSendRefDate?.timeIntervalSinceNow.isLess(than: -10.0) ?? false) == true {
            self.lastSendRefDate = Date()
            self.sendIsWriting()
        }
    }

    @objc
    func updateOnlineState() {
        if self.canUpdateOnlineState == false {
            return
        }
        self.performBlockInBackground { [weak self] in
            guard let strongSelf = self else { return }
            if let lastOnlineCheckTime = strongSelf.lastOnlineCheckTime, let lastOnlineTryCheckTime = strongSelf.lastOnlineTryCheckTime, lastOnlineTryCheckTime.isLaterThan(date: lastOnlineCheckTime) == true, lastOnlineTryCheckTime.addingTimeInterval(30).isInPast == false {
                return
            }
            strongSelf.lastOnlineTryCheckTime = Date()
            if let contactGuid = (DPAGApplicationFacade.cache.decryptedStream(streamGuid: strongSelf.streamGuid) as? DPAGDecryptedStreamPrivate)?.contactGuid {
                DPAGApplicationFacade.profileWorker.getOnlineState(accountGuid: contactGuid, lastKnownState: strongSelf.lastOnlineState ?? "u") { [weak self] response, errorCode, _ in
                    guard let strongSelf = self else { return }
                    if strongSelf.canUpdateOnlineState == false {
                        return
                    }
                    strongSelf.lastOnlineCheckTime = Date()
                    if let newStateArr = response as? [[String: Any?]], let newState = newStateArr.first {
                        if let lastOnlineState = newState["state"] as? String {
                            strongSelf.lastOnlineState = lastOnlineState
                        }

                        if let lastOnline = newState["lastOnline"] as? String {
                            strongSelf.lastOnlineTime = lastOnline
                        }
                        if let oooStatus = newState["oooStatus"] as? [String: Any?], let oooStatusState = oooStatus["statusState"] as? String {
                            strongSelf.lastOnlineOooState = oooStatusState
                        }

                        strongSelf.performBlockOnMainThread { [weak self] in
                            self?.loadTitle()
                        }
                    }
                    if errorCode == nil {
                        strongSelf.performBlockOnMainThread { [weak self] in
                            self?.perform(#selector(DPAGChatStreamViewController.updateOnlineState), with: nil, afterDelay: 1)
                        }
                    } else {
                        strongSelf.performBlockOnMainThread { [weak self] in
                            self?.perform(#selector(DPAGChatStreamViewController.updateOnlineState), with: nil, afterDelay: 10)
                        }
                    }
                }
            }
        }
    }

    override func updateNewMessagesCountAndBadge() {
        self.updateNewMessagesCountAndBadge(-1)
    }

    override func handleMessageWasSent() {
        self.performBlockInBackground { [weak self] in
            guard let strongSelf = self else { return }
            guard let stream = DPAGApplicationFacade.cache.decryptedStream(streamGuid: strongSelf.streamGuid) as? DPAGDecryptedStreamPrivate, let contactGuidCache = stream.contactGuid, let contact = DPAGApplicationFacade.cache.contact(for: contactGuidCache) else { return }
            DPAGApplicationFacade.preferences.addLastRecentlyUsed(contacts: [contact])
        }
        super.handleMessageWasSent()
    }

    override func handleMessageSendFailed(_ errorMessage: String?) {
        super.handleMessageSendFailed(errorMessage)
        if errorMessage != nil, errorMessage == "service.ERR-0007" {
            DPAGApplicationFacade.contactsWorker.deleteContact(withStreamGuid: self.streamGuid)
            self.performBlockOnMainThread { [weak self] in
                self?.updateInputStateAnimated(true, forceDisabled: true)
            }
        }
    }

    @objc
    func showDetailsForContactStream() {
        let contactGuidWithDetails = (DPAGApplicationFacade.cache.decryptedStream(streamGuid: self.streamGuid) as? DPAGDecryptedStreamPrivate)?.contactGuid ?? "???"
        self.showDetailsForContact(contactGuidWithDetails)
    }

    override func openInfoForMessage(_ message: DPAGDecryptedMessage) {
        let nextVC = DPAGApplicationFacadeUI.messageReceiverInfoPrivateVC(decMessage: message, streamGuid: self.streamGuid, streamState: self.state)
        nextVC.sendingDelegate = self
        self.reloadOnAppear = true
        self.navigationController?.pushViewController(nextVC, animated: true)
    }

    func isEditingEnabled() -> Bool {
        var enabled = true
        if let contactGuid = (DPAGApplicationFacade.cache.decryptedStream(streamGuid: self.streamGuid) as? DPAGDecryptedStreamPrivate)?.contactGuid, let contact = DPAGApplicationFacade.cache.contact(for: contactGuid) {
            enabled = enabled && (contact.streamState == DPAGChatStreamState.write)
        }
        return enabled
    }
}
