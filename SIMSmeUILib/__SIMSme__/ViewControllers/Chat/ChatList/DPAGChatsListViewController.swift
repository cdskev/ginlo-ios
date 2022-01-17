//
//  DPAGChatsListViewController.swift
// ginlo
//
//  Created by RBU on 22/04/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData

import Sentry
import SIMSmeCore
import UIKit

public protocol DPAGChatsListViewControllerProtocol: DPAGTableViewControllerProtocol {
    var isModelLoaded: Bool { get }
    func scrollToStream(_ streamGuid: String)
    func bannerCancelled(animated: Bool)
    func showAVCallInvitation(forMessage messageGuid: String)
}

class DPAGChatsListViewController: DPAGTableViewControllerWithSearch, DPAGProgressHUDDelegate, DPAGChatsListSearchResultsViewDelegate, DPAGViewControllerNavigationTitleBig, DPAGChatsListViewControllerProtocol {
    enum Rows: Int {
        case new_SINGLE_CHAT = 0,
            new_GROUP_CHAT,
            subscribe_CHANNEL,
            subscribe_SERVICE,
            invite_FRIENDS,
            row_COUNT
    }

    static let ChatOverviewCellIdentifier = "ChatOverviewCell"
    static let ChatConfirmContactCellIdentifier = "ChatConfirmContactCell"
    static let GroupChatCellIdentifier = "GroupChatCell"
    static let GroupChatConfirmCellIdentifier = "GroupChatConfirmInvitationCell"
    static let ChannelCellIdentifier = "ChannelCell"
    static let ServiceCellIdentifier = "ServiceCell"
    static let SettingsCellHiddenIdentifier = "SettingsCellHidden"

    lazy var fetchedResultsController: DPAGFetchedResultsControllerChatList = DPAGFetchedResultsControllerChatList { [weak self] changes, streams in
        guard let strongSelf = self, strongSelf.isViewLoaded else {
            self?.queueSyncVars.sync(flags: .barrier) {
                self?.streams = streams
            }
            return
        }
        strongSelf.tableView.beginUpdates()
        strongSelf.queueSyncVars.sync(flags: .barrier) {
            strongSelf.streams = streams
        }
        for change in changes {
            if let changedRow = change as? DPAGFetchedResultsControllerRowChange {
                switch change.changeType {
                    case .insert:
                        strongSelf.tableView.insertRows(at: [changedRow.changedIndexPath], with: .automatic)
                    case .delete:
                        strongSelf.tableView.deleteRows(at: [changedRow.changedIndexPath], with: .automatic)
                    case .update:
                        strongSelf.tableView.reloadRows(at: [changedRow.changedIndexPath], with: .none)
                    case .move:
                        if let changedIndexPathMovedTo = changedRow.changedIndexPathMovedTo {
                            strongSelf.tableView.moveRow(at: changedRow.changedIndexPath, to: changedIndexPathMovedTo)
                        }
                    @unknown default:
                        DPAGLog("Switch with unknown value: \(change.changeType.rawValue)", level: .warning)
                }
            } else if let changedSection = change as? DPAGFetchedResultsControllerSectionChange {
                switch change.changeType {
                    case .insert:
                        strongSelf.tableView.insertSections(IndexSet(integer: changedSection.changedSection), with: .automatic)
                    case .delete:
                        strongSelf.tableView.deleteSections(IndexSet(integer: changedSection.changedSection), with: .automatic)
                    case .update:
                        strongSelf.tableView.reloadSections(IndexSet(integer: changedSection.changedSection), with: .none)
                    default:
                        break
                }
            }
        }
        strongSelf.tableView.endUpdates()
    }

    var isModelLoaded = false
    private var viewBanner: (UIView & DPAGChatListBannerViewProtocol)?
    private var constraintTopViewPromotion: NSLayoutConstraint?
    private var constraintBottomViewPromotion: NSLayoutConstraint?
    private var showContactsButton = true
    private var didCheckForCompanyEMailValidate = false
    private var didCheckForCompanyPhoneNumberValidate = false
    private var didCheckForCompanyEMailConfirm = false
    private var didCheckForCompanyPhoneNumberConfirm = false
    private var isPresentingAccountDeletion = false
    private var supressPromotionForSession = false
    private var observers: [NSObjectProtocol] = []
    var fileURLTemp: URL?
    // var fileURLZipTemp: NSURL?
    private var openInController: UIDocumentInteractionController?
    var openInControllerOpensApplication = false
    private(set) var streams: [String] = []
    private var navigationView: UIView?
    private var navigationProcessDescription: UILabel?
    private var navigationProcessActivityIndicator: UIActivityIndicatorView?
    private var navigationViewCompanyLogo: UIImageView?
    var loadingChatGuid: String?
    private var lastUpdateOnlineStateDate: Date?
    let queueSyncVars = DispatchQueue(label: "de.dpag.simsme.DPAGChatsListViewController.queueSyncVars", qos: .default, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil)
    private var startNewChatHelper = StartNewChatHelper()
    let conversationActionHelper = ConversationActionHelper()
    var lastSelectedStreamGuid: String?

