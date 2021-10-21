//
//  DPAGNewChatViewController.swift
// ginlo
//
//  Created by RBU on 29/01/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGContactsSelectionNewChatBaseViewController: DPAGContactsSelectionViewController, DPAGContactsSelectionNewChatDelegateConsumer, DPAGContactsOptionsProtocol, DPAGContactsOptionsViewControllerProtocol, DPAGContactsSelectionNewChatBaseViewControllerProtocol, DPAGContactsPageViewControllerProtocol {
    var reloadOnAppear: Bool = false

    typealias T = DPAGContact

    init(contactsSelected: DPAGSearchListSelection<DPAGContact>) {
        super.init(contactsSelected: contactsSelected, showInviteAction: true)
        self.options = [.EnableGroupedStyle]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = DPAGLocalizedString("chats.title.newChat")
        self.tableView.accessibilityLabel = DPAGLocalizedString("chats.title.newChat")
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(dismissViewController))
    }

    @objc
    private func dismissViewController() {
        self.dismiss(animated: true, completion: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if self.reloadOnAppear {
            self.reloadOnAppear = false
            self.performBlockInBackground { [weak self] in
                self?.createModel()
                self?.performBlockOnMainThread { [weak self] in
                    self?.tableView.reloadData()
                }
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    override func configureSearchBar() {
        self.configureSearchBarWithResultsController(DPAGApplicationFacadeUIContacts.contactsSearchResultsVC(delegate: self, emptyViewDelegate: self), placeholder: "android.serach.placeholder")
    }

    @objc
    func handleOptions() {
        self.handleOptions(presentingVC: self, modelVC: self, barButtonItem: self.navigationItem.rightBarButtonItem)
    }

    override func didSelect(objects: Set<DPAGContact>) {
        let blockSelect = {
            guard let contact = objects.first else { return }
            DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { [weak self] _ in
                if contact.entryTypeLocal == .hidden {
                    DPAGApplicationFacade.contactsWorker.privatizeContact(contact)
                }
                let block = {
                    DPAGProgressHUD.sharedInstance.hide(true) {
                        NotificationCenter.default.post(name: DPAGStrings.Notification.Menu.MENU_SHOW_CHATS, object: nil, userInfo: [DPAGStrings.Notification.Menu.MENU_SHOW_CHATS__USERINFO_KEY__CONTACT_GUID: contact.guid])
                    }
                }
                if contact.publicKey == nil {
                    DPAGApplicationFacade.updateKnownContactsWorker.synchronize(accountGuid: contact.guid, response: { _, _, errorMessage in
                        if let errorMessage = errorMessage {
                            DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                                self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
                            }
                        } else {
                            block()
                        }
                    })
                } else {
                    block()
                }
            }
        }
        if let searchController = self.searchController, searchController.isActive {
            searchController.dismiss(animated: true) {
                blockSelect()
            }
        } else {
            blockSelect()
        }
    }

    private func showSyncContactsAlert() {
        let options = [AlertOption.okOption()]
        let titleString = DPAGLocalizedString("contacts.remindSyncingPopup.title")
        let messageString = DPAGLocalizedString("contacts.remindSyncingPopup.message")
        let alert = UIAlertController.controller(options: options, titleString: titleString, messageString: messageString, withStyle: .alert, accessibilityIdentifier: "contacts.remindSyncingPopup")
        self.presentAlertController(alert)
    }
}

extension DPAGContactsSelectionNewChatBaseViewController: DPAGContactsSearchViewControllerDelegate {
    func didSelectContact(contact: DPAGContact) {
        self.didSelect(objects: Set([contact]))
    }
}

class DPAGContactsSelectionNewChatViewController: DPAGContactsSelectionNewChatBaseViewController {
    override func configureNavigationBar() {
        super.configureNavigationBar()
        self.setRightBarButtonItem(image: DPAGImageProvider.shared[.kEllipsisCircle], action: #selector(handleOptions), accessibilityLabelIdentifier: "navigation.options")
    }
}

class DPAGContactsSelectionNewChatPageViewController: DPAGContactsSelectionNewChatBaseViewController {}

class DPAGContactsSelectionNewChatCompanyViewController: DPAGContactsSelectionNewChatBaseViewController {
    override var selectionType: DPAGContactsSelectionType {
        .company
    }
}

class DPAGContactsSelectionNewChatDomainViewController: DPAGContactsSelectionNewChatBaseViewController, DPAGContactsDomainEmptyViewControllerProtocol {
    override var selectionType: DPAGContactsSelectionType {
        .domain
    }

    private var _tableViewEmpty: UIView?

    override var tableViewEmpty: UIView? {
        get {
            if _tableViewEmpty == nil {
                _tableViewEmpty = DPAGApplicationFacadeUIContacts.viewContactsDomainEmpty()
            }
            return _tableViewEmpty
        }
        set {
            super.tableViewEmpty = newValue
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.configureEmptyDomainGui()
        if let emptyView = self.tableViewEmpty as? DPAGContactsDomainEmptyViewProtocol {
            emptyView.btnStartEMail.addTarget(self, action: #selector(self.handleAuthenticateMailButtonTapped(_:)), for: .touchUpInside)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.updateEmptyDomainGui()
    }

    @objc
    func handleAuthenticateMailButtonTapped(_: Any?) {
        if let nextVC = DPAGApplicationFacade.preferences.viewControllerForIdent(DPAGWhiteLabelNextView.dpagProfileViewController_startCompanyProfilInitEMailController) {
            self.navigationController?.pushViewController(nextVC, animated: true)
        }
    }
}

class DPAGContactsSelectionNewChatCompanyPageViewController: DPAGContactsSelectionNewChatCompanyViewController {}

class DPAGContactsSelectionNewChatDomainPageViewController: DPAGContactsSelectionNewChatDomainViewController {}

class DPAGContactsSelectionNewChatCompanyPagesViewController: DPAGContactsPagesBaseViewController, DPAGContactsPagesViewControllerProtocol, DPAGContactsSelectionNewChatDelegateConsumer, DPAGContactsOptionsProtocol {
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(dismissViewController))
        self.setRightBarButtonItem(image: DPAGImageProvider.shared[.kEllipsisCircle], action: #selector(handleOptions), accessibilityLabelIdentifier: "navigation.options")
    }

    @objc
    private func dismissViewController() {
        self.dismiss(animated: true, completion: nil)
    }

    func createPage0() -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol) {
        let retVal = DPAGApplicationFacadeUIContacts.contactsSelectionNewChatPageVC(contactsSelected: self.contactsSelected)
        return retVal
    }

    func createPage2() -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol)? {
        DPAGApplicationFacadeUIContacts.contactsSelectionNewChatCompanyPageVC(contactsSelected: self.contactsSelected)
    }

    @objc
    private func handleOptions() {
        if let modelVC = self.page0 as? DPAGContactsOptionsViewControllerProtocol {
            self.handleOptions(presentingVC: self, modelVC: modelVC, barButtonItem: self.navigationItem.rightBarButtonItem)
        }
    }
}

class DPAGContactsSelectionNewChatDomainPagesViewController: DPAGContactsPagesBaseViewController, DPAGContactsPagesViewControllerProtocol, DPAGContactsSelectionNewChatDelegateConsumer, DPAGContactsOptionsProtocol {
    weak var delegate: DPAGNewChatDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(dismissViewController))
        self.setRightBarButtonItem(image: DPAGImageProvider.shared[.kEllipsisCircle], action: #selector(handleOptions), accessibilityLabelIdentifier: "navigation.options")
    }

    @objc
    private func dismissViewController() {
        self.dismiss(animated: true, completion: nil)
    }

    func createPage0() -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol) {
        DPAGApplicationFacadeUIContacts.contactsSelectionNewChatPageVC(contactsSelected: self.contactsSelected)
    }

    func createPage1() -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol)? {
        DPAGApplicationFacadeUIContacts.contactsSelectionNewChatDomainPageVC(contactsSelected: self.contactsSelected)
    }

    @objc
    private func handleOptions() {
        if let modelVC = self.page0 as? DPAGContactsOptionsViewControllerProtocol {
            self.handleOptions(presentingVC: self, modelVC: modelVC, barButtonItem: self.navigationItem.rightBarButtonItem)
        }
    }
}

