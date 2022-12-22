//
//  DPAGReceiverSelectionViewController.swift
// ginlo
//
//  Created by RBU on 05/03/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import MagicalRecord
import SIMSmeCore
import UIKit

class DPAGReceiverSelectionChatViewController: DPAGTableViewControllerBackground {
    private static let ChatCellIdentifier = "ChatCellIdentifier"
    private var streamsForward: [DPAGContact] = []
    weak var streamDelegate: DPAGReceiverDelegate?

    override func configureTableView() {
        super.configureTableView()
        self.tableView.register(DPAGApplicationFacadeUIContacts.cellChatNib(), forCellReuseIdentifier: DPAGReceiverSelectionChatViewController.ChatCellIdentifier)
        self.tableView.separatorInset = .zero
        self.tableView.layoutMargins = .zero
        self.tableView.estimatedRowHeight = 96
        self.tableView.sectionFooterHeight = 0
        self.tableView.separatorStyle = .singleLine
        self.tableView.accessibilityLabel = DPAGLocalizedString("chats.title.chats")
        self.tableView.accessibilityIdentifier = "DPAGReceiverSelectionChatViewController"
    }

    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)
        if parent == nil {
            self.streamDelegate = nil
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.checkEmptyTable()
        self.createModel()
    }

    private func createModel() {
        self.performBlockInBackground { [weak self] in
            self?.createModelInBackground()
        }
    }

    private func createModelInBackground() {
        if AppConfig.isShareExtension {
            self.streamsForward.append(contentsOf: DPAGApplicationFacadeShareExt.cache.allChats().sorted(by: { (chat1, chat2) -> Bool in
                if let date1 = chat1.lastMessageDate {
                    if let date2 = chat2.lastMessageDate {
                        return date1 > date2
                    }
                    return true
                }
                return chat2.lastMessageDate == nil
            }))
        } else {
            self.streamsForward = DPAGApplicationFacade.contactsWorker.fetchChatStreamsForwarding()
        }
        self.performBlockOnMainThread { [weak self] in
            self?.checkEmptyTable()
            self?.tableView.reloadData()
        }
    }

    private func checkEmptyTable() {
        if self.streamsForward.count == 0 {
            self.tableView.setEmptyMessage(DPAGLocalizedString("receiver.selection.label.noChatsFound"))
            self.tableView.separatorStyle = .none
        } else {
            self.tableView.removeEmptyMessage()
            self.tableView.separatorStyle = .singleLine
        }
    }
}

extension DPAGReceiverSelectionChatViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        self.streamsForward.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let contact = self.streamsForward[indexPath.row]
        var retVal: UITableViewCell?
        var cell: (UITableViewCell & DPAGChatCellProtocol)?
        if let cellConfirmed = tableView.dequeueReusableCell(withIdentifier: DPAGReceiverSelectionChatViewController.ChatCellIdentifier, for: indexPath) as? (UITableViewCell & DPAGChatCellProtocol) {
            cellConfirmed.configure(with: contact)
            cell = cellConfirmed
        }
        cell?.selectionStyle = .default
        cell?.setNeedsUpdateConstraints()
        cell?.updateConstraintsIfNeeded()
        retVal = cell
        return retVal ?? UITableViewCell(style: .default, reuseIdentifier: "???")
    }
}

