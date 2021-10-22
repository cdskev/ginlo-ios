//
//  DPAGSetNotificationDefaultsWorker.swift
// ginlo
//
//  Created by RBU on 27/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import UIKit

public protocol DPAGNotificationWorkerDelegate: AnyObject {
    func notificationSetupComplete()

    func notificationSetupDidFail()
}

public class DPAGSetNotificationDefaultsWorker {
    public weak var delegate: DPAGNotificationWorkerDelegate?

    var tasks: [DPAGCompletion] = []

    public init() {
        self.tasks = [
            enableSingleChatNotificationSounds,
            enableGroupChatNotificationSounds,
            enableChannelChatNotificationSounds,
            enableSingleChatNotifications,
            enableGroupChatNotifications,
            enableChannelChatNotifications
        ]
    }

    public func start() {
        let preferences = DPAGApplicationFacade.preferences

        preferences[.kNotificationChatEnabled] = DPAGPreferences.kValueNotificationEnabled
        preferences[.kNotificationGroupChatEnabled] = DPAGPreferences.kValueNotificationEnabled
        preferences[.kNotificationChannelChatEnabled] = DPAGPreferences.kValueNotificationEnabled
        preferences[.kNotificationServiceChatEnabled] = DPAGPreferences.kValueNotificationEnabled

        preferences[.kChatRingtone] = DPAGPreferences.kValueNotificationSoundDefault
        preferences[.kGroupChatRingtone] = DPAGPreferences.kValueNotificationSoundDefault
        preferences[.kChannelChatRingtone] = DPAGPreferences.kValueNotificationSoundDefault
        preferences[.kServiceChatRingtone] = DPAGPreferences.kValueNotificationSoundDefault

        self.continueWithNextTask()
    }

    func continueWithNextTask() {
        if self.tasks.isEmpty == false {
            self.tasks.removeLast()()
        } else {
            self.delegate?.notificationSetupComplete()
        }
    }

    func enableSingleChatNotificationSounds() {
        DPAGApplicationFacade.server.setNotificationSound(enable: true, forChatType: .single, withResponse: self.newResponseBlock())
    }

    func enableGroupChatNotificationSounds() {
        DPAGApplicationFacade.server.setNotificationSound(enable: true, forChatType: .group, withResponse: self.newResponseBlock())
    }

    func enableChannelChatNotificationSounds() {
        DPAGApplicationFacade.server.setNotificationSound(enable: true, forChatType: .channel, withResponse: self.newResponseBlock())
    }

    func enableSingleChatNotifications() {
        DPAGApplicationFacade.server.setNotification(enable: true, forChatType: .single, withResponse: self.newResponseBlock())
    }

    func enableGroupChatNotifications() {
        DPAGApplicationFacade.server.setNotification(enable: true, forChatType: .group, withResponse: self.newResponseBlock())
    }

    func enableChannelChatNotifications() {
        DPAGApplicationFacade.server.setNotification(enable: true, forChatType: .channel, withResponse: self.newResponseBlock())
    }

    func newResponseBlock() -> DPAGServiceResponseBlock {
        { [weak self] _, _, errorMessage in

            if errorMessage != nil {
                self?.handleError()
            } else {
                self?.continueWithNextTask()
            }
        }
    }

    func handleError() {
        self.delegate?.notificationSetupDidFail()
    }
}
