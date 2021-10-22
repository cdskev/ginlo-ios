//
//  DPAGChatNoStreamViewController.swift
// ginlo
//
//  Created by RBU on 10/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import CoreLocation
import SIMSmeCore
import UIKit

class DPAGChatNoStreamViewController: DPAGChatBaseViewController, DPAGSendingDelegate, DPAGChatStreamInputVoiceViewControllerDelegate, DPAGContactsSelectionDistributionListMembersViewControllerDelegate, DPAGNavigationViewControllerStyler {
    static let cellContactIdentifier = "cellContactIdentifier"
    var toSendRecipientPersons: Set<DPAGContact> = Set()
    var persons: [DPAGContact] = []
    var selectedPersons: [DPAGContact] = []

    init(text: String?) {
        super.init(style: UITableView.Style.grouped)
        self.draftTextMessage = text
        self.sendingDelegate = self
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.selectedPersons = []
        self.performBlockInBackground { [weak self] in
            self?.createModelWithSelectedPersons([])
            self?.performBlockOnMainThread { [weak self] in
                self?.tableView.reloadData()
            }
        }
        let rightBarButtonItem = UIBarButtonItem(image: DPAGImageProvider.shared[.kImageBarButtonNavContact], style: .plain, target: self, action: #selector(DPAGChatNoStreamViewController.handleAddContacts))
        rightBarButtonItem.accessibilityLabel = DPAGLocalizedString("chat.new.searchbar.button_add_contacts.accessibilityLabel")
        rightBarButtonItem.accessibilityIdentifier = "chat.new.searchbar.button_add_contacts"
        rightBarButtonItem.isAccessibilityElement = true
        self.navigationItem.rightBarButtonItem = rightBarButtonItem
        DPAGSendMessageViewOptions.sharedInstance.messageGuidCitation = nil
    }

    override func viewDidAppear(_ animated: Bool) {
        let isFirstAppearOfView = self.isFirstAppearOfView
        super.viewDidAppear(animated)
        if isFirstAppearOfView {
            self.handleAddContacts()
        }
    }

    func getRecipients() -> [DPAGSendMessageRecipient] {
        self.toSendRecipientPersons.compactMap { (contact) -> DPAGSendMessageRecipient? in
            DPAGSendMessageRecipient(recipientGuid: contact.guid)
        }
    }

    override func sendMessageResponseBlock() -> DPAGServiceResponseBlock {
        let responseBlock: DPAGServiceResponseBlock = { [weak self] _, _, errorMessage in
            if let errorMessage = errorMessage {
                self?.handleMessageSendFailed(errorMessage)
                self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
            }
        }
        return responseBlock
    }

    func updateViewBeforeMessageWillSend() {}

    func updateViewAfterMessageWasSent() {
        self.didSendMessage()
        self.inputController?.updateViewAfterMessageWasSent()
    }

    override func isProximityMonitoringEnabled() -> Bool {
        if self.selectedPersons.count == 0, self.toSendRecipientPersons.count == 0 {
            return false
        }
        return super.isProximityMonitoringEnabled()
    }

    override func configureTableView() {
        super.configureTableView()
        self.tableView.register(DPAGApplicationFacadeUIViews.cellContactNib(), forCellReuseIdentifier: DPAGChatNoStreamViewController.cellContactIdentifier)
    }

    func configureSearchBar() {}

    func createModelWithSelectedPersons(_ selectedPersons: [DPAGContact]) {
        self.selectedPersons = selectedPersons
        self.updateTitle()
    }

    func updateTitle() {
        let newTitle = self.selectedPersons.count > 1 ? DPAGLocalizedString("chat.no_stream.title.multi") : DPAGLocalizedString("chat.no_stream.title.single")
        self.performBlockOnMainThread { [weak self] in
            self?.title = newTitle
        }
    }

    @objc
    func handleAddContacts() {
        self.inputController?.textView?.resignFirstResponder()
        let contactsSelected = DPAGSearchListSelection<DPAGContact>()
        contactsSelected.appendSelected(contentsOf: Set(self.selectedPersons))
        if let nextVC = DPAGApplicationFacade.preferences.viewControllerContactSelectionForIdent(.dpagSelectDistributionListMembersViewController, contactsSelected: contactsSelected), let nextVCConsumer = nextVC as? DPAGContactsSelectionDistributionListMembersDelegateConsumer {
            nextVCConsumer.delegate = self
            self.navigationController?.pushViewController(nextVC, animated: true)
        }
    }

    override func inputContainerCanExecuteSendMessage() -> Bool {
        if self.selectedPersons.count == 0, self.toSendRecipientPersons.count == 0 {
            let isTextViewFirstResponder = self.inputController?.textView?.isFirstResponder() ?? false
            if isTextViewFirstResponder {
                self.inputController?.textView?.resignFirstResponder()
            }
            let actionOK = UIAlertAction(titleIdentifier: "res.ok", style: .default, handler: { [weak self] _ in
                if isTextViewFirstResponder {
                    self?.inputController?.textView?.becomeFirstResponder()
                }
            })
            self.presentAlert(alertConfig: AlertConfig(titleIdentifier: "attention", messageIdentifier: "chat.no_stream.alert.select_contact_first", otherButtonActions: [actionOK]))
            return false
        } else {
            self.inputController?.textView?.resignFirstResponder()
        }
        return true
    }

    override func handleAddAttachment() {
        if self.selectedPersons.count == 0, self.toSendRecipientPersons.count == 0 {
            self.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: "chat.no_stream.alert.select_contact_first"))
        } else {
            super.handleAddAttachment()
        }
    }

    func inputContainerIsVoiceEnabled() -> Bool {
        true
    }

    override func inputContainerCanExecuteVoiceRecStart() -> Bool {
        if self.selectedPersons.count == 0, self.toSendRecipientPersons.count == 0 {
            self.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: "chat.no_stream.alert.select_contact_first"))
            return false
        }
        return true
    }

    func showContactSelection() {
        if self.selectedPersons.count > 0 {
            self.didSelect(contacts: Set(self.selectedPersons))
        } else if self.toSendRecipientPersons.count == 0 {
            self.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: "chat.no_stream.alert.select_contact_first"))
        }
    }

    func didSelectContact(contact: DPAGContact) {
        self.didSelect(contacts: Set([contact]))
    }

    func didSelect(contacts: Set<DPAGContact>) {
        self.toSendRecipientPersons = contacts
        self.selectedPersons = contacts.sorted { (c1, c2) -> Bool in
            c1.isBeforeInSearch(c2)
        }
        let selectedPersons = self.selectedPersons
        self.selectedPersons = []
        self.navigationController?.popToViewController(self, animated: true)
        self.performBlockInBackground { [weak self] in
            if let strongSelf = self {
                strongSelf.createModelWithSelectedPersons(selectedPersons)
                strongSelf.performBlockOnMainThread { [weak strongSelf] in
                    if let strongerSelf = strongSelf {
                        strongerSelf.tableView.reloadData()
                    }
                }
            }
        }
    }

    override func handleMessageSendFailed(_ errorMessage: String?) {
        super.handleMessageSendFailed(errorMessage)
        DPAGProgressHUD.sharedInstance.hide(true)
    }

    func didSendMessage() {
        self.inputController?.resetSendOptions()
        let block = {
            let recipients = self.getRecipients()
            if recipients.count == 1, let recipient = recipients.first, let recipientContact = DPAGApplicationFacade.cache.contact(for: recipient.recipientGuid), let streamGuid = recipientContact.streamGuid {
                DPAGChatHelper.openChatStreamView(streamGuid, navigationController: self.navigationController) { _ in
                    DPAGProgressHUD.sharedInstance.hide(true)
                }
            } else if let viewControllers = self.navigationController?.viewControllers {
                for vc in viewControllers where vc is DPAGChatsListViewControllerProtocol {
                    DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                        self?.navigationController?.popToViewController(vc, animated: true)
                    }
                    break
                }
            }
        }
        if Thread.isMainThread, DPAGProgressHUD.sharedInstance.isHUDVisible() == false {
            DPAGProgressHUD.sharedInstance.showForBackgroundProcess(false) { _ in
                block()
            }
        } else {
            block()
        }
    }
}