extension DPAGReceiverSelectionChatViewController: UITableViewDelegate {
    func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }

    func tableView(_: UITableView, heightForFooterInSection _: Int) -> CGFloat {
        1
    }

    func tableView(_: UITableView, willDisplayFooterView view: UIView, forSection _: Int) {
        (view as? UITableViewHeaderFooterView)?.backgroundView?.backgroundColor = .clear
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let contact = self.streamsForward[indexPath.row]
        self.streamDelegate?.didSelectReceiver(contact)
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

class DPAGReceiverSelectionGroupViewController: DPAGTableViewControllerBackground {
    private static let GroupCellIdentifier = "GroupCellIdentifier"

    private var streamsForward: [DPAGGroup] = []
    weak var streamDelegate: DPAGReceiverDelegate?

    override func configureTableView() {
        super.configureTableView()
        self.tableView.register(DPAGApplicationFacadeUIContacts.cellGroupNib(), forCellReuseIdentifier: DPAGReceiverSelectionGroupViewController.GroupCellIdentifier)
        self.tableView.separatorInset = .zero
        self.tableView.layoutMargins = .zero
        self.tableView.estimatedRowHeight = 96
        self.tableView.sectionFooterHeight = 0
        self.tableView.accessibilityLabel = DPAGLocalizedString("chat.list.filter.label.group")
        self.tableView.accessibilityIdentifier = "DPAGReceiverSelectionGroupViewController"
    }

    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)
        if parent == nil {
            self.streamDelegate = nil
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.checkEmptyTable()
        self.createModel()
    }

    private func createModel() {
        self.performBlockInBackground { [weak self] in
            self?.createModelInBackground()
        }
    }

    private func createModelInBackground() {
        let streamsFiltered: [DPAGGroup]
        if AppConfig.isShareExtension {
            streamsFiltered = DPAGApplicationFacadeShareExt.cache.allGroups().filter({ (group) -> Bool in
                group.isConfirmed && group.isDeleted == false && group.isReadOnly == false
            })
        } else {
            streamsFiltered = DPAGApplicationFacade.cache.allGroups().filter({ (group) -> Bool in
                group.isConfirmed && group.isDeleted == false && group.isReadOnly == false
            })
        }
        self.streamsForward = streamsFiltered.sorted(by: { (group1, group2) -> Bool in
            if let date1 = group1.lastMessageDate {
                if let date2 = group2.lastMessageDate {
                    return date1 > date2
                }
                return true
            }
            return group2.lastMessageDate == nil
        })
        self.performBlockOnMainThread { [weak self] in
            self?.checkEmptyTable()
            self?.tableView.reloadData()
        }
    }

    private func checkEmptyTable() {
        if self.streamsForward.count == 0 {
            self.tableView.setEmptyMessage(DPAGLocalizedString("receiver.selection.label.noGroupsFound"))
            self.tableView.separatorStyle = .none
        } else {
            self.tableView.removeEmptyMessage()
            self.tableView.separatorStyle = .singleLine
        }
    }
}

extension DPAGReceiverSelectionGroupViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        self.streamsForward.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellDequeued = tableView.dequeueReusableCell(withIdentifier: DPAGReceiverSelectionGroupViewController.GroupCellIdentifier, for: indexPath)
        guard let cellConfirmed = cellDequeued as? (UITableViewCell & DPAGGroupCellProtocol) else { return cellDequeued }
        let group = self.streamsForward[indexPath.row]
        cellConfirmed.configure(with: group)
        cellConfirmed.selectionStyle = .default
        cellConfirmed.setNeedsUpdateConstraints()
        cellConfirmed.updateConstraintsIfNeeded()
        return cellConfirmed
    }
}

extension DPAGReceiverSelectionGroupViewController: UITableViewDelegate {
    func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }

    func tableView(_: UITableView, heightForFooterInSection _: Int) -> CGFloat {
        1
    }

    func tableView(_: UITableView, willDisplayFooterView view: UIView, forSection _: Int) {
        (view as? UITableViewHeaderFooterView)?.backgroundView?.backgroundColor = .clear
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.streamDelegate?.didSelectReceiver(self.streamsForward[indexPath.row])
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

class DPAGReceiverSelectionContactsViewController: DPAGTableViewControllerBackground {
    static let ContactCellIdentifier = "ContactCellIdentifier"

    var streamsForward: [DPAGContact] = []
    weak var streamDelegate: DPAGReceiverDelegate?

    override func configureTableView() {
        super.configureTableView()
        self.tableView.register(DPAGApplicationFacadeUIViews.cellContactNib(), forCellReuseIdentifier: DPAGReceiverSelectionContactsViewController.ContactCellIdentifier)
        self.tableView.separatorInset = .zero
        self.tableView.layoutMargins = .zero
        self.tableView.estimatedRowHeight = DPAGConstantsGlobal.kContactCellHeight
        self.tableView.sectionFooterHeight = 0
        self.tableView.accessibilityLabel = DPAGLocalizedString("contacts.overViewViewControllerTitle")
        self.tableView.accessibilityIdentifier = "DPAGReceiverSelectionContactsViewController"
    }

    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)
        if parent == nil {
            self.streamDelegate = nil
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.checkEmptyTable()
        self.createModel()
    }

    private func createModel() {
        self.performBlockInBackground { [weak self] in
            self?.createModelInBackground()
        }
    }

    private func createModelInBackground() {
        self.streamsForward.removeAll()
        let contacts: Set<DPAGContact>
        if AppConfig.isShareExtension {
            let account = DPAGApplicationFacadeShareExt.cache.account
            contacts = DPAGApplicationFacadeShareExt.cache.allContactsLocal(entryType: .privat) { (contact) -> Bool in
                contact.guid != account?.guid
            }
        } else {
            contacts = DPAGApplicationFacade.contactsWorker.unblockedContacts(withReadOnly: false)
        }

        self.streamsForward = contacts.sorted(by: { (c1, c2) -> Bool in
            c1.isBeforeInSearch(c2)
        })
        self.performBlockOnMainThread { [weak self] in
            self?.checkEmptyTable()
            self?.tableView.reloadData()
        }
    }

    private func checkEmptyTable() {
        if self.streamsForward.count == 0 {
            self.tableView.setEmptyMessage(DPAGLocalizedString("contacts.invitation.noContacts"))
            self.tableView.separatorStyle = .none
        } else {
            self.tableView.removeEmptyMessage()
            self.tableView.separatorStyle = .singleLine
        }
    }
}

extension DPAGReceiverSelectionContactsViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        self.streamsForward.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellDequeued = tableView.dequeueReusableCell(withIdentifier: DPAGReceiverSelectionContactsViewController.ContactCellIdentifier, for: indexPath)
        guard let cellContact = cellDequeued as? (UITableViewCell & DPAGContactCellProtocol) else { return cellDequeued }
        let contact = self.streamsForward[indexPath.row]
        cellContact.update(contact: contact)
        cellContact.labelText.textColor = DPAGColorProvider.shared[.labelText]
        cellContact.accessoryView = nil
        cellContact.labelTextDetail.text = contact.statusMessageFallback
        cellContact.accessibilityIdentifier = "cell-\(indexPath.section)-\(indexPath.row)"
        return cellContact
    }

    func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }
}

extension DPAGReceiverSelectionContactsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.streamDelegate?.didSelectReceiver(self.streamsForward[indexPath.row])
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

class DPAGReceiverSelectionViewController: DPAGViewControllerBackground, DPAGReceiverDelegate, DPAGNavigationViewControllerStyler {
    enum Tab: Int {
        case activeChats,
            groups,
            contacts
    }

    private var activeTab = Tab.activeChats
    private let pageViewController = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
    private var pageChats: UIViewController = UIViewController()
    private var pageGroups: UIViewController = UIViewController()
    private var pageContacts: UIViewController = UIViewController()

    @IBOutlet private var stackView: UIStackView!
    @IBOutlet private var contentView: UIView!
    @IBOutlet private var viewButtonFrame: UIView!
    @IBOutlet private var btnStreamSelectionRecents: UIButton? {
        didSet {
            self.btnStreamSelectionRecents?.setTitle(DPAGLocalizedString("chat.list.filter.label.single").uppercased(), for: .normal)
            self.btnStreamSelectionRecents?.setTitleColor(DPAGColorProvider.shared[.buttonTintNoBackground], for: .normal)
            self.btnStreamSelectionRecents?.setTitleColor(DPAGColorProvider.shared[.buttonTintNoBackground], for: .selected)
            self.btnStreamSelectionRecents?.titleLabel?.font = UIFont.kFontFootnote
            self.btnStreamSelectionRecents?.setBackgroundImage(UIImage.tabControlImageSelected(height: 56), for: .selected)
            self.btnStreamSelectionRecents?.accessibilityIdentifier = "chat.list.filter.label.single"
            self.btnStreamSelectionRecents?.addTargetClosure { [weak self] _ in
                self?.showActiveChats()
            }
        }
    }

    @IBOutlet private var btnStreamSelectionGroups: UIButton? {
        didSet {
            self.btnStreamSelectionGroups?.setTitle(DPAGLocalizedString("chat.list.filter.label.group").uppercased(), for: .normal)
            self.btnStreamSelectionGroups?.setTitleColor(DPAGColorProvider.shared[.buttonTintNoBackground], for: .normal)
            self.btnStreamSelectionGroups?.setTitleColor(DPAGColorProvider.shared[.buttonTintNoBackground], for: .selected)
            self.btnStreamSelectionGroups?.titleLabel?.font = UIFont.kFontFootnote
            self.btnStreamSelectionGroups?.setBackgroundImage(UIImage.tabControlImageSelected(height: 56), for: .selected)
            self.btnStreamSelectionGroups?.accessibilityIdentifier = "chat.list.filter.label.group"
            self.btnStreamSelectionGroups?.addTargetClosure { [weak self] _ in
                self?.showGroups()
            }
        }
    }

