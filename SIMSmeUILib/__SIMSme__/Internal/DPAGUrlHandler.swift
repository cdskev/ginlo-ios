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
    func isInvitationUrl(_ url: URL) -> Bool
    func shouldCreateInvitationBasedAccount(_ url: URL) -> Bool
    func hasMyUrlScheme(_ url: URL) -> Bool
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

    private func handleChannelAdd(_ dict: [String: String]) -> [UIViewController] {
        let key = DPAGStrings.URLHandler.KEY_CHANNEL
        if let channelNameShort = dict[key], let channel = DPAGApplicationFacade.cache.allChannels().first(where: { (channel) -> Bool in
            channel.name_short == channelNameShort
        }) {
            let feedType = channel.feedType
            if let channelStreamGuid = channel.stream, channel.isSubscribed {
                if feedType == .channel {
                    let nextVC = DPAGApplicationFacadeUI.channelStreamVC(stream: channelStreamGuid, streamState: channel.streamState)
                    if let nextVC = nextVC {
                        nextVC.createModel()
                        return [DPAGSimsMeController.sharedInstance.chatsListViewController, nextVC]
                    }
                }
            } else if feedType == .channel {
                let nextVC = DPAGApplicationFacadeUI.channelDetailsVC(channelGuid: channel.guid, category: nil)
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
    
    private func parseURL(_ url: URL) -> [String: String] {
        var ret: [String: String] = [:]
        guard let components = NSURLComponents(url: url, resolvingAgainstBaseURL: true) else { return ret }
        guard let params = components.queryItems else { return ret }
        for param in params {
            if let value = param.value {
                ret[param.name] = value
            } else {
                ret[param.name] = ""
            }
        }
        return ret
    }
}

extension DPAGUrlHandler: DPAGUrlHandlerProtocol {
    func handleUrl(_ url: URL) -> [UIViewController] {
        if url.isFileURL {
            return self.handleFileURL(url)
        } else if let host = url.host, let query = url.query {
            DPAGLog("host: %@", host)
            DPAGLog("query string: %@", query)

            let dict = self.parseURL(url)

            DPAGLog("url received: \(url)")
            DPAGLog("url path: \(url.path)")

            DPAGLog("query dict: %@", dict)

            if host == DPAGStrings.URLHandler.HOST_ACCOUNT {
                return self.handleAccountQuery(dict)
            } else if host == DPAGStrings.URLHandler.HOST_INVITE, DPAGApplicationFacade.cache.account == nil {
                return self.handleInvitationBasedAccountCreation(dict)
            } else if let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid), let nickName = contact.nickName, !nickName.isEmpty {
                switch host {
                    case DPAGStrings.URLHandler.HOST_MESSAGE:
                        return self.handleCreateMessage(dict)
                    case DPAGStrings.URLHandler.HOST_CONTACT:
                        return self.handleSearchContact(dict)
                    case DPAGStrings.URLHandler.HOST_CHANNEL:
                        if url.path == DPAGStrings.URLHandler.PATH_CHANNEL_ADD {
                            return self.handleChannelAdd(dict)
                        }
                    case DPAGStrings.URLHandler.HOST_INVITE:
                        return self.handleInvitationBasedContactSearch(dict)
                    default:
                        break
                }
            }
        }
        return []
    }

    func isInvitationUrl(_ url: URL) -> Bool {
        if hasMyUrlScheme(url), url.query != nil, let host = url.host, host == DPAGStrings.URLHandler.HOST_INVITE {
            return true
        }      
        return false
    }
    
    func shouldCreateInvitationBasedAccount(_ url: URL) -> Bool {
        DPAGApplicationFacade.cache.account == nil && !DPAGApplicationFacade.preferences.isBaMandant && isInvitationUrl(url)
    }
    
    func hasMyUrlScheme(_ url: URL) -> Bool {
        let urlScheme: String = DPAGApplicationFacade.preferences.urlScheme ?? "ginlo"
        let oldUrlScheme: String = DPAGApplicationFacade.preferences.urlSchemeOld ?? "simsme"
        return url.scheme?.hasPrefix(urlScheme) ?? false || url.scheme?.hasPrefix(oldUrlScheme) ?? false
    }
    
    func handleInvitationBasedAccountCreation(_ dict: [String: String]) -> [UIViewController] {
        guard DPAGApplicationFacade.cache.account == nil else { return [] }
        if let rawP = dict["p"], let q = dict["q"], let invitationData = DPAGApplicationFacade.contactsWorker.parseInvitationParams(rawP: rawP, q: q) {
            var invitationBasedCreationVC = DPAGApplicationFacadeUIRegistration.initialPasswordVC(initialPasswordJob: .executeInvitation)
            invitationBasedCreationVC.invitationData = invitationData
            return [invitationBasedCreationVC]
        }
        return []
    }
    
    func handleCreateMessage(_ dict: [String: String]) -> [UIViewController] {
        let text = dict[DPAGStrings.URLHandler.KEY_MESSAGE_TEXT]
        let nostreamVC = DPAGApplicationFacadeUI.chatNoStreamVC(text: text)
        return [DPAGSimsMeController.sharedInstance.chatsListViewController, nostreamVC]
    }

    func handleInvitationBasedContactSearch(_ dict: [String: String]) -> [UIViewController] {
        var searchDict: [String: String] = [:]
        if let accountID = dict["i"] {
            searchDict[DPAGStrings.URLHandler.KEY_CONTACT_GINLOID] = accountID
            return handleSearchContact(searchDict)
        }
        return []
    }
    
    func handleSearchContact(_ dict: [String: String]) -> [UIViewController] {
        let contactSearchVC = DPAGApplicationFacadeUIContacts.contactNewSearchVC()
        if let ginloID = dict[DPAGStrings.URLHandler.KEY_CONTACT_GINLOID] {
            contactSearchVC.ginloIDInit = ginloID
        } else if let simsmeID = dict[DPAGStrings.URLHandler.KEY_CONTACT_SIMSMEID] {
            contactSearchVC.ginloIDInit = simsmeID
        }
        contactSearchVC.phoneNumInit = dict[DPAGStrings.URLHandler.KEY_CONTACT_PHONENUM]
        contactSearchVC.countryCodeInit = dict[DPAGStrings.URLHandler.KEY_CONTACT_COUNTRY_CODE]
        contactSearchVC.emailAddressInit = dict[DPAGStrings.URLHandler.KEY_CONTACT_EMAIL_ADDRESS]
        return [DPAGSimsMeController.sharedInstance.chatsListViewController, contactSearchVC]
    }
}
