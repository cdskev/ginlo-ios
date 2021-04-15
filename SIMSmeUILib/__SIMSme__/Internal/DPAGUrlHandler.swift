//
//  DPAGUrlHandler.swift
//  SIMSme
//
//  Created by RBU on 04/11/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

public protocol DPAGUrlHandlerProtocol {
    func handleUrl(_ url: URL) -> [UIViewController]
    func handleCreateMessage(_ dict: [String: String]) -> [UIViewController]
}

class DPAGUrlHandler {
    static let sharedInstance = DPAGUrlHandler()

    private func handleFileURL(_ fileURL: URL) -> [UIViewController] {
        if DPAGApplicationFacade.cache.account != nil {
            let nextVC = DPAGApplicationFacadeUIContacts.newFileChatVC(delegate: DPAGSimsMeController.sharedInstance.chatsListViewController, fileURL: fileURL)

            return [DPAGSimsMeController.sharedInstance.chatsListViewController, nextVC]
        } else {
            DPAGLog("no account was found")
            if let mainWindow = AppConfig.appWindow() {
                mainWindow?.rootViewController?.presentErrorAlert(alertConfig: UIViewController.AlertConfigError(titleIdentifier: "attention", messageIdentifier: "account.noAccountFound"))
            }
        }
        return []
    }

    private func handleChannelAdd(_ dict: [String: String], isChannel: Bool) -> [UIViewController] {
        var key = DPAGStrings.URLHandler.KEY_CHANNEL
        if !isChannel {
            key = DPAGStrings.URLHandler.KEY_SERVICE
        }
        if let channelNameShort = dict[key], let channel = DPAGApplicationFacade.cache.allChannels().first(where: { (channel) -> Bool in
            channel.name_short == channelNameShort
        }) {
            let feedType = channel.feedType

            if let channelStreamGuid = channel.stream, channel.isSubscribed {
                let nextVC: (UIViewController & DPAGChatStreamBaseViewControllerProtocol)?

                switch feedType {
                case .channel:
                    nextVC = DPAGApplicationFacadeUI.channelStreamVC(stream: channelStreamGuid, streamState: channel.streamState)
                case .service:
                    nextVC = DPAGApplicationFacadeUI.serviceStreamVC(stream: channelStreamGuid, streamState: channel.streamState)
                }

                if let nextVC = nextVC {
                    nextVC.createModel()

                    return [DPAGSimsMeController.sharedInstance.chatsListViewController, nextVC]
                }
            } else {
                let nextVC: UIViewController?

                switch feedType {
                case .channel:
                    nextVC = DPAGApplicationFacadeUI.channelDetailsVC(channelGuid: channel.guid, category: nil)
                case .service:
                    nextVC = DPAGApplicationFacadeUI.serviceSubscribeVC()
                }

                if let nextVC = nextVC {
                    return [DPAGSimsMeController.sharedInstance.chatsListViewController, nextVC]
                }
            }
        }
        return []
    }

    private func handleAccountQuery(_ dict: [String: String]) -> [UIViewController] {
        let code = dict[DPAGStrings.URLHandler.KEY_CONFIRM]

        if let account = DPAGApplicationFacade.cache.account {
            let state = account.accountState

            let waitState = "\(DPAGAccountState.waitForConfirm.rawValue)"

            DPAGLog("account state %@, expected %@", state.rawValue, waitState)

            let waitingForConfirmation = (state == .waitForConfirm)

            if waitingForConfirmation {
                DPAGLog("redirecting to confirmation vc")
                let confirmationController = DPAGApplicationFacadeUIRegistration.confirmAccountVC(confirmationCode: code)

                return [confirmationController]
            } else {
                DPAGLog("account state does not fit: \(state.rawValue)")
                // TODO: change message according to account state
                if let mainWindow = AppConfig.appWindow() {
                    mainWindow?.rootViewController?.presentErrorAlert(alertConfig: UIViewController.AlertConfigError(titleIdentifier: "attention", messageIdentifier: "account.alreadyConfirmed"))
                }
            }
        } else {
            DPAGLog("no account was found")
            if let mainWindow = AppConfig.appWindow() {
                mainWindow?.rootViewController?.presentErrorAlert(alertConfig: UIViewController.AlertConfigError(titleIdentifier: "attention", messageIdentifier: "account.noAccountFound"))
            }
        }
        return []
    }

