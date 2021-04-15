//
//  DPAGMigrationBaseViewController.swift
//  SIMSme
//
//  Created by RBU on 04/03/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

public protocol DPAGMigrationViewControllerProtocol: AnyObject {}

class DPAGMigrationBaseViewController: DPAGLaunchScreenMigrationViewController, DPAGMigrationWorkerDelegate, DPAGMigrationViewControllerProtocol {
    override init() {
        super.init()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = DPAGLocalizedString("migration.title")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.setMigrationInfo(DPAGLocalizedString("migration.info.init"))
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(cancelMigration), name: DPAGStrings.Notification.Application.DID_ENTER_BACKGROUND, object: nil)
        self.performBlockInBackground { [weak self] in
            self?.startMigration()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: DPAGStrings.Notification.Application.DID_ENTER_BACKGROUND, object: nil)
    }

    func setMigrationInfo(_ info: String) {
        self.performBlockOnMainThread { [weak self] in
            self?.labelInfo.text = DPAGLocalizedString(info)
            self?.activityIndicator.startAnimating()
        }
    }

    var migrationVersion: DPAGPreferences.DPAGMigrationVersion {
        .versionCurrent
    }

    func startMigration() {
        self.endMigration()
    }

    @objc
    func cancelMigration() {}

    func endMigration() {
        DPAGApplicationFacade.preferences.migrationVersion = self.migrationVersion
        NotificationCenter.default.post(name: DPAGStrings.Notification.Application.DID_COMPLETE_LOGIN, object: nil)
    }
}