class DPAGContactsSelectionNewChatCompanyDomainPagesViewController: DPAGContactsPagesBaseViewController, DPAGContactsPagesViewControllerProtocol, DPAGContactsSelectionNewChatDelegateConsumer, DPAGContactsOptionsProtocol {
    weak var delegate: DPAGNewChatDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(dismissViewController))
        self.setRightBarButtonItem(image: DPAGImageProvider.shared[.kEllipsisCircle], action: #selector(handleOptions), accessibilityLabelIdentifier: "navigation.options")
    }

    @objc
    private func dismissViewController() {
        self.dismiss(animated: true, completion: nil)
    }

    func createPage0() -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol) {
        DPAGApplicationFacadeUIContacts.contactsSelectionNewChatPageVC(contactsSelected: self.contactsSelected)
    }

    func createPage2() -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol)? {
        DPAGApplicationFacadeUIContacts.contactsSelectionNewChatCompanyPageVC(contactsSelected: self.contactsSelected)
    }

    func createPage1() -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol)? {
        DPAGApplicationFacadeUIContacts.contactsSelectionNewChatDomainPageVC(contactsSelected: self.contactsSelected)
    }

    @objc
    private func handleOptions() {
        if let modelVC = self.page0 as? DPAGContactsOptionsViewControllerProtocol {
            self.handleOptions(presentingVC: self, modelVC: modelVC, barButtonItem: self.navigationItem.rightBarButtonItem)
        }
    }
}
