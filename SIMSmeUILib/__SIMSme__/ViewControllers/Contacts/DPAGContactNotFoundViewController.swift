//
//  DPAGContactNotFoundViewController.swift
//  SIMSme
//
//  Created by RBU on 27.04.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import MessageUI
import SIMSmeCore
import UIKit

class DPAGContactNotFoundViewController: DPAGViewControllerBackground, DPAGContactNotFoundViewControllerProtocol {
    @IBOutlet private var imageView: UIImageView! {
        didSet {
            self.imageView.image = DPAGImageProvider.shared[.kImageContactsSearch]
        }
    }

    @IBOutlet private var labelHeader: UILabel! {
        didSet {
            self.labelHeader.text = DPAGLocalizedString("alert.contactSearch.noneFound.message")
            self.labelHeader.font = UIFont.kFontTitle1
            self.labelHeader.textColor = DPAGColorProvider.shared[.labelText]
            self.labelHeader.numberOfLines = 0
        }
    }

    @IBOutlet private var labelDescription: UILabel! {
        didSet {
            self.labelDescription.font = UIFont.kFontSubheadline
            self.labelDescription.textColor = DPAGColorProvider.shared[.labelText]
            self.labelDescription.numberOfLines = 0
        }
    }

    @IBOutlet private var viewButtonInvite: DPAGButtonPrimaryView! {
        didSet {
            self.viewButtonInvite.button.accessibilityIdentifier = "buttonInvite"
            self.viewButtonInvite.button.setTitle(DPAGLocalizedString("contacts.button.inviteUserToSimsMe"), for: .normal)
            self.viewButtonInvite.button.addTargetClosure { [weak self] _ in
                guard let strongSelf = self else { return }
                strongSelf.inviteContact()
            }
        }
    }
    
    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.labelHeader.textColor = DPAGColorProvider.shared[.labelText]
                self.labelDescription.textColor = DPAGColorProvider.shared[.labelText]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    private let searchData: String
    private let searchMode: DPAGContactSearchMode
    private let sendEmailHelper = SendEmailHelper()

    init(searchData: String, searchMode: DPAGContactSearchMode) {
        self.searchData = searchData
        self.searchMode = searchMode

        super.init(nibName: nil, bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = DPAGLocalizedString("contacts.options.addContact")
        switch self.searchMode {
            case .accountID:
                self.labelDescription.text = String(format: DPAGLocalizedString("alert.contactSearch.noneFound.messageDescription.accountID"), self.searchData, DPAGMandant.default.name)
            case .mail:
                self.labelDescription.text = String(format: DPAGLocalizedString("alert.contactSearch.noneFound.messageDescription.emailAddress"), self.searchData, DPAGMandant.default.name)
            case .phone:
                self.labelDescription.text = String(format: DPAGLocalizedString("alert.contactSearch.noneFound.messageDescription.phoneNumber"), self.searchData, DPAGMandant.default.name)
        }
    }

    private func inviteContact() {
        SharingHelper().showSharingForInvitation(fromViewController: self, sourceView: viewButtonInvite)
    }
}