    @IBOutlet private var btnStreamSelectionContacts: UIButton? {
        didSet {
            if AppConfig.isShareExtension { self.btnStreamSelectionContacts?.setTitle(((DPAGApplicationFacadeShareExt.cache.account?.isCompanyUserRestricted ?? false) ? DPAGApplicationFacadeShareExt.preferences.companyIndexName : nil) ?? DPAGLocalizedString("contacts.overViewViewControllerTitle").uppercased(), for: .normal)
            } else {
                self.btnStreamSelectionContacts?.setTitle(((DPAGApplicationFacade.cache.account?.isCompanyUserRestricted ?? false) ? DPAGApplicationFacade.preferences.companyIndexName : nil) ?? DPAGLocalizedString("contacts.overViewViewControllerTitle").uppercased(), for: .normal)
            }
            self.btnStreamSelectionContacts?.setTitleColor(DPAGColorProvider.shared[.buttonTintNoBackground], for: .normal)
            self.btnStreamSelectionContacts?.setTitleColor(DPAGColorProvider.shared[.buttonTintNoBackground], for: .selected)
            self.btnStreamSelectionContacts?.titleLabel?.font = UIFont.kFontFootnote
            self.btnStreamSelectionContacts?.setBackgroundImage(UIImage.tabControlImageSelected(height: 56), for: .selected)
            self.btnStreamSelectionContacts?.accessibilityIdentifier = "contacts.overViewViewControllerTitle"
            self.btnStreamSelectionContacts?.addTargetClosure { [weak self] _ in
                self?.showContacts()
            }
        }
    }

    override
    func handleDesignColorsUpdated() {
        self.btnStreamSelectionRecents?.setTitleColor(DPAGColorProvider.shared[.buttonTintNoBackground], for: .normal)
        self.btnStreamSelectionRecents?.setTitleColor(DPAGColorProvider.shared[.buttonTintNoBackground], for: .selected)
        self.btnStreamSelectionGroups?.setTitleColor(DPAGColorProvider.shared[.buttonTintNoBackground], for: .normal)
        self.btnStreamSelectionGroups?.setTitleColor(DPAGColorProvider.shared[.buttonTintNoBackground], for: .selected)
        self.btnStreamSelectionContacts?.setTitleColor(DPAGColorProvider.shared[.buttonTintNoBackground], for: .normal)
        self.btnStreamSelectionContacts?.setTitleColor(DPAGColorProvider.shared[.buttonTintNoBackground], for: .selected)
    }