    private func parseQueryString(_ query: String) -> [String: String] {
        let queryToSplit = query.replacingOccurrences(of: "+", with: "%20")

        var dict: [String: String] = [:]

        let pairs = queryToSplit.components(separatedBy: "&")

        for pair in pairs {
            let elements = pair.components(separatedBy: "=")

            if elements.count > 1, let key = elements[0].removingPercentEncoding, let val = elements[1].removingPercentEncoding, key.isEmpty == false, val.isEmpty == false {
                dict[key] = val
            }
        }
        return dict
    }
}

extension DPAGUrlHandler: DPAGUrlHandlerProtocol {
    func handleUrl(_ url: URL) -> [UIViewController] {
        if url.isFileURL {
            return self.handleFileURL(url)
        } else if let host = url.host, let query = url.query {
            DPAGLog("host: %@", host)
            DPAGLog("query string: %@", query)

            let dict = self.parseQueryString(query)

            DPAGLog("url received: \(url)")
            DPAGLog("url path: \(url.path)")

            DPAGLog("query dict: %@", dict)

            if host == DPAGStrings.URLHandler.HOST_ACCOUNT {
                return self.handleAccountQuery(dict)
            } else if host == DPAGStrings.URLHandler.HOST_MESSAGE || host == DPAGStrings.URLHandler.HOST_CHANNEL || host == DPAGStrings.URLHandler.HOST_SERVICE || host == DPAGStrings.URLHandler.HOST_CONTACT {
                if let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid), let nickName = contact.nickName, nickName.isEmpty == false {
                    if host == DPAGStrings.URLHandler.HOST_MESSAGE {
                        return self.handleCreateMessage(dict)
                    }
                    if host == DPAGStrings.URLHandler.HOST_CONTACT {
                        return self.handleSearchContact(dict)
                    }
                    if host == DPAGStrings.URLHandler.HOST_CHANNEL, DPAGStrings.URLHandler.PATH_CHANNEL_ADD == url.path {
                        return self.handleChannelAdd(dict, isChannel: true)
                    }
                    if host == DPAGStrings.URLHandler.HOST_SERVICE, DPAGStrings.URLHandler.PATH_SERVICE_ADD == url.path {
                        return self.handleChannelAdd(dict, isChannel: false)
                    }
                }
            }
        }
        return []
    }

    func handleCreateMessage(_ dict: [String: String]) -> [UIViewController] {
        let text = dict[DPAGStrings.URLHandler.KEY_MESSAGE_TEXT]

        let nostreamVC = DPAGApplicationFacadeUI.chatNoStreamVC(text: text)

        return [DPAGSimsMeController.sharedInstance.chatsListViewController, nostreamVC]
    }

    func handleSearchContact(_ dict: [String: String]) -> [UIViewController] {
        let contactSearchVC = DPAGApplicationFacadeUIContacts.contactNewSearchVC()

        contactSearchVC.simsmeIDInit = dict[DPAGStrings.URLHandler.KEY_CONTACT_SIMSMEID]
        contactSearchVC.phoneNumInit = dict[DPAGStrings.URLHandler.KEY_CONTACT_PHONENUM]
        contactSearchVC.countryCodeInit = dict[DPAGStrings.URLHandler.KEY_CONTACT_COUNTRY_CODE]
        contactSearchVC.emailAddressInit = dict[DPAGStrings.URLHandler.KEY_CONTACT_EMAIL_ADDRESS]

        return [DPAGSimsMeController.sharedInstance.chatsListViewController, contactSearchVC]
    }
}
