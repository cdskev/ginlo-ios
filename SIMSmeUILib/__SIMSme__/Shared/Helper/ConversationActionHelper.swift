//
//  ConversationActionHelper.swift
//  SIMSmeUIContactsLib
//
//  Created by Maxime Bentin on 29.04.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

struct ConversationActionHelper {
    func showClearChatPopup(viewController: UIViewController?, streamGuid: String?) {
        guard let streamGuid = streamGuid else {
            return
        }

        let actionClear = UIAlertAction(titleIdentifier: "chat.list.action.confirm.clear.chat", style: .destructive, handler: { _ in
            DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in
                DPAGApplicationFacade.contactsWorker.emptyStreamWithGuid(streamGuid)
                DPAGProgressHUD.sharedInstance.hide(true)
            }
        })

        viewController?.presentAlert(alertConfig: UIViewController.AlertConfig(titleIdentifier: "chat.list.title.confirm.clear.chat",
                                                                               cancelButtonAction: .cancelDefault,
                                                                               otherButtonActions: [actionClear]))
    }
}