    init() {
        super.init(style: .grouped)
        NotificationCenter.default.addObserver(self, selector: #selector(handleDesignLogoUpdated), name: DPAGStrings.Notification.Application.DESIGN_LOGO_UPDATED, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(menuShowChatstream(_:)), name: DPAGStrings.Notification.Menu.MENU_SHOW_CHATSTREAM, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(menuShowChats(_:)), name: DPAGStrings.Notification.Menu.MENU_SHOW_CHATS, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(menuShowSettings), name: DPAGStrings.Notification.Menu.MENU_SHOW_SETTINGS, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(menuShowAskAfterInstall), name: DPAGStrings.Notification.Menu.MENU_SHOW_EMAILADDRESS_ASK_AFTER_INSTALL, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleResetDates), name: DPAGStrings.Notification.Application.RESET_DATES, object: nil)
    }

    @objc
    private func menuShowAskAfterInstall(_: Notification) {
        let title = "settings.companyemail.askafterinstall"
        let message = "settings.companyemail.askafterinstall.hint"
        DPAGApplicationFacade.preferences.didAskForCompanyEmail = true
        let actionLater = UIAlertAction(titleIdentifier: "settings.companyemail.askafterinstall.later", style: .cancel, handler: nil)
        let actionNow = UIAlertAction(titleIdentifier: "settings.companyemail.askafterinstall.now", style: .default, handler: { _ in
            let nextVC = DPAGApplicationFacadeUISettings.profileVC()
            nextVC.skipToEmailValidationInit = true
            DPAGApplicationFacadeUIBase.containerVC.showTopMainViewController(nextVC, completion: nil)
        })
        self.presentAlert(alertConfig: AlertConfig(titleIdentifier: title, messageIdentifier: message, cancelButtonAction: actionLater, otherButtonActions: [actionNow]))
    }

    @objc
    private func menuShowChatstream(_ aNotification: Notification) {
      self.performBlockOnMainThread {
        if let streamGuid = aNotification.userInfo?[DPAGStrings.Notification.Menu.MENU_SHOW_CHATSTREAM__USERINFO_KEY__STREAM_GUID] as? String {
            DPAGChatHelper.openChatStreamView(streamGuid, navigationController: DPAGApplicationFacadeUIBase.containerVC.secondaryNavigationController, startChatWithUnconfirmedContact: aNotification.userInfo?[DPAGStrings.Notification.Menu.MENU_SHOW_CHATSTREAM__USERINFO_KEY__WITH_UNCONFIRMED_CONTACT] != nil, completion: { _ in
                DPAGProgressHUD.sharedInstance.hide(true)
            })
        }
      }
    }

    @objc
    private func menuShowChats(_ aNotification: Notification) {
        if let nextVC = aNotification.userInfo?[DPAGStrings.Notification.Menu.MENU_SHOW_CHATS__USERINFO_KEY__NEXT_VC] as? UIViewController {
            DPAGApplicationFacadeUIBase.containerVC.showTopMainViewController(self, addViewController: nextVC, completion: nil)
        } else if let contactGuid = aNotification.userInfo?[DPAGStrings.Notification.Menu.MENU_SHOW_CHATS__USERINFO_KEY__CONTACT_GUID] as? String {
            var nextVC: UIViewController & DPAGChatBaseViewControllerProtocol
            if let contact = DPAGApplicationFacade.cache.contact(for: contactGuid), let streamGuid = contact.streamGuid {
                // prepareCache
                _ = DPAGApplicationFacade.cache.decryptedStream(streamGuid: streamGuid, in: nil)
                let streamVC = DPAGApplicationFacadeUI.chatStreamVC(stream: streamGuid, streamState: contact.streamState)
                streamVC.fileToSend = aNotification.userInfo?[DPAGStrings.Notification.Menu.MENU_SHOW_CHATS__USERINFO_KEY__FILE_URL] as? URL
                streamVC.createModel()
                nextVC = streamVC
                DPAGApplicationFacade.preferences.setChatPrivateCreationAccount(contactGuid)
            } else {
                nextVC = DPAGApplicationFacadeUI.chatNoStreamVC(text: nil)
            }
            if let presentedViewController = self.presentedViewController {
                presentedViewController.dismiss(animated: true) {
                    DPAGApplicationFacadeUIBase.containerVC.pushSecondaryViewController(nextVC, animated: false)
                }
            } else {
                DPAGApplicationFacadeUIBase.containerVC.pushSecondaryViewController(nextVC, animated: false)
            }
        } else {
            if let presentedViewController = self.presentedViewController {
                presentedViewController.dismiss(animated: true) {
                    DPAGApplicationFacadeUIBase.containerVC.showTopMainViewController(self, animated: true, completion: nil)
                }
            } else {
                DPAGApplicationFacadeUIBase.containerVC.showTopMainViewController(self, animated: true, completion: nil)
            }
        }
    }

    @objc
    private func menuShowSettings() {
        let router = ApplicationRouter()
        let settingsViewController = DPAGApplicationFacadeUISettings.settingsVC(appRouter: router)
        DPAGApplicationFacadeUIBase.containerVC.pushMainViewController(settingsViewController, animated: true)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        for observer in self.observers {
            NotificationCenter.default.removeObserver(observer)
        }
        self.observers.removeAll()
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = DPAGLocalizedString("chats.title.chats")
        self.configureGui()
        self.startNewChatHelper.viewController = self
        self.startNewChatHelper.delegateNewGroup = self
    }

    private func getOwnAccountID() -> String? {
        guard let account = DPAGApplicationFacade.cache.account else {
            return nil
        }
        let contact = DPAGApplicationFacade.cache.contact(for: account.guid)
        return contact?.accountID
    }
    
    private func getOwnAVUserInfo() -> String? {
        guard let account = DPAGApplicationFacade.cache.account else { return nil }

        var avUserInfo: String? = ""
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

    func prepareChatStream(_ sguid: String?, completion: @escaping () -> Void) {
        guard let senderGuid = sguid else { return }
        if let contact = DPAGApplicationFacade.cache.contact(for: senderGuid), let streamGuid = contact.streamGuid, contact.isConfirmed {
            DPAGProgressHUD.sharedInstance.show(true) { [weak self] _ in
                DPAGSimsMeController.sharedInstance.dismissAllPresentedNavigationControllers(true, completionInBackground: true) { [weak self] in
                    // Thread.sleep(forTimeInterval: 1)
                    if contact.isDeleted { // Check if contact is really deleted (MELO-454)
                        self?.performBlockInBackground {
                            DPAGApplicationFacade.updateKnownContactsWorker.getAccountInfo(accountGuid: senderGuid, withProfile: true, withTempDevice: true) { _, _, errorMessage in
                                if errorMessage == nil {
                                    contact.setIsDeleted(false)
                                    DPAGApplicationFacade.contactsWorker.unDeleteContact(withContactGuid: senderGuid)
                                }
                                self?.performBlockOnMainThread {
                                    DPAGChatHelper.openChatStreamView(streamGuid, navigationController: self?.navigationController) { _ in
                                        DPAGProgressHUD.sharedInstance.hide(true)
                                        completion()
                                    }
                                }
                            }
                        }
                        return
                    }
                    self?.performBlockOnMainThread {
                        DPAGChatHelper.openChatStreamView(streamGuid, navigationController: self?.navigationController) { _ in
                            DPAGProgressHUD.sharedInstance.hide(true)
                            completion()
                        }
                    }
                }
            }
            return
        }
        if let group = DPAGApplicationFacade.cache.group(for: senderGuid), group.isConfirmed {
            DPAGProgressHUD.sharedInstance.show(true) { [weak self] _ in
                DPAGSimsMeController.sharedInstance.dismissAllPresentedNavigationControllers(true, completionInBackground: true) { [weak self] in
                    // Thread.sleep(forTimeInterval: 1)
                    self?.performBlockOnMainThread {
                        DPAGChatHelper.openChatStreamView(senderGuid, navigationController: self?.navigationController) { _ in
                            DPAGProgressHUD.sharedInstance.hide(true)
                            completion()
                        }
                    }
                }
            }
            return
        }
    }

    public func showAVCallInvitation(forMessage messageGuid: String) {
        // We don't want to disturb an ongoing call...
        // So, if we are already showing an AVCallViewController, don't do enaything...
        // otherwise show the invite, etc...
        if AVCallViewController.isInAVCall == false {
            var streamNameOrNil: String?
            var streamGuidOrNil: String?
            var presentGuid: String?
            let ptceOld = DPAGSimsMeController.sharedInstance.pushToChatEnabled
            if let message = DPAGApplicationFacade.cache.decryptedMessage(messageGuid: messageGuid) {
                // Because there is a timing issue when coming from a
                // Push notification, we want the app to actually NOT move to the
                // selected chat...
                DPAGSimsMeController.sharedInstance.pushToChatEnabled = false
                streamGuidOrNil = message.streamGuid
                if let decMessagePrivate = message as? DPAGDecryptedMessagePrivate, let contactGuid = decMessagePrivate.contactGuid, let contact = DPAGApplicationFacade.cache.contact(for: contactGuid) {
                    streamNameOrNil = contact.displayName
                    presentGuid = contactGuid
                } else if let messageGroup = message as? DPAGDecryptedMessageGroup, let streamGuid = messageGroup.streamGuid, let group = DPAGApplicationFacade.cache.group(for: streamGuid) {
                    presentGuid = streamGuid
                    if let contact = DPAGApplicationFacade.cache.contact(for: message.fromAccountGuid) {
                        streamNameOrNil = String(format: "%@@%@", contact.displayName, streamNameOrNil ?? "")
                    } else {
                        streamNameOrNil = group.name
                    }
                } else {
                    presentGuid = nil
                }
                if let roomInfo = message.content?.split(separator: "@"), roomInfo.count >= 3 {
                    let password = String(roomInfo[0])
                    let room = String(roomInfo[1])
                    let server = String(roomInfo[2])
                    let acceptAudioOption = AlertOption(title: DPAGLocalizedString("chat.button.avcall.acceptAudio"), style: .default, image: DPAGImageProvider.shared[.kPhone], textAlignment: CATextLayerAlignmentMode.center, accesibilityIdentifier: "chat.button.audioCall.accessibility.label", handler: { [weak self] in
                        guard let strongSelf = self else { return }
                        strongSelf.sendAVCallAcceptedMessage(room: room, password: password, server: server)
                        strongSelf.acceptAudioCall(room: room, password: password, server: server)
                    })
                    let acceptVideoOption = AlertOption(title: DPAGLocalizedString("chat.button.avcall.acceptVideo"), style: .default, image: DPAGImageProvider.shared[.kVideo], textAlignment: CATextLayerAlignmentMode.center, accesibilityIdentifier: "chat.button.videoCall.accessibility.label", handler: { [weak self] in
                        guard let strongSelf = self else { return }
                        strongSelf.sendAVCallAcceptedMessage(room: room, password: password, server: server)
                        strongSelf.acceptVideoCall(room: room, password: password, server: server)

                    })
                    let rejectOption = AlertOption(title: DPAGLocalizedString("res.cancel"), style: .cancel, textAlignment: CATextLayerAlignmentMode.center, handler: { [weak self] in
                        guard let strongSelf = self else { return }
                        strongSelf.sendAVCallRejectedMessage(room: room, password: password, server: server)
                        DPAGSimsMeController.sharedInstance.pushToChatEnabled = ptceOld
                    })
                    let options = [acceptAudioOption, acceptVideoOption, rejectOption]
                    let alertController = UIAlertController.controller(options: options.compactMap { $0 }, titleString: DPAGLocalizedString("chat.button.avcall.incomingcall") + " " + (streamNameOrNil ?? ""), withStyle: .alert)
                    if let streamGuidOrNil = streamGuidOrNil {
                        DPAGApplicationFacade.messageWorker.markStreamMessagesAsRead(streamGuid: streamGuidOrNil)
                    }
                    self.prepareChatStream(presentGuid) { [alertController] in
                        self.presentAlertController(alertController)
                    }
                } else {
                    DPAGSimsMeController.sharedInstance.pushToChatEnabled = ptceOld
                }
            }
        }
    }
    
    private func sendAVCallAcceptedMessage(room: String?, password: String?, server: String?) {
        self.performBlockOnMainThread {
            if let pvc = DPAGApplicationFacadeUIBase.containerVC.mainNavigationController.topViewController as? DPAGChatBaseViewControllerProtocol, let room = room, let password = password, let server = server {
                pvc.sendAVCallAccepted(room: room, password: password, server: server)
            }
        }
    }
    
    private func sendAVCallRejectedMessage(room: String?, password: String?, server: String?) {
        self.performBlockOnMainThread {
            if let pvc = DPAGApplicationFacadeUIBase.containerVC.mainNavigationController.topViewController as? DPAGChatBaseViewControllerProtocol, let room = room, let password = password, let server = server {
                pvc.sendAVCallRejected(room: room, password: password, server: server)
            }
        }
    }
    
    private func acceptAudioCall(room: String?, password: String?, server: String?) {
        joinAVCall(room: room, password: password, server: server, isVideo: false)
    }
    
    private func acceptVideoCall(room: String?, password: String?, server: String?) {
        joinAVCall(room: room, password: password, server: server, isVideo: true)
    }
    
    private func joinAVCall(room: String?, password: String?, server: String?, isVideo: Bool) {
        guard let room = room else { return }
        let vc = AVCallViewController(room: room, password: password ?? "", server: server ?? "", localUser: getOwnAVUserInfo(), isVideo: isVideo, isOutgoingCall: false)
        vc.modalTransitionStyle = .crossDissolve
        vc.modalPresentationStyle = .fullScreen
        topModalViewController.present(vc, animated: true)
    }

    @objc
    private func onDidBecomeActive(notification _: Notification) {
    }

    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)
        self.navigationController?.navigationBar.prefersLargeTitles = true
    }

