//
//  ShareViewController.swift
//  shareExtensionTest
//
//  Created by Robert Burchert on 03.12.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import SIMSmeUILib

@objc(ShareViewController)
class ShareViewController: DPAGShareExtViewControllerBase {
    private let config = DPAGSharedContainerConfig(keychainAccessGroupName: AppConfig.keychainAccessGroupName, groupID: AppConfig.groupId, urlHttpService: AppConfig.urlHttpService)

    override var containerConfig: DPAGSharedContainerConfig? {
        self.config
    }
}
