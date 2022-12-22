//
//  DPAGChatsListViewController+Delegates.swift
// ginlo
//
//  Created by RBU on 07/04/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

// MARK: - DPAGNewChatDelegate

extension DPAGChatsListViewController: DPAGNewChatDelegate {
    func startChatWithGroup(_ streamGuid: String, fileURL: URL?) {
        if let group = DPAGApplicationFacade.cache.group(for: streamGuid) {
            let nextVC = DPAGApplicationFacadeUI.chatGroupStreamVC(stream: streamGuid, streamState: group.streamState)
            nextVC.fileToSend = fileURL
            nextVC.createModel()
            DPAGApplicationFacadeUIBase.containerVC.pushSecondaryViewController(nextVC, animated: true)
        }
    }
}

// MARK: - DPAGNewGroupDelegate

extension DPAGChatsListViewController: DPAGNewGroupDelegate {
    func handleGroupCreated(_ groupGuid: String?) {
        if let groupGuid = groupGuid, let group = DPAGApplicationFacade.cache.group(for: groupGuid) {
            let streamVC = DPAGApplicationFacadeUI.chatGroupStreamVC(stream: groupGuid, streamState: group.streamState)
            streamVC.createModel()
            DPAGApplicationFacadeUIBase.containerVC.pushSecondaryViewController(streamVC, animated: true)
            DPAGApplicationFacade.preferences.chatGroupCreationCount += 1
        }
    }
}
