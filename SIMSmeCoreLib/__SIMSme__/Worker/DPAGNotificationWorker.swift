//
//  DPAGNotificationWorker.swift
// ginlo
//
//  Created by RBU on 27/01/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

public struct DPAGNotificationWorker {
    private init() {}

    public static func setNotificationEnabled(_ enabled: Bool, forChatType chatType: DPAGNotificationChatType, withResponse responseBlock: @escaping DPAGServiceResponseBlock) {
        DPAGApplicationFacade.server.setNotification(enable: enabled, forChatType: chatType, withResponse: responseBlock)
    }

    public static func setBackgroundPushNotificationEnabled(_ enabled: Bool, withResponse responseBlock: @escaping DPAGServiceResponseBlock) {
        DPAGApplicationFacade.server.setBackgroundPushNotification(enable: enabled, withResponse: responseBlock)
    }

    public static func setPreviewPushNotificationEnabled(_ enabled: Bool, withResponse responseBlock: @escaping DPAGServiceResponseBlock) {
        DPAGApplicationFacade.server.setPreviewPushNotification(enable: enabled, withResponse: responseBlock)
    }

    public static func setNotificationSoundEnabled(_ enabled: Bool, forChatType chatType: DPAGNotificationChatType, withResponse responseBlock: @escaping DPAGServiceResponseBlock) {
        DPAGApplicationFacade.server.setNotificationSound(enable: enabled, forChatType: chatType, withResponse: responseBlock)
    }
}
