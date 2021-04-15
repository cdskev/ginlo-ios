//
//  DPAGActiveChatsListViewController.swift
//  SIMSme
//
//  Created by RBU on 03/03/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGActiveChatsListViewController: DPAGReceiverSelectionViewController, DPAGActiveChatsListViewControllerProtocol {
    var completionOnSelectReceiver: ((DPAGObject) -> Void)?

    override init() {
        super.init()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        self.navigationItem.title = DPAGLocalizedString("chats.title.newFileChat")
    }

    override func didSelectReceiver(_ receiver: DPAGObject) {
        self.completionOnSelectReceiver?(receiver)
    }
}
