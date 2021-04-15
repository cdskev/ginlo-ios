//
//  DPAGContactsSearchEmptyView.swift
//  SIMSmeUILib
//
//  Created by RBU on 23.05.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

public protocol DPAGContactsSearchEmptyViewDelegate: AnyObject {
    func handleSearch()
    func handleInvite()
}

public protocol DPAGContactsSearchEmptyViewProtocol: AnyObject {
    var buttonDelegate: DPAGContactsSearchEmptyViewDelegate? { get set }
}

class DPAGContactsSearchEmptyView: UITableViewCell, DPAGContactsSearchEmptyViewProtocol {
    @IBOutlet private var labelTitle: UILabel! {
        didSet {
            self.labelTitle.font = UIFont.kFontTitle1
            self.labelTitle.textColor = DPAGColorProvider.shared[.labelText]
            self.labelTitle.text = DPAGLocalizedString("contacts.search.empty.header")
            self.labelTitle.numberOfLines = 0
        }
    }

    @IBOutlet private var labelDescription: UILabel! {
        didSet {
            let bundleIdentifier = DPAGMandant.default.name

            self.labelDescription.font = UIFont.kFontSubheadline
            self.labelDescription.textColor = DPAGColorProvider.shared[.labelText]
            self.labelDescription.text = String(format: DPAGLocalizedString("contacts.search.empty.ask"), bundleIdentifier)
            self.labelDescription.numberOfLines = 0
        }
    }

    @IBOutlet private var buttonSearch: UIButton! {
        didSet {
            let bundleIdentifier = DPAGMandant.default.name

            self.buttonSearch.accessibilityIdentifier = "contacts.search.empty.search"
            self.buttonSearch.configureButton()
            self.buttonSearch.setTitle(String(format: DPAGLocalizedString("contacts.search.empty.search"), bundleIdentifier), for: .normal)
            self.buttonSearch.addTarget(self, action: #selector(handleSearch), for: .touchUpInside)
        }
    }

    @IBOutlet private var buttonInvite: UIButton! {
        didSet {
            self.buttonInvite.configureButton()
            self.buttonInvite.accessibilityIdentifier = "contacts.search.empty.invite"
            self.buttonInvite.setTitle(DPAGLocalizedString("contacts.search.empty.invite"), for: .normal)
            self.buttonInvite.addTarget(self, action: #selector(handleInvite), for: .touchUpInside)
        }
    }

    weak var buttonDelegate: DPAGContactsSearchEmptyViewDelegate?

    override func awakeFromNib() {
        super.awakeFromNib()

        self.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
    }

    @objc
    private func handleSearch() {
        self.buttonDelegate?.handleSearch()
    }

    @objc
    private func handleInvite() {
        self.buttonDelegate?.handleInvite()
    }
    
    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.labelTitle.textColor = DPAGColorProvider.shared[.labelText]
                self.labelDescription.textColor = DPAGColorProvider.shared[.labelText]
                self.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }
}
