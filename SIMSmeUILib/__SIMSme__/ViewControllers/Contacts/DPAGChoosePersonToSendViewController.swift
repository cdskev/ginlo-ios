//
//  DPAGChoosePersonToSendViewController.swift
//  SIMSme
//
//  Created by Matthias Röhricht on 20.03.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGChoosePersonToSendViewController: DPAGPersonsSelectionViewController, DPAGViewControllerOrientationFlexibleIfPresented {
    private weak var delegateSending: DPAGPersonSendingDelegate?

    init(delegateSending: DPAGPersonSendingDelegate?) {
        super.init()

        self.delegateSending = delegateSending
        self.delegateSelection = self
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = DPAGLocalizedString("contacts.overViewViewControllerTitle")

        if self.presentingViewController != nil {
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(dismissViewController))
        }
    }

    @objc
    private func dismissViewController() {
        self.dismiss(animated: true, completion: nil)
    }
}

extension DPAGChoosePersonToSendViewController: DPAGPersonsSelectionDelegate {
    func didSelect(persons: Set<DPAGPerson>) {
        if let person = persons.first {
            self.delegateSending?.send(person: person)

            self.dismiss(animated: true, completion: nil)
        }
    }
}
