//
//  StartNewChatHelper.swift
//  SIMSmeUILib
//
//  Created by Evgenii Kononenko on 02.04.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation
import SIMSmeCore

class StartNewChatHelper {
    private let textAlignment = CATextLayerAlignmentMode.left
    weak var viewController: UIViewController?
    weak var delegateNewGroup: DPAGNewGroupDelegate?

    // MARK: - Internal

    func getAlertOptions() -> [AlertOption] {
        let options = [self.optionStartNewChat(),
                   self.optionStartNewMailingList(),
                   self.optionCreateNewGroup(),
                   self.optionCreateNewAnnouncementGroup(),
                   self.optionInviteFriends(),
                   self.optionCancel()]
        return options.compactMap { $0 }
    }

    // MARK: - Options

    private func optionStartNewChat() -> AlertOption {
        AlertOption(title: DPAGLocalizedString("chat.list.label.newsinglechat"), style: .default, image: DPAGImageProvider.shared[.kImageMenuNewStartNewChat], textAlignment: self.textAlignment, accesibilityIdentifier: "chat.list.label.newsinglechat", handler: self.showStartNewChat)
    }

    private func optionStartNewMailingList() -> AlertOption {
        AlertOption(title: DPAGLocalizedString("chat.list.label.newbroadcastlist"), style: .default, image: DPAGImageProvider.shared[.kImageMenuNewStartNewMailingList], textAlignment: self.textAlignment, accesibilityIdentifier: "chat.no_stream.title.multi", handler: self.showStartNewMailingList)
    }

    private func optionCreateNewGroup() -> AlertOption {
        AlertOption(title: DPAGLocalizedString("chat.list.label.newgroupchat"), style: .default, image: DPAGImageProvider.shared[.kImageMenuNewStartNewGroup], textAlignment: self.textAlignment, accesibilityIdentifier: "chat.list.label.newgroupchat", handler: self.showCreateNewGroup)
    }

    private func optionCreateNewAnnouncementGroup() -> AlertOption? {
        guard AppConfig.createAnnouncementGroupAllowed == true else { return nil }
        return AlertOption(title: DPAGLocalizedString("chat.list.label.newannouncementgroupchat"), style: .default, image: DPAGImageProvider.shared[.kImageMenuNewStartNewGroup], textAlignment: self.textAlignment, accesibilityIdentifier: "chat.list.label.newannouncementgroupchat", handler: self.showCreateNewAnnouncementGroup)
    }

    private func optionInviteFriends() -> AlertOption? {
        guard DPAGApplicationFacade.preferences.showInviteFriends == true else { return nil }
        return AlertOption(title: DPAGLocalizedString("chat.list.label.invitefriends"), style: .default, image: DPAGImageProvider.shared[.kImageMenuNewInviteFriends], textAlignment: self.textAlignment, accesibilityIdentifier: "chat.list.cell.label.invitefriends", handler: self.showInviteFriends)
    }

    private func optionCancel() -> AlertOption {
        AlertOption(title: DPAGLocalizedString("res.cancel"), style: .cancel)
    }

    private func showStartNewChat() {
        if let nextVC = DPAGApplicationFacade.preferences.viewControllerContactSelectionForIdent(.dpagNewChatViewController, contactsSelected: DPAGSearchListSelection<DPAGContact>()) {
            let navigationController = DPAGApplicationFacadeUIBase.navVC(rootViewController: nextVC)
            self.viewController?.present(navigationController, animated: true, completion: nil)
        }
    }

    private func showStartNewMailingList() {
        NotificationCenter.default.post(name: DPAGStrings.Notification.Menu.MENU_SHOW_CHATS, object: nil, userInfo: [DPAGStrings.Notification.Menu.MENU_SHOW_CHATS__USERINFO_KEY__CONTACT_GUID: "???"])
    }

    private func showCreateNewGroup() {
        if DPAGHelperEx.isNetworkReachable() == false {
            let alertConfig = UIViewController.AlertConfigError(messageIdentifier: "backendservice.internet.connectionFailed", accessibilityIdentifier: "backendservice.internet.connectionFailed")
            self.viewController?.presentErrorAlert(alertConfig: alertConfig)
            return
        }
        let nextVC = DPAGApplicationFacadeUI.groupNewVC(delegate: self.delegateNewGroup)
        let navigationController = DPAGApplicationFacadeUIBase.navVC(rootViewController: nextVC)
        self.viewController?.present(navigationController, animated: true, completion: nil)
    }

    private func showCreateNewAnnouncementGroup() {
        if DPAGHelperEx.isNetworkReachable() == false {
            let alertConfig = UIViewController.AlertConfigError(messageIdentifier: "backendservice.internet.connectionFailed", accessibilityIdentifier: "backendservice.internet.connectionFailed")
            self.viewController?.presentErrorAlert(alertConfig: alertConfig)
            return
        }
        let nextVC = DPAGApplicationFacadeUI.groupNewAnnouncementGroupVC(delegate: self.delegateNewGroup)
        let navigationController = DPAGApplicationFacadeUIBase.navVC(rootViewController: nextVC)
        self.viewController?.present(navigationController, animated: true, completion: nil)
    }

    private func showInviteFriends() {
        SharingHelper().showSharingForInvitation(fromViewController: self.viewController)
    }
}