extension DPAGChatNoStreamViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellDequeued = tableView.dequeueReusableCell(withIdentifier: DPAGChatNoStreamViewController.cellContactIdentifier, for: indexPath)
        guard let cell = cellDequeued as? (UITableViewCell & DPAGContactCellProtocol) else { return cellDequeued }
        let person = self.selectedPersons[indexPath.row]
        self.configureCell(cell, withPerson: person)
        return cell
    }

    @discardableResult
    func configureCell(_ cell: UITableViewCell & DPAGContactCellProtocol, withPerson person: DPAGContact) -> Bool {
        cell.update(contact: person)
        if self.selectedPersons.contains(person) {
            cell.imageViewCheck.isHidden = false
        } else {
            cell.imageViewCheck.isHidden = true
        }
        return true
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        self.selectedPersons.count
    }

    func tableView(_: UITableView, titleForHeaderInSection _: Int) -> String? {
        nil
    }

    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        1
    }

    func tableView(_: UITableView, viewForHeaderInSection _: Int) -> UIView? {
        nil
    }

    func tableView(_: UITableView, heightForFooterInSection _: Int) -> CGFloat {
        1
    }

    func tableView(_: UITableView, viewForFooterInSection _: Int) -> UIView? {
        let view = UIView()
        view.backgroundColor = .clear
        view.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        return view
    }

    func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        DPAGConstantsGlobal.kContactCellHeight
    }
}

extension DPAGChatNoStreamViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if self.selectedPersons.count > indexPath.row { self.toSendRecipientPersons.remove(self.selectedPersons[indexPath.row])
            self.selectedPersons.remove(at: indexPath.row)
        }
        tableView.beginUpdates()
        tableView.deleteRows(at: [indexPath], with: .automatic)
        tableView.endUpdates()
        self.updateTitle()
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == UITableViewCell.EditingStyle.delete {
            self.selectedPersons.remove(at: indexPath.row)
            tableView.beginUpdates()
            tableView.deleteRows(at: [indexPath], with: .automatic)
            tableView.endUpdates()
            self.updateTitle()
            return
        }
    }

    func tableView(_: UITableView, canEditRowAt _: IndexPath) -> Bool {
        true
    }

    func tableView(_: UITableView, shouldShowMenuForRowAt _: IndexPath) -> Bool {
        false
    }

    func tableView(_: UITableView, canPerformAction _: Selector, forRowAt _: IndexPath, withSender _: Any?) -> Bool {
        false
    }
}