    init() {
        super.init(nibName: "DPAGReceiverSelectionViewController", bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.configureUI()
    }

    private func configurePages() {
        if AppConfig.isShareExtension {
            if let nextVC = DPAGApplicationFacadeShareExt.viewControllerContactSelectionForIdent(.dpagSelectReceiverViewController, contactsSelected: DPAGSearchListSelection<DPAGContact>()), let nextVCConsumer = nextVC as? DPAGContactsSelectionReceiverDelegateConsumer {
                nextVCConsumer.delegate = self
                self.pageContacts = nextVC
            } else {
                let pageContacts = DPAGReceiverSelectionContactsViewController()
                pageContacts.streamDelegate = self
                self.pageContacts = pageContacts
            }
        } else {
            if let nextVC = DPAGApplicationFacade.preferences.viewControllerContactSelectionForIdent(.dpagSelectReceiverViewController, contactsSelected: DPAGSearchListSelection<DPAGContact>()), let nextVCConsumer = nextVC as? DPAGContactsSelectionReceiverDelegateConsumer {
                nextVCConsumer.delegate = self
                self.pageContacts = nextVC
            } else {
                let pageContacts = DPAGReceiverSelectionContactsViewController()
                pageContacts.streamDelegate = self
                self.pageContacts = pageContacts
            }
        }
        let pageGroups = DPAGReceiverSelectionGroupViewController()
        let pageChats = DPAGReceiverSelectionChatViewController()
        pageGroups.streamDelegate = self
        pageChats.streamDelegate = self
        self.pageGroups = pageGroups
        self.pageChats = pageChats
    }

    private func configureUI() {
        self.configurePages()
        self.pageViewController.willMove(toParent: self)
        self.addChild(self.pageViewController)
        self.pageViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.pageViewController.view.frame = self.contentView.bounds
        self.contentView.addSubview(self.pageViewController.view)
        self.pageViewController.didMove(toParent: self)
        self.showActiveChats()
        self.pageViewController.delegate = self
        self.pageViewController.dataSource = self
        self.definesPresentationContext = true
    }

    @objc
    private func showActiveChats() {
        self.activeTab = .activeChats
        self.btnStreamSelectionRecents?.isSelected = true
        self.btnStreamSelectionGroups?.isSelected = false
        self.btnStreamSelectionContacts?.isSelected = false
        self.btnStreamSelectionRecents?.accessibilityIdentifier = "chat.list.filter.label.single-show"
        self.btnStreamSelectionGroups?.accessibilityIdentifier = "chat.list.filter.label.group-hide"
        self.btnStreamSelectionContacts?.accessibilityIdentifier = "contacts.overViewViewControllerTitle-hide"
        if self.pageViewController.viewControllers?.last != self.pageChats {
            (self.pageChats as? DPAGReceiverSelectionChatViewController)?.streamDelegate = self
            self.pageViewController.setViewControllers([self.pageChats], direction: .forward, animated: true, completion: nil)
        }
    }

    @objc
    private func showGroups() {
        self.activeTab = .groups
        self.btnStreamSelectionRecents?.isSelected = false
        self.btnStreamSelectionGroups?.isSelected = true
        self.btnStreamSelectionContacts?.isSelected = false
        self.btnStreamSelectionRecents?.accessibilityIdentifier = "chat.list.filter.label.single-hide"
        self.btnStreamSelectionGroups?.accessibilityIdentifier = "chat.list.filter.label.group-show"
        self.btnStreamSelectionContacts?.accessibilityIdentifier = "contacts.overViewViewControllerTitle-hide"
        if self.pageViewController.viewControllers?.last != self.pageGroups {
            (self.pageGroups as? DPAGReceiverSelectionGroupViewController)?.streamDelegate = self
            self.pageViewController.setViewControllers([self.pageGroups], direction: .forward, animated: true, completion: nil)
        }
    }

    @objc
    private func showContacts() {
        self.activeTab = .contacts
        self.btnStreamSelectionRecents?.isSelected = false
        self.btnStreamSelectionGroups?.isSelected = false
        self.btnStreamSelectionContacts?.isSelected = true
        self.btnStreamSelectionRecents?.accessibilityIdentifier = "chat.list.filter.label.single-hide"
        self.btnStreamSelectionGroups?.accessibilityIdentifier = "chat.list.filter.label.group-hide"
        self.btnStreamSelectionContacts?.accessibilityIdentifier = "contacts.overViewViewControllerTitle-show"
        if self.pageViewController.viewControllers?.last != self.pageContacts {
            (self.pageContacts as? DPAGReceiverSelectionContactsViewController)?.streamDelegate = self
            (self.pageContacts as? DPAGContactsSelectionReceiverDelegateConsumer)?.delegate = self
            self.pageViewController.setViewControllers([self.pageContacts], direction: .forward, animated: true, completion: nil)
        }
    }

    func didSelectReceiver(_: DPAGObject) {}
}

extension DPAGReceiverSelectionViewController: DPAGReceiverSelectionViewControllerProtocol {
    func willPresentSearchController(_: UISearchController) {
        self.viewButtonFrame.isHidden = true
        self.stackView.layoutIfNeeded()
    }

    func willDismissSearchController(_: UISearchController) {
        self.viewButtonFrame.isHidden = false
        self.stackView.layoutIfNeeded()
    }
}

extension DPAGReceiverSelectionViewController: UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating _: Bool, previousViewControllers _: [UIViewController], transitionCompleted completed: Bool) {
        if completed {
            if pageViewController.viewControllers?.last == self.pageChats {
                self.showActiveChats()
            } else if pageViewController.viewControllers?.last == self.pageGroups {
                self.showGroups()
            } else if pageViewController.viewControllers?.last == self.pageContacts {
                self.showContacts()
            }
        }
    }
}

extension DPAGReceiverSelectionViewController: UIPageViewControllerDataSource {
    func pageViewController(_: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        if viewController == self.pageChats {
            (self.pageGroups as? DPAGReceiverSelectionGroupViewController)?.streamDelegate = self
            return self.pageGroups
        }
        if viewController == self.pageGroups {
            (self.pageContacts as? DPAGReceiverSelectionContactsViewController)?.streamDelegate = self
            (self.pageContacts as? DPAGContactsSelectionReceiverDelegateConsumer)?.delegate = self
            return self.pageContacts
        }
        return nil
    }

    func pageViewController(_: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        if viewController == self.pageGroups {
            (self.pageChats as? DPAGReceiverSelectionChatViewController)?.streamDelegate = self
            return self.pageChats
        }
        if viewController == self.pageContacts {
            (self.pageGroups as? DPAGReceiverSelectionGroupViewController)?.streamDelegate = self
            return self.pageGroups
        }
        return nil
    }
}
