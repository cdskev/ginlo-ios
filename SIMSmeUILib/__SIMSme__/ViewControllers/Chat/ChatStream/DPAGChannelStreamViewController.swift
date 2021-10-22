//
//  DPAGChannelStreamViewController.swift
// ginlo
//
//  Created by RBU on 11/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

extension DPAGChannelStreamViewController: DPAGNavigationViewControllerStyler {
    func configureNavigationWithStyle() {
        if let navigationController = self.navigationController, let colorBack = self.channelInfo.colorNavigationbar, let colorAction = self.channelInfo.colorNavigationbarAction, let colorText = self.channelInfo.colorNavigationbarText {
            navigationController.navigationBar.barTintColor = colorBack
            navigationController.navigationBar.tintColor = colorAction
            navigationController.navigationBar.titleTextAttributes = [.foregroundColor: colorText]
            navigationController.navigationBar.largeTitleTextAttributes = [.foregroundColor: colorText]
            self.navigationProcessActivityIndicator?.color = colorText
            self.navigationProcessDescription?.textColor = colorText
            self.navigationTitle?.textColor = colorText
        }
    }
}

class DPAGChannelStreamViewController: DPAGChatStreamBaseViewController, UITableViewDataSource, UITableViewDelegate {
    private static let TextMessageWithImagePreviewChannelLeftCellIdentifier = "TextMessageWithImagePreviewChannelLeftCell"
    private static let kLogoHeight: CGFloat = 90
    private let channelInfo: DPAGChannel
    private lazy var viewSettingsImage: UIImageView = UIImageView()
    private lazy var viewLogos: UIView = UIView()
    lazy var sizingCellLeftTextWithPreview: (UITableViewCell & DPAGTextMessageWithImagePreviewCellProtocol)? = { self.tableView.dequeueReusableCell(withIdentifier: DPAGChannelStreamViewController.TextMessageWithImagePreviewChannelLeftCellIdentifier) as? (UITableViewCell & DPAGTextMessageWithImagePreviewCellProtocol)
    }()