    @objc
    private func appUIReadyWithPrivateKey() {
        if self.fetchedResultsController.fetchedResultsController?.delegate != nil {
            self.performBlockInBackground { [weak self] in
                Thread.sleep(forTimeInterval: 0.5)
                self?.performBlockOnMainThread {
                    DPAGSimsMeController.sharedInstance.checkForPush()
                }
            }
            DPAGApplicationFacadeUI.newMessageNotifier.initialReceivingCheckForNewMessages()
        }
    }

    private func appUIReadyWithPrivateKeyInternal() {
        if self.fetchedResultsController.fetchedResultsController?.delegate != nil {
            self.performBlockInBackground { [weak self] in
                Thread.sleep(forTimeInterval: 0.5)
                self?.performBlockOnMainThread {
                    DPAGSimsMeController.sharedInstance.checkForPush()
                }
            }
        }
    }

    private func createModel() {
        self.queueSyncVars.sync(flags: .barrier) {
            self.streams = self.fetchedResultsController.load()
        }
        self.appUIReadyWithPrivateKeyInternal()
        self.isModelLoaded = true
    }

    @objc
    private func reloadTableDataInBackground(_: Notification) {
        self.performBlockOnMainThread { [weak self] in
            self?.tableView.reloadData()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if UIDevice.current.userInterfaceIdiom != .pad {
            self.lastSelectedStreamGuid = nil
        }
        if self.observers.isEmpty {
            NotificationCenter.default.addObserver(self, selector: #selector(reloadTableDataInBackground(_:)), name: UIApplication.significantTimeChangeNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(reloadTableDataInBackground(_:)), name: DPAGStrings.Notification.ChatList.NEEDS_UPDATE, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(reloadTableDataInBackground(_:)), name: DPAGStrings.Notification.ChatStream.NEEDS_UPDATE, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(reloadTableDataInBackground(_:)), name: DPAGStrings.Notification.ChatStream.NEEDS_UPDATE, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(reloadTableDataInBackground(_:)), name: DPAGStrings.Notification.Group.CONFIDENCE_UPDATED, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(reloadTableDataInBackground(_:)), name: DPAGStrings.Notification.Contact.CHANGED, object: nil)
            var observer = NotificationCenter.default.addObserver(forName: DPAGStrings.Notification.Account.WAS_DELETED, object: nil, queue: .main) { [weak self] _ in
                self?.handleAccountDeleted()
            }
            self.observers.append(observer)
            observer = NotificationCenter.default.addObserver(forName: DPAGStrings.Notification.Application.UI_IS_READY_WITH_PRIVATE_KEY, object: nil, queue: .main) { [weak self] _ in
                self?.appUIReadyWithPrivateKey()
            }
            self.observers.append(observer)
            observer = NotificationCenter.default.addObserver(forName: DPAGStrings.Notification.Application.TEST_APPLICATION_DAYS_CHANGED, object: nil, queue: .main) { [weak self] _ in
                _ = self?.checkShowTestVoucherInfo()
            }
            self.observers.append(observer)
        }
        self.removeActivityIndicator()
        if DPAGApplicationFacadeUI.newMessageNotifier.isReceivingInitialMessagesProcessRunning {
            self.receivingMessagesStarted(nil)
        }

        NotificationCenter.default.addObserver(self, selector: #selector(receivingMessagesStarted(_:)), name: DPAGStrings.Notification.ReceivingNewMessages.STARTED, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(receivingMessagesFailed(_:)), name: DPAGStrings.Notification.ReceivingNewMessages.FAILED, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(receivingMessagesFinished(_:)), name: DPAGStrings.Notification.ReceivingNewMessages.FINISHED, object: nil)
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
        if self.isFirstAppearOfView {
            let viewSplash = UIView(frame: self.view.bounds)
            viewSplash.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            viewSplash.backgroundColor = self.view.backgroundColor
            self.view.addSubview(viewSplash)
            if let leftBarButtonItems = self.navigationItem.leftBarButtonItems {
                for btn in leftBarButtonItems {
                    btn.isEnabled = false
                }
            }
            if let rightBarButtonItems = self.navigationItem.rightBarButtonItems {
                for btn in rightBarButtonItems {
                    btn.isEnabled = false
                }
            }
            self.performBlockInBackground { [weak self] in
                guard let strongSelf = self else { return }
                DPAGApplicationFacadeUI.newMessageNotifier.initialReceivingCheckForNewMessages()
                strongSelf.createModel()
                strongSelf.performBlockOnMainThread { [weak self] in
                    if let strongSelf = self {
                        strongSelf.tableView.reloadData()
                        if let leftBarButtonItems = strongSelf.navigationItem.leftBarButtonItems {
                            for btn in leftBarButtonItems {
                                btn.isEnabled = true
                            }
                        }
                        if let rightBarButtonItems = strongSelf.navigationItem.rightBarButtonItems {
                            for btn in rightBarButtonItems {
                                btn.isEnabled = true
                            }
                        }
                        UIView.animate(withDuration: TimeInterval(UINavigationController.hideShowBarDuration), animations: {
                            viewSplash.alpha = 0
                        }, completion: { _ in
                            viewSplash.removeFromSuperview()
                        })
                    }
                }
            }
        }
        configureNavigationBarImageProfile()
        self.performBlockInBackground {
            DPAGSimsMeController.sharedInstance.syncConfigVersions()
        }
    }

    func setupHUD(_ hud: DPAGProgressHUDProtocol) {
        if let hudWithLabels = hud as? DPAGProgressHUDWithLabelProtocol {
            hudWithLabels.labelTitle.text = DPAGLocalizedString("chat.list.info.decrypting_data")
        }
    }

    @objc
    private func handleAccountDeleted() {
        if self.isPresentingAccountDeletion == false {
            self.isPresentingAccountDeletion = true
            let actionOK = UIAlertAction(titleIdentifier: "res.ok", style: .default, handler: { [weak self] _ in
                // Account loeschen
                NotificationCenter.default.post(name: DPAGStrings.Notification.Application.SECURITY_RESET_APP, object: nil)
                self?.isPresentingAccountDeletion = false
            })
            let alert = DPAGApplicationFacadeUIBase.containerVC.mainNavigationController.presentAlert(alertConfig: AlertConfig(titleIdentifier: "service.error499", otherButtonActions: [actionOK]))
            alert.appInBackgroundCompletion = { [weak self] in
                self?.isPresentingAccountDeletion = false
            }
        }
    }

    @objc
    private func handleResetDates() {
        self.lastUpdateOnlineStateDate = nil
    }

    override func filterContent(searchText: String, completion: @escaping DPAGCompletion) {
        var resultSingle: [DPAGDecryptedStream] = []
        var resultGroup: [DPAGDecryptedStream] = []
        var resultChannel: [DPAGDecryptedStream] = []
        for streamGuid in self.streams {
            let decStream: DPAGDecryptedStream? = DPAGApplicationFacade.cache.decryptedStream(streamGuid: streamGuid, in: nil)
            if let decStream = decStream {
                var bValid = false
                repeat {
                    if let privateStream = decStream as? DPAGDecryptedStreamPrivate {
                        if privateStream.isSystemChat {
                            bValid = true
                            break
                        }
                        if let contactGuid = privateStream.contactGuid, let contact = DPAGApplicationFacade.cache.contact(for: contactGuid) {
                            if contact.isConfirmed {
                                bValid = true
                                break
                            }
                        }
                    } else if let groupStream = decStream as? DPAGDecryptedStreamGroup, let group = DPAGApplicationFacade.cache.group(for: groupStream.guid) {
                        if group.isConfirmed {
                            bValid = true
                            break
                        }
                    } else if decStream is DPAGDecryptedStreamChannel {
                        bValid = true
                    }
                } while false
                if bValid, decStream.isSearchResult(searchText: searchText.lowercased()) {
                    switch decStream.type {
                    case .single:
                        resultSingle.append(decStream)
                    case .group:
                        resultGroup.append(decStream)
                    case .channel:
                        resultChannel.append(decStream)
                    default:
                        break
                    }
                }
            }
        }

        self.performBlockOnMainThread { [weak self] in
            (self?.searchResultsController as? DPAGChatsListViewSearchResultsViewControllerProtocol)?.setResult(searchText, filter: ["single": resultSingle, "group": resultGroup, "channel": resultChannel])
            completion()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if CryptoHelper.sharedInstance?.isPrivateKeyInMemory() ?? false {
            self.checkSendNickname()
            self.checkNeedConfirmCompanyAdressBook()
        }
        self.performBlockOnMainThread { [weak self] in
            self?.askForInvitation()
        }
        self.checkForBanner()
        self.checkForOwnOooStatus()
    }

    private func checkForBanner() {
        if DPAGApplicationFacade.preferences.isBaMandant {
            if AppConfig.applicationState() != .active {
                self.supressPromotionForSession = false
            }
            if self.checkShowTestVoucherInfo() {
                return
            }
        }
    }

    private func checkForOwnOooStatus() {
        self.performBlockOnMainThread {
            DPAGApplicationFacade.profileWorker.checkForOwnOooStatus { [weak self] in
                guard let strongSelf = self else { return }
                let title = "chatlist.oooStatus.title"
                let message = "chatlist.oooStatus.message"
                let actionOK = UIAlertAction(titleIdentifier: "chatlist.oooStatus.message.ok", style: .cancel, handler: { [weak self] _ in
                    let nextVC = DPAGApplicationFacadeUISettings.outOfOfficeStatusVC()
                    self?.present(DPAGApplicationFacadeUIBase.navVC(rootViewController: nextVC), animated: true, completion: nil)
                })
                strongSelf.presentAlert(alertConfig: AlertConfig(titleIdentifier: title, messageIdentifier: message, cancelButtonAction: actionOK, otherButtonActions: [UIAlertAction(titleIdentifier: "res.cancel", style: .default, handler: nil)]))
            }
        }
    }

    override func handleDesignColorsUpdated() {
        super.handleDesignColorsUpdated()
        (self.navigationController as? DPAGNavigationViewControllerStyler)?.configureNavigationWithStyle()
    }

    override func appWillEnterForeground() {
        super.appWillEnterForeground()
        self.checkForBanner()
    }

    private func setupBannerView(viewBanner: UIView & DPAGChatListBannerViewProtocol) {
        viewBanner.delegate = self
        viewBanner.translatesAutoresizingMaskIntoConstraints = false
        viewBanner.alpha = 0
        self.view.addSubview(viewBanner)
        let constraintTopViewPromotion = self.view.safeAreaLayoutGuide.topAnchor.constraint(equalTo: viewBanner.topAnchor)
        let constraintBottomViewPromotion = self.view.safeAreaLayoutGuide.topAnchor.constraint(equalTo: viewBanner.bottomAnchor)
        NSLayoutConstraint.activate([
            constraintBottomViewPromotion,
            self.view.constraintLeading(subview: viewBanner),
            self.view.constraintTrailing(subview: viewBanner)
        ])
        self.constraintTopViewPromotion = constraintTopViewPromotion
        self.constraintBottomViewPromotion = constraintBottomViewPromotion
        self.viewBanner = viewBanner
        self.view.setNeedsUpdateConstraints()
        self.view.layoutIfNeeded()
    }

    private func presentBannerView() {
        if let constraintBottomViewPromotion = self.constraintBottomViewPromotion {
            NSLayoutConstraint.deactivate([constraintBottomViewPromotion])
        }
        if let constraintTopViewPromotion = self.constraintTopViewPromotion {
            NSLayoutConstraint.activate([constraintTopViewPromotion])
        }

        UIView.animate(withDuration: TimeInterval(0.7), delay: 0, options: .allowUserInteraction, animations: { [weak self] in
            self?.viewBanner?.alpha = 1
            self?.view.layoutIfNeeded()
        })
    }

    private func dismissBannerView(animated: Bool = true, nilBanner: Bool = true) {
        if let constraintTopViewPromotion = self.constraintTopViewPromotion {
            NSLayoutConstraint.deactivate([constraintTopViewPromotion])
        }
        if let constraintBottomViewPromotion = constraintBottomViewPromotion {
            NSLayoutConstraint.activate([constraintBottomViewPromotion])
        }
        let banner = self.viewBanner
        if nilBanner {
            self.viewBanner = nil
        }
        if animated {
            UIView.animate(withDuration: TimeInterval(0.7), animations: { [weak self] in
                banner?.alpha = 0
                self?.view.layoutIfNeeded()
            }, completion: { _ in
                if nilBanner {
                    banner?.removeFromSuperview()
                }
            })
        } else {
            banner?.alpha = 0
            self.view.layoutIfNeeded()
            if nilBanner {
                banner?.removeFromSuperview()
            }
        }
    }

    private func checkShowTestVoucherInfo() -> Bool {
        if let daysLeft = Int(DPAGApplicationFacade.preferences.testLicenseDaysLeft() ?? "0") {
            if daysLeft > 0 && daysLeft < 30 {
                if self.supressPromotionForSession == false {
                    if self.viewBanner == nil {
                        self.setupBannerView(viewBanner: DPAGApplicationFacadeUI.viewChatListTestVoucher())
                    }
                    if let test = self.viewBanner as? DPAGChatListTestVoucherInfoViewProtocol {
                        test.updateText(daysLeft: daysLeft)
                    }
                    self.presentBannerView()
                    return true
                }
            } else if self.viewBanner != nil {
                self.bannerCancelled(animated: true)
            }
        }
        return false
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: DPAGStrings.Notification.ReceivingNewMessages.STARTED, object: nil)
        NotificationCenter.default.removeObserver(self, name: DPAGStrings.Notification.ReceivingNewMessages.FAILED, object: nil)
        NotificationCenter.default.removeObserver(self, name: DPAGStrings.Notification.ReceivingNewMessages.FINISHED, object: nil)
    }

    private func configureGui() {
        self.configureNavigationBar()
        self.configureSearchBar()
    }

    private func configureSearchBar() {
        self.configureSearchBarWithResultsController(DPAGApplicationFacadeUI.chatsListSearchResultsVC(delegate: self), placeholder: "android.serach.placeholder")
    }

    private func configureNavigationBarImageProfile() {
        guard let account = DPAGApplicationFacade.cache.account,
            let contact = DPAGApplicationFacade.cache.contact(for: account.guid),
            let image = contact.image(for: .barButtonSettings) else {
            return
        }
        setLeftBarButtonItem(image: image, action: #selector(menuShowSettings), accessibilityLabelIdentifier: "")
    }

    private func configureNavigationBar() {
        let navigationView = UIView()
        let navigationProcessDescription = UILabel()
        let navigationProcessActivityIndicator = UIActivityIndicatorView(style: .gray)
        _ = self.configureActivityIndicatorNavigationBarView(navBarView: navigationView, subLabel: navigationProcessDescription, subActivityIndicator: navigationProcessActivityIndicator)
        self.navigationView = navigationView
        self.navigationProcessDescription = navigationProcessDescription
        self.navigationProcessActivityIndicator = navigationProcessActivityIndicator
        self.navigationViewCompanyLogo = nil

        if DPAGApplicationFacade.preferences.isBaMandant, let companyLogoStr = DPAGApplicationFacade.preferences.companyLogo(), let companyLogoData = Data(base64Encoded: companyLogoStr, options: .ignoreUnknownCharacters), let companyLogo = UIImage(data: companyLogoData) {
            let imageViewCompanyLogo = UIImageView(image: companyLogo)
            imageViewCompanyLogo.frame.size.height = self.navigationController?.navigationBar.frame.height ?? 44
            imageViewCompanyLogo.autoresizingMask = [.flexibleHeight, .flexibleWidth]
            imageViewCompanyLogo.contentMode = .scaleAspectFit
            self.navigationViewCompanyLogo = imageViewCompanyLogo
//            self.navigationItem.titleView = imageViewCompanyLogo
        }
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: DPAGImageProvider.shared[.kImageBarButtonNavAdd], style: .plain, target: self, action: #selector(buttonAddPressed))
    }

    private func presentValidationVC(isModal: Bool, isPhone: Bool, isConfirmation: Bool) {
        let title: String
        let message: String
        let cancelTitle: String
        let okTitle: String
        if isConfirmation {
            title = isPhone ? "settings.companyPhoneNumber.askconfirm" : "settings.companyemail.askconfirm"
            message = isPhone ? "settings.companyPhoneNumber.askconfirm.hint" : "settings.companyemail.askconfirm.hint"
            okTitle = isPhone ? "settings.companyPhoneNumber.askconfirm.now" : "settings.companyemail.askconfirm.now"
            cancelTitle = isPhone ? "settings.companyPhoneNumber.askconfirm.later" : "settings.companyemail.askconfirm.later"
        } else {
            title = isPhone ? "settings.companyPhoneNumber.askvalidate" : "settings.companyemail.askvalidate"
            message = isPhone ? "settings.companyPhoneNumber.askvalidate.hint" : "settings.companyemail.askvalidate.hint"
            okTitle = isPhone ? "settings.companyPhoneNumber.askvalidate.now" : "settings.companyemail.askvalidate.now"
            cancelTitle = isPhone ? "settings.companyPhoneNumber.askvalidate.later" : "settings.companyemail.askvalidate.later"
        }
        let actionOK = UIAlertAction(titleIdentifier: okTitle, style: .default, handler: { _ in
            let nextVC = DPAGApplicationFacadeUISettings.profileVC()
            if isConfirmation {
                if isPhone {
                    nextVC.skipToPhoneNumberValidation = true
                } else {
                    nextVC.skipToEmailValidation = true
                }
            } else {
                if isPhone {
                    nextVC.skipToPhoneNumberValidationInit = true
                } else {
                    nextVC.skipToEmailValidationInit = true
                }
            }
            DPAGApplicationFacadeUIBase.containerVC.showTopMainViewController(nextVC, completion: nil)
        })
        if isModal {
            self.presentAlert(alertConfig: AlertConfig(titleIdentifier: title, messageIdentifier: message, otherButtonActions: [actionOK]))
        } else {
            let cancelButtonAction = UIAlertAction(titleIdentifier: cancelTitle, style: .cancel, handler: nil)
            self.presentAlert(alertConfig: AlertConfig(titleIdentifier: title, messageIdentifier: message, cancelButtonAction: cancelButtonAction, otherButtonActions: [actionOK]))
        }
    }

    func checkNeedConfirmCompanyAdressBook() {
        guard DPAGApplicationFacade.preferences.isCompanyAdressBookEnabled else { return }
        guard let account = DPAGApplicationFacade.cache.account else { return }
        if DPAGApplicationFacade.preferences.isCompanyManagedState {
            if DPAGApplicationFacade.preferences.validationEmailAddress != nil {
                self.presentValidationVC(isModal: true, isPhone: false, isConfirmation: account.companyEMailAddressStatus == .wait_CONFIRM)
            } else if DPAGApplicationFacade.preferences.validationPhoneNumber != nil {
                self.presentValidationVC(isModal: true, isPhone: true, isConfirmation: account.companyPhoneNumberStatus == .wait_CONFIRM)
            }
        } else {
            if self.didCheckForCompanyEMailConfirm == false, account.companyEMailAddressStatus == .wait_CONFIRM {
                self.didCheckForCompanyEMailConfirm = true
                self.presentValidationVC(isModal: false, isPhone: false, isConfirmation: true)
            } else if self.didCheckForCompanyPhoneNumberConfirm == false, account.companyPhoneNumberStatus == .wait_CONFIRM {
                self.didCheckForCompanyPhoneNumberConfirm = true
                self.presentValidationVC(isModal: false, isPhone: true, isConfirmation: true)
            }
        }
    }

    @objc
    private func handleDesignLogoUpdated() {
        self.performBlockOnMainThread { [weak self] in
            self?.configureNavigationBar()
            self?.setNeedsStatusBarAppearanceUpdate()
        }
    }

    @objc
    private func receivingMessagesStarted(_: Notification?) {
        self.addActivityIndicator(identifier: "refresh.loading.label")
    }

    @objc
    private func receivingMessagesFailed(_: Notification?) {
        self.removeActivityIndicator()
    }

    @objc
    private func receivingMessagesFinished(_: Notification?) {
        if DPAGApplicationFacadeUI.newMessageNotifier.isReceivingInitialMessagesProcessRunning == false {
            self.removeActivityIndicator()
        }
    }

    private func checkSendNickname() {
        if DPAGApplicationFacade.preferences[.kNotificationNicknameEnabled] == nil {
            let title = "settings.notification.nickname.notifications"
            let message = "settings.notification.nickname.notifications.hint"
            let actionSend = UIAlertAction(titleIdentifier: "settings.notification.nickname.notifications.send", style: .cancel, handler: { _ in
                DPAGApplicationFacade.preferences[.kNotificationNicknameEnabled] = DPAGPreferences.kValueNotificationEnabled
            })
            let actionDoNotSend = UIAlertAction(titleIdentifier: "settings.notification.nickname.notifications.notsend", style: .default, handler: { _ in
                DPAGApplicationFacade.preferences[.kNotificationNicknameEnabled] = DPAGPreferences.kValueNotificationDisabled
            })
            self.presentAlert(alertConfig: AlertConfig(titleIdentifier: title, messageIdentifier: message, cancelButtonAction: actionSend, otherButtonActions: [actionDoNotSend]))
        }
    }

    private func askForInvitation() {
        if DPAGApplicationFacade.preferences.showInviteFriends == false {
            return
        }
        if DPAGApplicationFacade.preferences.chatPrivateCreationCount > 1, DPAGApplicationFacade.preferences.shouldInviteFriendsAfterChatPrivateCreation {
            let title = "invite.friends.after.chatcreation.title"
            let message = "invite.friends.after.chatcreation.message"
            let actionCancel = UIAlertAction(titleIdentifier: "invite.friends.after.chatcreation.cancel", style: .cancel, handler: nil)
            let actionOK = UIAlertAction(titleIdentifier: "invite.friends.after.chatcreation.invite", style: .default, handler: { [weak self] _ in
                SharingHelper().showSharingForInvitation(fromViewController: self)
            })
            self.presentAlert(alertConfig: AlertConfig(titleIdentifier: title, messageIdentifier: message, cancelButtonAction: actionCancel, otherButtonActions: [actionOK]))
            DPAGApplicationFacade.preferences.shouldInviteFriendsAfterChatPrivateCreation = false
        }
    }

    private func addActivityIndicator(identifier: String) {
        guard self.navigationView != nil else { return }
        self.performBlockOnMainThread { [weak self] in
            self?.navigationProcessDescription?.text = DPAGLocalizedString(identifier)
            self?.navigationProcessActivityIndicator?.startAnimating()
            self?.navigationItem.titleView = self?.navigationView
        }
    }

    private func removeActivityIndicator() {
        guard self.navigationView != nil else { return }
        self.performBlockOnMainThread { [weak self] in
            self?.navigationProcessDescription?.text = ""
            self?.navigationProcessActivityIndicator?.stopAnimating()
            self?.navigationItem.titleView = self?.navigationViewCompanyLogo
            self?.title = DPAGLocalizedString("chats.title.chats")
        }
    }

    // MARK: - Actions
    
    @objc
    private func buttonAddPressed() {
        if let rightBarButton = self.navigationItem.rightBarButtonItem {
            let alertOptions = self.startNewChatHelper.getAlertOptions()
            self.startNewChatHelper.barButtonItem = rightBarButton
            let alertController = UIAlertController.controller(options: alertOptions, barButtonItem: rightBarButton)
            self.presentAlertController(alertController)
        }
    }

    // MARK: - table view overrides

    override func configureTableView() {
        super.configureTableView()
        self.tableView.register(DPAGApplicationFacadeUI.cellChatContactNib(), forCellReuseIdentifier: DPAGChatsListViewController.ChatOverviewCellIdentifier)
        self.tableView.register(DPAGApplicationFacadeUI.cellChatContactConfirmNib(), forCellReuseIdentifier: DPAGChatsListViewController.ChatConfirmContactCellIdentifier)
        self.tableView.register(DPAGApplicationFacadeUI.cellChatGroupNib(), forCellReuseIdentifier: DPAGChatsListViewController.GroupChatCellIdentifier)
        self.tableView.register(DPAGApplicationFacadeUI.cellChatGroupConfirmNib(), forCellReuseIdentifier: DPAGChatsListViewController.GroupChatConfirmCellIdentifier)
        self.tableView.register(DPAGApplicationFacadeUI.cellChannelNib(), forCellReuseIdentifier: DPAGChatsListViewController.ChannelCellIdentifier)
        self.tableView.register(DPAGApplicationFacadeUI.cellServiceNib(), forCellReuseIdentifier: DPAGChatsListViewController.ServiceCellIdentifier)
        self.tableView.register(DPAGApplicationFacadeUIViews.cellHiddenNib(), forCellReuseIdentifier: DPAGChatsListViewController.SettingsCellHiddenIdentifier)
        self.tableView.separatorInset = .zero
        self.tableView.layoutMargins = .zero
        self.tableView.estimatedRowHeight = 97
        self.tableView.accessibilityLabel = DPAGLocalizedString("chats.title.chats")
        self.tableView.isUserInteractionEnabled = self.showContactsButton
    }
}

extension DPAGChatsListViewController: DPAGNavigationViewControllerStyler {
    func configureNavigationWithStyle() {
        if let navigationController = self.navigationController as? (UINavigationController & DPAGNavigationControllerProtocol) {
            navigationController.resetNavigationBarStyle()
            self.navigationProcessActivityIndicator?.color = navigationController.navigationBar.tintColor
            self.navigationProcessActivityIndicator?.tintColor = navigationController.navigationBar.tintColor
            self.navigationProcessDescription?.textColor = navigationController.navigationBar.tintColor
            navigationController.navigationBar.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        }
    }
}

extension DPAGChatsListViewController: DPAGChatListBannerViewDelegate {
    func bannerSelected() {
        let bannerType = self.viewBanner?.bannerType ?? .unknown
        switch bannerType {
            case .business:
                if DPAGApplicationFacade.preferences.isBaMandant {
                    if let vc = DPAGApplicationFacade.preferences.viewControllerForIdent(DPAGWhiteLabelNextView.dpagLicenseInitViewController) {
                        if let validDateString = DPAGApplicationFacade.preferences.licenseValidDate() {
                            let dateValid = DPAGFormatter.dateServer.date(from: validDateString)
                            if let vcConsumer = vc as? DPAGLicencesInitConsumer {
                                vcConsumer.setDateValid(dateValid)
                            }
                        }
                        let nextVC = DPAGApplicationFacadeUIBase.navVC(rootViewController: vc)
                        AppConfig.appWindow()??.rootViewController?.present(nextVC, animated: true, completion: nil)
                    }
                }
            case .unknown:
                break
        }
        self.bannerCancelled(animated: true)
    }

    func bannerCancelled(animated: Bool) {
        let bannerType = self.viewBanner?.bannerType ?? .unknown
        switch bannerType {
            case .business:
                self.dismissBannerView(animated: animated, nilBanner: false)
                if DPAGApplicationFacade.preferences.isBaMandant {
                    self.supressPromotionForSession = true
                }
            case .unknown:
                break
        }
    }
}

protocol DPAGChatsListViewSearchResultsViewControllerProtocol: DPAGSearchResultsViewControllerProtocol {
    var searchDelegate: DPAGChatsListSearchResultsViewDelegate? { get }
    func setResult(_ searchText: String?, filter: [String: [DPAGDecryptedStream]])
}

class DPAGChatsListViewSearchResultsViewController: DPAGSearchResultsViewController, DPAGChatsListViewSearchResultsViewControllerProtocol {
    weak var searchDelegate: DPAGChatsListSearchResultsViewDelegate?
    private var result: [String: [DPAGDecryptedStream]] = [:]
    private var groups: [String] = []
    private var searchText: String?

    init(delegate: DPAGChatsListSearchResultsViewDelegate) {
        self.searchDelegate = delegate
        super.init(style: .grouped)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.register(DPAGApplicationFacadeUI.cellChatContactNib(), forCellReuseIdentifier: DPAGChatsListViewController.ChatOverviewCellIdentifier)
        self.tableView.register(DPAGApplicationFacadeUI.cellChatContactConfirmNib(), forCellReuseIdentifier: DPAGChatsListViewController.ChatConfirmContactCellIdentifier)
        self.tableView.register(DPAGApplicationFacadeUI.cellChatGroupNib(), forCellReuseIdentifier: DPAGChatsListViewController.GroupChatCellIdentifier)
        self.tableView.register(DPAGApplicationFacadeUI.cellChatGroupConfirmNib(), forCellReuseIdentifier: DPAGChatsListViewController.GroupChatConfirmCellIdentifier)
        self.tableView.register(DPAGApplicationFacadeUI.cellChannelNib(), forCellReuseIdentifier: DPAGChatsListViewController.ChannelCellIdentifier)
        self.tableView.register(DPAGApplicationFacadeUI.cellServiceNib(), forCellReuseIdentifier: DPAGChatsListViewController.ServiceCellIdentifier)
        self.tableView.register(DPAGApplicationFacadeUIViews.cellHiddenNib(), forCellReuseIdentifier: DPAGChatsListViewController.SettingsCellHiddenIdentifier)
        self.tableView.register(DPAGApplicationFacadeUIViews.tableHeaderGroupedNib(), forHeaderFooterViewReuseIdentifier: "headerIdentifier")
        self.tableView.separatorInset = .init(top: 16, left: 16, bottom: 6, right: 16)
        self.tableView.layoutMargins = .zero
        self.tableView.estimatedRowHeight = 97
        self.tableView.accessibilityLabel = DPAGLocalizedString("chats.title.chats")
        self.tableView.dataSource = self
        self.tableView.delegate = self
    }

    func setResult(_ searchText: String?, filter: [String: [DPAGDecryptedStream]]) {
        var groups: [String] = []
        for f in ["single", "group", "channel"] where (filter[f]?.count ?? 0) > 0 {
            groups.append(f)
        }
        self.groups = groups
        self.result = filter
        self.searchText = searchText
        self.tableView.reloadData()
    }
}

extension DPAGChatsListViewSearchResultsViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        self.groups.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == self.tableView {
            return self.result[self.groups[section]]?.count ?? 0
        }
        return 0
    }

    func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let stream = self.result[self.groups[indexPath.section]]?[indexPath.row] else {
            return UITableViewCell(style: .default, reuseIdentifier: "???")
        }
        if let rc = self.searchDelegate?.createCell(self.tableView, stream: stream, indexPath: indexPath, searchText: self.searchText) {
            return rc
        }
        return UITableViewCell(style: .default, reuseIdentifier: "???")
    }
}

extension DPAGChatsListViewSearchResultsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "headerIdentifier") as? (UITableViewHeaderFooterView & DPAGTableHeaderViewGroupedProtocol)
        let sectionName = self.groups[section]
        let sectionTitle: String
        if sectionName == "single" {
            sectionTitle = DPAGLocalizedString("chatlist.search.section.single")
        } else if sectionName == "group" {
            sectionTitle = DPAGLocalizedString("chatlist.search.section.group")
        } else {
            sectionTitle = DPAGLocalizedString("chatlist.search.section.channel")
        }
        headerView?.label.text = sectionTitle
        return headerView
    }

    func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }

    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // tableView.deselectRow(at: indexPath, animated: true)
        guard let stream = self.result[self.groups[indexPath.section]]?[indexPath.row] else { return }
        self.searchDelegate?.openStream(tableView, stream: stream, indexPath: indexPath)
    }
}
