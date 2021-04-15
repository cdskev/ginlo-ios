//
//  NotificationService.swift
//  notificationExtension
//
//  Created by Matthias Röhricht on 06.03.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UserNotifications

class NotificationService: NotificationServiceBase {
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        self.bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        self.handleContent(request, config: DPAGSharedContainerConfig(keychainAccessGroupName: AppConfig.keychainAccessGroupName, groupID: AppConfig.groupId, urlHttpService: AppConfig.urlHttpService), withContentHandler: contentHandler)
    }

    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        if let contentHandler = self.contentHandler, let bestAttemptContent = self.bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
}