    init?(stream streamGuid: String, streamState: DPAGChatStreamState) {
        guard let channelInfoNew = DPAGApplicationFacade.cache.channel(for: streamGuid) else { return nil }
        self.channelInfo = channelInfoNew
        super.init(streamGuid: streamGuid, streamState: streamState)
        self.showsInputController = false
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.setRightBarButtonItem(image: DPAGImageProvider.shared[.kImageBarButtonSettings], action: #selector(handleToggleChannelSettings), accessibilityLabelIdentifier: "chat_details.accessibility.label")
        self.rightBarButtonItem = self.navigationItem.rightBarButtonItem
        self.setup()
        self.title = self.channelInfo.name_short
        let viewLogoFront = UIImageView()
        let viewLogoBack = UIImageView()
        self.viewLogos.translatesAutoresizingMaskIntoConstraints = false
        viewLogoFront.translatesAutoresizingMaskIntoConstraints = false
        viewLogoBack.translatesAutoresizingMaskIntoConstraints = false
        var constraints: [NSLayoutConstraint] = []
        constraints.append(self.viewLogos.constraintHeight(DPAGChannelStreamViewController.kLogoHeight))
        self.viewLogos.addSubview(viewLogoBack)
        self.viewLogos.addSubview(viewLogoFront)
        constraints.append(contentsOf: self.viewLogos.constraintsFill(subview: viewLogoBack))
        constraints.append(contentsOf: self.viewLogos.constraintsFill(subview: viewLogoFront))
        NSLayoutConstraint.activate(constraints)
        viewLogoFront.contentMode = .center
        viewLogoBack.contentMode = .scaleAspectFill
        viewLogoFront.clipsToBounds = true
        viewLogoBack.clipsToBounds = true
        let assetsList = DPAGApplicationFacade.feedWorker.assetsList(feedGuid: self.channelInfo.guid)
        var assetTypesMissing: [String] = []
        
        switch self.channelInfo.feedType {
            case .channel:
                viewLogoBack.backgroundColor = self.channelInfo.colorChatBackgroundLogo
                if viewLogoBack.backgroundColor == nil {
                    viewLogoBack.image = assetsList[.itemBackground] as? UIImage
                    if viewLogoBack.image == nil, assetsList.keys.contains(.itemBackground) == false {
                        assetTypesMissing.append("\(self.channelInfo.guid);\(DPAGChannel.AssetType.itemBackground.rawValue)")
                    }
                }
        }
        viewLogoFront.image = assetsList[.itemForeground] as? UIImage
        if viewLogoFront.image == nil, assetsList.keys.contains(.itemForeground) == false {
            assetTypesMissing.append("\(self.channelInfo.guid);\(DPAGChannel.AssetType.itemForeground.rawValue)")
        }
        if assetTypesMissing.count > 0 {
            let feedType = self.channelInfo.feedType
            self.performBlockInBackground {
                DPAGApplicationFacade.feedWorker.updateFeedAssets(feedGuids: [self.channelInfo.guid], feedAssetIdentifier: assetTypesMissing, feedType: feedType) { [weak self] in
                    self?.performBlockOnMainThread { [weak self] in
                        guard let strongSelf = self else { return }
                        let assetsList = DPAGApplicationFacade.feedWorker.assetsList(feedGuid: strongSelf.channelInfo.guid)
                        switch feedType {
                            case .channel:
                                if viewLogoBack.backgroundColor == nil {
                                    viewLogoBack.image = assetsList[.itemBackground] as? UIImage
                                }
                        }
                        viewLogoFront.image = assetsList[.itemForeground] as? UIImage
                    }
                }
            }
        }
        self.stackViewTableView?.insertArrangedSubview(self.viewLogos, at: 0)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.updateInputStateAnimated(false)
        self.transitionCoordinator?.animate(alongsideTransition: { [weak self] _ in
            self?.setNeedsStatusBarAppearanceUpdate()
        }, completion: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func shouldAddVoipButtons() -> Bool {
        false
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        if let color = self.channelInfo.colorNavigationbarText, let backgroundColor = self.channelInfo.colorNavigationbar {
            return color.statusBarStyle(backgroundColor: backgroundColor)
        }
        return super.preferredStatusBarStyle
    }

    func getRecipients() -> [String] {
        [self.streamGuid]
    }

    override func updateNewMessagesCountAndBadge() {
        self.updateNewMessagesCountAndBadge(-1)
    }

    override func nibForSimpleMessageLeft() -> UINib {
        switch self.channelInfo.feedType {
            case .channel:
                return DPAGApplicationFacadeUI.cellMessageSimpleChannelLeftNib()
        }
    }

    override func nibForImageMessageLeft() -> UINib {
        DPAGApplicationFacadeUI.cellMessageImageChannelLeftNib()
    }

    override func configureTableView() {
        super.configureTableView()
        self.tableView.register(DPAGApplicationFacadeUI.cellMessageTextWithImagePreviewChannelLeftNib(), forCellReuseIdentifier: DPAGChannelStreamViewController.TextMessageWithImagePreviewChannelLeftCellIdentifier)
    }

    @objc
    private func handleToggleChannelSettings() {
        self.getAlertOptions(channelInfo: self.channelInfo) {
            let alertController = UIAlertController.controller(options: $0, withStyle: .actionSheet, barButtonItem: self.rightBarButtonItem)
            DispatchQueue.main.async {
                self.presentAlertController(alertController)
            }
        }
    }

    override
    func handleDesignColorsUpdated() {
        super.handleDesignColorsUpdated()
        setChatBackground()
        let assetsChat = DPAGApplicationFacade.feedWorker.assetsChat(feedGuid: self.channelInfo.guid)
        (self.tableView.backgroundView as? UIImageView)?.image = assetsChat[.chatBackground] as? UIImage
    }

    private func handleReplyChannel() {
        if let phoneNumber = self.channelInfo.feedbackContactPhoneNumber, phoneNumber.isEmpty == false {
            if let streamGuid = DPAGApplicationFacade.contactsWorker.findContactStream(forPhoneNumbers: [phoneNumber]) {
                DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { [weak self] _ in
                    if let strongSelf = self {
                        DPAGChatHelper.openChatStreamView(streamGuid, navigationController: strongSelf.navigationController, startChatWithUnconfirmedContact: true) { _ in
                            DPAGProgressHUD.sharedInstance.hide(true)
                        }
                    }
                }
            } else {
                DPAGApplicationFacade.feedWorker.checkFeedbackContactPhoneNumber(feedbackContactPhoneNumber: phoneNumber, feedbackContactNickname: self.channelInfo.feedbackContactNickname)
            }
        }
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, createCellForTextMessageWithImagePreview _: DPAGDecryptedMessage, forIndexPath indexPath: IndexPath) -> UITableViewCell {
        tableView.dequeueReusableCell(withIdentifier: DPAGChannelStreamViewController.TextMessageWithImagePreviewChannelLeftCellIdentifier, for: indexPath)
    }

    func createHeightCellForTextMessageWithImagePreview(_: DPAGDecryptedMessage) -> UITableViewCell? {
        self.sizingCellLeftTextWithPreview
    }

    func tableView(_ tableView: UITableView, cellForTextMessageWithImagePreview decMessage: DPAGDecryptedMessage, forIndexPath indexPath: IndexPath) -> UITableViewCell {
        self.tableView(tableView, createCellForTextMessageWithImagePreview: decMessage, forIndexPath: indexPath)
    }

    func cellForHeightForTextMessageWithImagePreview(_ decMessage: DPAGDecryptedMessage) -> UITableViewCell? {
        self.createHeightCellForTextMessageWithImagePreview(decMessage)
    }

    override func tableView(_: UITableView, cellForSimpleTextMessage decMessage: DPAGDecryptedMessage, forIndexPath indexPath: IndexPath) -> UITableViewCell {
        if decMessage.imagePreview != nil {
            return self.tableView(tableView, cellForTextMessageWithImagePreview: decMessage, forIndexPath: indexPath)
        }

        return super.tableView(tableView, cellForSimpleTextMessage: decMessage, forIndexPath: indexPath)
    }

    override func cellForHeightForSimpleTextMessage(_ decMessage: DPAGDecryptedMessage) -> (UITableViewCell & DPAGMessageCellProtocol)? {
        if decMessage.imagePreview != nil {
            return self.cellForHeightForTextMessageWithImagePreview(decMessage) as? (UITableViewCell & DPAGMessageCellProtocol) ?? super.cellForHeightForSimpleTextMessage(decMessage)
        }
        return super.cellForHeightForSimpleTextMessage(decMessage)
    }

    override func setUpInvisibleScreen() {}

    override func setChatBackground() {
        if self.tableView.backgroundView == nil {
            self.tableView.backgroundView = UIImageView(frame: self.tableView.bounds)
            self.tableView.backgroundView?.contentMode = .scaleAspectFill
        }
        self.tableView.backgroundView?.backgroundColor = self.channelInfo.colorChatBackground
        if self.tableView.backgroundView?.backgroundColor == nil {
            let assetsChat = DPAGApplicationFacade.feedWorker.assetsChat(feedGuid: self.channelInfo.guid)
            (self.tableView.backgroundView as? UIImageView)?.image = assetsChat[.chatBackground] as? UIImage
        } else if self.channelInfo.colorChatBackground == DPAGColorProvider.shared[.chatDetailsBubbleChannel] {
            self.tableView.backgroundView?.backgroundColor = DPAGColorProvider.shared[.chatDetailsBackground2]
        }
    }
}

extension DPAGChannelStreamViewController {
    private func getAlertOptions(channelInfo: DPAGChannel, completion: @escaping ([AlertOption]) -> Void) {
        if channelInfo.isDeleted {
            completion([self.optionUnsubscribe(destructive: false), self.optionCancel()])
        }
        var alertOptions = [self.optionInfo(), self.optionRecommend()]
        AppConfig.currentUserNotificationSettings { settings in
            if settings != nil, let optionNotification = self.optionNotification(channelInfo) {
                alertOptions.append(optionNotification)
            }
            if channelInfo.isMandatory == false {
                alertOptions.append(self.optionUnsubscribe())
            }
            alertOptions.append(self.optionCancel())
            completion(alertOptions)
        }
    }

    private func optionInfo() -> AlertOption {
        AlertOption(title: DPAGLocalizedString("channel.settings.menu.title.info"), style: .default, image: DPAGImageProvider.shared[.kImageChannelInfo], textAlignment: CATextLayerAlignmentMode.left, accesibilityIdentifier: "channel.settings.menu.title.info", handler: self.showDetails)
    }

    private func optionRecommend() -> AlertOption {
        AlertOption(title: DPAGLocalizedString("channel.settings.menu.title.recommend"), style: .default, image: DPAGImageProvider.shared[.kImageChannelLike], textAlignment: CATextLayerAlignmentMode.left, accesibilityIdentifier: "channel.settings.menu.title.recommend", handler: self.handleRecommend)
    }

    private func optionNotification(_ channelInfo: DPAGChannel) -> AlertOption? {
        let settingKey: String
        let settingKeyGlobal: DPAGPreferences.PropString
        switch channelInfo.feedType {
            case .channel:
                settingKey = String(format: "%@-%@", channelInfo.guid, DPAGPreferences.PropString.kNotificationChannelChatEnabled.rawValue)
                settingKeyGlobal = .kNotificationChannelChatEnabled
        }
        let channelNotficationSettingGlobal = DPAGApplicationFacade.preferences[settingKeyGlobal]
        let channelNotficationSettingGlobalIsON = channelNotficationSettingGlobal != DPAGPreferences.kValueNotificationDisabled
        if !channelNotficationSettingGlobalIsON {
            return nil
        }
        let channelNotficationSetting = DPAGApplicationFacade.preferences[settingKey] as? String
        let channelNotficationSettingIsON = channelNotficationSetting != DPAGPreferences.kValueNotificationDisabled
        if channelNotficationSettingIsON {
            return AlertOption(title: DPAGLocalizedString("channel.settings.menu.title.soundsOn"), style: .default, image: DPAGImageProvider.shared[.kImageChannelSoundsOn], textAlignment: CATextLayerAlignmentMode.left, accesibilityIdentifier: "channel.settings.menu.title.soundsOn", handler: self.handleSetNotificationsOff)
        }
        return AlertOption(title: DPAGLocalizedString("channel.settings.menu.title.soundsOff"), style: .default, image: DPAGImageProvider.shared[.kImageChannelSoundsOff], textAlignment: CATextLayerAlignmentMode.left, accesibilityIdentifier: "channel.settings.menu.title.soundsOff", handler: self.handleSetNotificationsOn)
    }

    private func optionUnsubscribe(destructive: Bool = true) -> AlertOption {
        let alertOptionStyle: UIAlertAction.Style = destructive ? .destructive : .default
        return AlertOption(title: DPAGLocalizedString("channel.settings.menu.title.unsubscribe"), style: alertOptionStyle, image: DPAGImageProvider.shared[.kImageChannelStorno], textAlignment: CATextLayerAlignmentMode.left, accesibilityIdentifier: "channel.settings.menu.title.unsubscribe", handler: self.handleUnsubscribe)
    }

    private func optionCancel() -> AlertOption {
        AlertOption(title: DPAGLocalizedString("res.cancel"), style: .cancel, accesibilityIdentifier: "channel.settings.menu.cancel")
    }

    fileprivate func showDetails() {
        if self.channelInfo.feedType == .channel {
            self.showDetailsForChannel(self.channelInfo.guid)
        }
    }

    fileprivate func handleRecommend() {
        var recommendationText = self.channelInfo.recommendationText ?? ""
        if recommendationText.isEmpty {
            let recommendationFormat = DPAGLocalizedString("channel.settings.recommandation.default")
            recommendationText = String(format: recommendationFormat, self.channelInfo.name_short ?? "", DPAGApplicationFacade.preferences.urlScheme ?? "", self.channelInfo.name_short?.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? "")
        }
        let viewControllers = DPAGApplicationFacadeUI.urlHandler.handleCreateMessage([DPAGStrings.URLHandler.KEY_MESSAGE_TEXT: recommendationText])
        if viewControllers.count > 0 {
            DPAGApplicationFacadeUIBase.containerVC.secondaryNavigationController.setViewControllers(viewControllers, animated: true)
        }
    }

    fileprivate func handleSetNotificationsOff() {
        self.handleSetNotificationsEnabled(false)
    }

    fileprivate func handleSetNotificationsOn() {
        self.handleSetNotificationsEnabled(true)
    }

    private func handleSetNotificationsEnabled(_ enabled: Bool) {
        let channelGuid = self.channelInfo.guid
        let feedType = self.channelInfo.feedType
        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in
            let responseBlock: DPAGServiceResponseBlock = { _, _, errorMessage in
                DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                    if let errorMessage = errorMessage {
                        self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
                    }
                }
            }
            DPAGApplicationFacade.feedWorker.setFeedNotification(enabled: enabled, feedGuid: channelGuid, feedType: feedType, withResponse: responseBlock)
        }
    }

    fileprivate func handleUnsubscribe() {
        let alertTitleId = self.channelInfo.serviceID != nil ? "channel_details.action.unsubscribe_service" : "channel_details.action.unsubscribe"
        let alertMessageId = self.channelInfo.serviceID != nil ? "channel_details.action.unsubcribe_service.title" : "channel_details.action.unsubcribe.title"
        let cancelAction = UIAlertAction(titleIdentifier: "common.button.no", style: .cancel, handler: nil, accessibilityIdentifier: "channel_details.action.unsubcribe.cancel")
        let okAction = UIAlertAction(titleIdentifier: "common.button.yes", style: .default, handler: { [weak self] _ in
            self?.unsubscribeChannel()
        }, accessibilityIdentifier: "channel_details.action.unsubcribe.ok")
        self.presentAlert(alertConfig: AlertConfig(titleIdentifier: alertTitleId, messageIdentifier: alertMessageId, cancelButtonAction: cancelAction, otherButtonActions: [okAction]))
    }

    private func unsubscribeChannel() {
        let channelGuid = self.channelInfo.guid
        let feedType = self.channelInfo.feedType
        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in
            DPAGApplicationFacade.feedWorker.unsubscribeFeed(feedGuid: channelGuid, feedType: feedType) { [weak self] _, _, errorMessage in
                DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                    NotificationCenter.default.post(name: DPAGStrings.Notification.Menu.MENU_NEW_REINIT, object: nil)
                    guard let strongSelf = self else { return }
                    if let errorMessage = errorMessage {
                        strongSelf.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
                        return
                    }
                    guard let navigationController = strongSelf.navigationController else { return }
                    var vcNext: UIViewController?
                    for vc in navigationController.viewControllers {
                        switch feedType {
                            case .channel:
                                if vc is DPAGSubscribeChannelViewControllerProtocol {
                                    vcNext = vc
                                } else if vc is DPAGChatsListViewControllerProtocol {
                                    vcNext = vc
                                }
                        }
                    }
                    if let vcNext = vcNext {
                        navigationController.popToViewController(vcNext, animated: true)
                    }
                }
            }
        }
    }
}
