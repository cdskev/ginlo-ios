//
//  DPAGNewAnnouncementGroupViewController.swift
// ginlo
//
//  Created by ISO on 2021-01-19
//  Copyright © 2021 ginlo.net GmbH. All rights reserved.
//

import AVFoundation
import MobileCoreServices
import Photos
import SIMSmeCore
import UIKit

class DPAGNewAnnouncementGroupViewController: DPAGNewGroupViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = DPAGLocalizedString("chat.group.newAnnouncementRoomTitle")
    }
    
    @objc
    override func handleCreateGroupTapped(_: Any?) {
        handleCreateGroup(ofType: DPAGStrings.Server.Group.Request.OBJECT_KEY_ANNOUNCEMENT)
    }
}
