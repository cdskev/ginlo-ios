//
//  DPAGContactNotFoundViewController.swift
// ginlo
//
//  Created by RBU on 27.04.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import MessageUI
import SIMSmeCore
import UIKit

// TODO: Add an option to dismiss the view
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
            if fromWelcomePage {
                self.viewButtonInvite.button.setTitle(DPAGLocalizedString("contacts.button.ignore"), for: .normal)
                self.viewButtonInvite.button.addTargetClosure { [weak self] _ in
                    if let strongSelf = self, let presentedViewController = strongSelf.presentedViewController {
                        presentedViewController.dismiss(animated: true) {
                            NotificationCenter.default.post(name: DPAGStrings.Notification.Application.DID_COMPLETE_LOGIN, object: nil)
                            NotificationCenter.default.post(name: DPAGStrings.Notification.Menu.MENU_SHOW_CHATS, object: nil, userInfo: nil)
                        }
                    } else {
                        NotificationCenter.default.post(name: DPAGStrings.Notification.Application.DID_COMPLETE_LOGIN, object: nil)
                        NotificationCenter.default.post(name: DPAGStrings.Notification.Menu.MENU_SHOW_CHATS, object: nil, userInfo: nil)
                    }
                }
            } else {
                self.viewButtonInvite.button.setTitle(DPAGLocalizedString("contacts.button.inviteUserToSimsMe"), for: .normal)
                self.viewButtonInvite.button.addTargetClosure { [weak self] _ in
                    guard let strongSelf = self else { return }
                    strongSelf.inviteContact()
                }
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

    var fromWelcomePage = false
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
        self.title = DPAGLocalizedString("contacts.options.addContact.notFound")
        var stringFormatKey = "alert.contactSearch.noneFound.messageDescription.accountID"
        switch self.searchMode {
            case .accountID:
                stringFormatKey = "alert.contactSearch.noneFound.messageDescription.accountID"
            case .mail:
                stringFormatKey = "alert.contactSearch.noneFound.messageDescription.emailAddress"
            case .phone:
                stringFormatKey = "alert.contactSearch.noneFound.messageDescription.phoneNumber"
        }
        if fromWelcomePage {
            stringFormatKey += ".fromWelcomePage"
        }
        self.labelDescription.text = String(format: DPAGLocalizedString(stringFormatKey), self.searchData, DPAGMandant.default.name)

    }

    private func inviteContact() {
        SharingHelper().showSharingForInvitation(fromViewController: self, sourceView: viewButtonInvite)
    }
}
