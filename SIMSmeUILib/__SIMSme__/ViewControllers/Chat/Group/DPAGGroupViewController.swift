//
//  DPAGNewGroupViewController.swift
//  SIMSme
//
//  Created by RBU on 28/04/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import AVFoundation
import MobileCoreServices
import Photos
import SIMSmeCore
import UIKit

class DPAGGroupViewController: DPAGViewControllerWithKeyboard, DPAGNavigationViewControllerStyler {
    static let MemberCellIdentifier = "MemberCellIdentifier"
    static let AdminCellIdentifier = "AdminCellIdentifier"
    static let SilentCellIdentifier = "SilentCellIdentifier"
    static let headerIdentifier = "headerIdentifier"
    static let MAXLENGTH_GROUP_NAME = 30

    var needsGroupImageUpdate = false
    var isAdmin = false
    var isOwner = false
    var groupGuid: String?
    var ownerGuid: String?
    var members = Set<DPAGContact>()
    var membersSorted: [DPAGContact] = []
    var admins = Set<DPAGContact>()
    var adminsSorted: [DPAGContact] = []
    var owners = Set<DPAGContact>()
    var adminsFixed = Set<DPAGContact>()
    var groupName: String?
    var accountGuid: String?
    var accountProfileName: String?
    var isDisappearing: Bool = false
    var needsGroupNameUpdate = false
    var needsUpdateMembers = false
    var setSilentHelper = SetSilentHelper(chatType: .group)
    var silentStateObservation: NSKeyValueObservation?
    let conversationActionHelper = ConversationActionHelper()
    
    func getEditOptions() -> [AlertOption] {
        var alertOptions: [AlertOption] = []
        
        let editGroupOption = AlertOption(title: DPAGLocalizedString("chat.group.button.edit"), style: .default, image: DPAGImageProvider.shared[.kPencilCircle], textAlignment: CATextLayerAlignmentMode.center, accesibilityIdentifier: "chat.group.button.edit", handler: { [weak self] in
            if let strongSelf = self {
                if strongSelf.isAdmin || strongSelf.isOwner {
                    strongSelf.isEditing = true
                    strongSelf.buttonGroupImage.isHidden = false
                    strongSelf.textFieldGroupName.isEnabled = true
                    strongSelf.textFieldGroupName.backgroundColor = DPAGColorProvider.shared[.searchBarTextFieldBackground]
                    strongSelf.textFieldGroupName.selectedTextRange = strongSelf.textFieldGroupName.textRange(from: strongSelf.textFieldGroupName.beginningOfDocument, to: strongSelf.textFieldGroupName.endOfDocument)
                    strongSelf.textFieldGroupName.becomeFirstResponder()
                }
            }
        })
        alertOptions.append(editGroupOption)
        return alertOptions
    }
    
    @objc
    private func showEditGroupOptions(_: Any?) {
        var alertOptions: [AlertOption] = getEditOptions()

        alertOptions.append(AlertOption(title: DPAGLocalizedString("res.cancel"), style: .cancel, textAlignment: CATextLayerAlignmentMode.center))
        let alertController = UIAlertController.controller(options: alertOptions.compactMap { $0 }, sourceView: editGroupButtonView)
        self.presentAlertController(alertController)
    }

    @IBOutlet var editGroupButton: UIButton! {
        didSet {
            self.editGroupButton.addTarget(self, action: #selector(showEditGroupOptions(_:)), for: .touchUpInside)
            self.editGroupButton.accessibilityIdentifier = "chat.group.button.edit"
            self.editGroupButton.setImage(DPAGImageProvider.shared[.kEdit]?.imageWithTintColor(DPAGColorProvider.shared[.buttonTint]), for: .normal)
            self.editGroupButton.tintColor = DPAGColorProvider.shared[.buttonTint]
        }
    }
    
    @IBOutlet var editGroupButtonView: UIView! {
        didSet {
            self.editGroupButtonView.layer.cornerRadius = self.editGroupButtonView.frame.size.width / 2
            self.editGroupButtonView.layer.masksToBounds = true
            self.editGroupButtonView.backgroundColor = DPAGColorProvider.shared[.buttonBackground]
        }
    }

    @IBOutlet var muteButton: UIButton! {
        didSet {
            self.muteButton.accessibilityIdentifier = "chats.group.selectImage"
            switch self.setSilentHelper.currentSilentState {
                case .none:
                    self.muteButton.setImage(DPAGImageProvider.shared[.kBell], for: .normal)
                default:
                    self.muteButton.setImage(DPAGImageProvider.shared[.kBellSlash], for: .normal)
            }
            self.muteButton.tintColor = DPAGColorProvider.shared[.buttonTint]
            self.muteButton.addTargetClosure { [weak self] _ in
                guard let strongSelf = self else { return }
                let nextVC = DPAGApplicationFacadeUIContacts.setSilentVC(setSilentHelper: strongSelf.setSilentHelper)
                strongSelf.navigationController?.pushViewController(nextVC, animated: true)
            }
        }
    }
    
    @IBOutlet var muteButtonView: UIView! {
        didSet {
            self.muteButtonView.layer.cornerRadius = self.muteButtonView.frame.size.width / 2
            self.muteButtonView.layer.masksToBounds = true
            self.muteButtonView.backgroundColor = DPAGColorProvider.shared[.buttonBackground]
        }
    }
    
    func getExportOption() -> AlertOption? {
        if DPAGApplicationFacade.preferences.isChatExportAllowed {
            return AlertOption(title: DPAGLocalizedString("chat.list.action.export.group"), style: .default, image: DPAGImageProvider.shared[.kShare], textAlignment: CATextLayerAlignmentMode.center, accesibilityIdentifier: "buttonExportChat", handler: { [weak self] in
                guard let streamGuid = self?.groupGuid else { return }
                let actionOK = UIAlertAction(titleIdentifier: "res.ok", style: .destructive, handler: { [weak self] _ in
                    self?.exportStreamWithStreamGuid(streamGuid)
                })
                self?.presentAlert(alertConfig: AlertConfig(titleIdentifier: "chat.message.exportChat.warning.title", messageIdentifier: "chat.message.exportChat.warning.message", cancelButtonAction: .cancelDefault, otherButtonActions: [actionOK]))
            })
        }
        return nil
    }
    
    func clearContentOption() -> AlertOption {
        AlertOption(title: DPAGLocalizedString("chat.list.action.removeMessages.group"), style: .default, image: DPAGImageProvider.shared[.kClear], textAlignment: CATextLayerAlignmentMode.center, accesibilityIdentifier: "buttonDeleteChatContent", handler: { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.conversationActionHelper.showClearChatPopup(viewController: strongSelf, streamGuid: self?.groupGuid)
        })
    }
    
    func getMoreOptions() -> [AlertOption] {
        var options: [AlertOption] = []
        if let exportOption = getExportOption() {
            options.append(exportOption)
        }
        options.append(clearContentOption())
        return options
    }
    
    @objc
    private func showMoreOptions(_: Any?) {
        var alertOptions: [AlertOption] = self.getMoreOptions()

        alertOptions.append(AlertOption(title: DPAGLocalizedString("res.cancel"), style: .cancel, textAlignment: CATextLayerAlignmentMode.center))
        let alertController = UIAlertController.controller(options: alertOptions.compactMap { $0 }, sourceView: moreButtonView)
        self.presentAlertController(alertController)
    }
    
    @IBOutlet var moreButton: UIButton! {
        didSet {
            self.moreButton.addTarget(self, action: #selector(showMoreOptions(_:)), for: .touchUpInside)
            self.moreButton.accessibilityIdentifier = "chats.group.selectImage"
            self.moreButton.setImage(DPAGImageProvider.shared[.kEllipsis]?.imageWithTintColor(DPAGColorProvider.shared[.buttonTint]), for: .normal)
            self.moreButton.tintColor = DPAGColorProvider.shared[.buttonTint]
        }
    }
    
    @IBOutlet var moreButtonView: UIView! {
        didSet {
            self.moreButtonView.layer.cornerRadius = self.moreButtonView.frame.size.width / 2
            self.moreButtonView.layer.masksToBounds = true
            self.moreButtonView.backgroundColor = DPAGColorProvider.shared[.buttonBackground]

        }
    }
    
    @IBOutlet var viewConfidence: UIView!
    @IBOutlet var scrollView: UIScrollView!

    @IBOutlet var imageViewGroup: UIImageView! {
        didSet {
            self.imageViewGroup.image = DPAGImageProvider.shared[.kImagePlaceholderGroup]
            self.imageViewGroup.layer.cornerRadius = self.imageViewGroup.frame.size.width / 2.0
            self.imageViewGroup.layer.masksToBounds = true
        }
    }

    @IBOutlet var topView: UIView! {
        didSet {
            self.topView.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        }
    }
    
    @IBOutlet var buttonGroupImage: UIButton! {
        didSet {
            self.buttonGroupImage.layer.cornerRadius = self.buttonGroupImage.frame.size.width / 2
            self.buttonGroupImage.layer.masksToBounds = true
            self.buttonGroupImage.addTarget(self, action: #selector(selectImageForGroup(_:)), for: .touchUpInside)
            self.buttonGroupImage.accessibilityIdentifier = "chats.group.selectImage"
            self.buttonGroupImage.setImage(DPAGImageProvider.shared[.kImageAddPhoto], for: .normal)
            self.buttonGroupImage.backgroundColor = DPAGColorProvider.shared[.imageSelectorBackground]
            self.buttonGroupImage.tintColor = DPAGColorProvider.shared[.imageSelectorTint]
        }
    }

    @IBOutlet var textFieldGroupName: DPAGTextField! {
        didSet {
            self.textFieldGroupName.configureAsTitle()
            self.textFieldGroupName.accessibilityIdentifier = "chat.group.topicInput"
            self.textFieldGroupName.attributedPlaceholder = NSAttributedString(string: DPAGLocalizedString("chat.group.topicInputPlaceholder"), attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
            self.textFieldGroupName.returnKeyType = .done
            self.textFieldGroupName.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
           
        }
    }

    @IBOutlet var memberListLabel: UILabel! {
        didSet {
            self.memberListLabel.textColor = DPAGColorProvider.shared[.labelText]
            self.memberListLabel.font = UIFont.kFontFootnote
            self.memberListLabel.textAlignment = .center
        }
    }
    
    @IBOutlet var membersHeaderLabel: UILabel! {
        didSet {
            self.membersHeaderLabel.text = "  " + DPAGLocalizedString("chat.group.label.members").uppercased()
            self.membersHeaderLabel.textColor = DPAGColorProvider.shared[.labelText]
            self.membersHeaderLabel.font = UIFont.kFontFootnote
        }
    }
    @IBOutlet var tableViewMember: UITableView! {
        didSet {
            self.tableViewMember.accessibilityIdentifier = "tableViewMember"
        }
    }

    @IBOutlet var constraintTableViewMemberHeight: NSLayoutConstraint!
    @IBOutlet var adminsHeaderLabel: UILabel! {
        didSet {
            self.adminsHeaderLabel.text = "  " + DPAGLocalizedString("chat.group.label.admin").uppercased()
            self.adminsHeaderLabel.textColor = DPAGColorProvider.shared[.labelText]
            self.adminsHeaderLabel.font = UIFont.kFontFootnote
        }
    }
    
    @IBOutlet var tableViewAdmins: UITableView! {
        didSet {
            self.tableViewAdmins.accessibilityIdentifier = "tableViewAdmins"
        }
    }

    @IBOutlet var constraintTableViewAdminsHeight: NSLayoutConstraint!

    deinit {
        self.silentStateObservation?.invalidate()
    }

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        self.createModel()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // TODO:
    override func viewDidLoad() {
        super.viewDidLoad()
        self.configureNavigationBar()
        self.configureTableViews()
        self.configureSetSilentHelper()
        self.textFieldGroupName.delegate = self
        let maxMembers = DPAGApplicationFacade.preferences.maxGroupMembers
        self.memberListLabel?.text = "\(self.members.count + self.admins.count) " + DPAGLocalizedString("chat.group.label.membersCount") + " \(maxMembers)"
        self.view.setNeedsLayout()
        self.view.layoutIfNeeded()
        self.view.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
    }

    private func configureSetSilentHelper() {
        self.silentStateObservation = self.setSilentHelper.observe(\.silentStateChange, options: [.new]) { [weak self] _, _ in
            self?.performBlockOnMainThread { [weak self] in
                if let strongSelf = self {
                    switch strongSelf.setSilentHelper.currentSilentState {
                        case .none:
                            strongSelf.muteButton.setImage(DPAGImageProvider.shared[.kBell]?.imageWithTintColor(DPAGColorProvider.shared[.buttonTint]), for: .normal)
                        default:
                            strongSelf.muteButton.setImage(DPAGImageProvider.shared[.kBellSlash]?.imageWithTintColor(DPAGColorProvider.shared[.buttonTint]), for: .normal)
                    }
                }
            }
        }
    }

    func configureNavigationBar() {}

    func configureTableViews() {
        self.membersHeaderLabel.isHidden = self.members.count == 0
        self.tableViewMember.register(DPAGApplicationFacadeUIViews.cellContactNib(), forCellReuseIdentifier: DPAGGroupViewController.MemberCellIdentifier)
        self.tableViewMember.separatorStyle = .none
        self.tableViewMember.rowHeight = DPAGConstantsGlobal.kContactCellHeight
        self.tableViewMember.dataSource = self
        self.tableViewMember.delegate = self
        self.tableViewMember.isScrollEnabled = false
        self.tableViewMember.sectionFooterHeight = 0

        self.tableViewAdmins.register(DPAGApplicationFacadeUIViews.cellContactNib(), forCellReuseIdentifier: DPAGGroupViewController.AdminCellIdentifier)
        self.tableViewAdmins.separatorStyle = .none
        self.tableViewAdmins.rowHeight = DPAGConstantsGlobal.kContactCellHeight
        self.tableViewAdmins.dataSource = self
        self.tableViewAdmins.delegate = self
        self.tableViewAdmins.isScrollEnabled = false
        self.tableViewAdmins.sectionFooterHeight = 0
    }

    func createModel() {
        if let account = DPAGApplicationFacade.cache.account {
            self.accountGuid = account.guid
            self.ownerGuid = account.guid
            self.isAdmin = true
            self.isOwner = true
            if let owner = DPAGApplicationFacade.cache.contact(for: account.guid) {
                self.admins.insert(owner)
                self.owners.insert(owner)
                self.adminsFixed.insert(owner)
            }
            self.adminsSorted = self.admins.sorted { (c1, c2) -> Bool in
                c1.isBeforeInSearch(c2)
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let groupGuid = self.groupGuid, let group = DPAGApplicationFacade.cache.group(for: groupGuid) {
            self.configureConfidenceGui(group.confidenceState)
        } else {
            self.configureConfidenceGui(.low)
        }
        self.isDisappearing = false
        if self.needsGroupImageUpdate {
            self.highlightRightButton((self.textFieldGroupName?.text?.trimmingCharacters(in: .whitespaces).isEmpty ?? true) == false)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.isDisappearing = true
    }

    func highlightRightButton(_ bEnabled: Bool) {
        if self.navigationItem.rightBarButtonItem?.isEnabled != bEnabled {
            if self.isDisappearing == false {
                self.navigationItem.rightBarButtonItem?.isEnabled = false
                self.performBlockInBackground {
                    Thread.sleep(forTimeInterval: 0.2)
                    self.performBlockOnMainThread {
                        self.navigationItem.rightBarButtonItem?.isEnabled = true
                        self.performBlockInBackground {
                            Thread.sleep(forTimeInterval: 0.2)
                            self.performBlockOnMainThread {
                                self.navigationItem.rightBarButtonItem?.isEnabled = false
                                self.performBlockInBackground {
                                    Thread.sleep(forTimeInterval: 0.2)
                                    self.performBlockOnMainThread {
                                        self.navigationItem.rightBarButtonItem?.isEnabled = bEnabled
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    func configureConfidenceGui(_ confidenceStatus: DPAGConfidenceState) {
        self.viewConfidence.backgroundColor = UIColor.confidenceStatusToColor(confidenceStatus, isActive: true)
    }

    func grantAdminToMember(at indexPath: IndexPath) {
        if self.isAdmin == false, self.isOwner == false {
            return
        }
        self.tableViewMember.setEditing(false, animated: true)
        self.tableViewMember.beginUpdates()
        let newAdmin = self.membersSorted.remove(at: indexPath.row)
        self.members.remove(newAdmin)
        self.admins.insert(newAdmin)
        self.adminsSorted = self.admins.sorted { (c1, c2) -> Bool in
            c1.isBeforeInSearch(c2)
        }
        self.tableViewMember.deleteRows(at: [indexPath], with: .automatic)
        self.tableViewAdmins.reloadData()
        self.tableViewMember.endUpdates()
        self.highlightRightButton((self.textFieldGroupName?.text?.trimmingCharacters(in: .whitespaces).isEmpty ?? true) == false)
        self.needsUpdateMembers = true
    }

    @objc
    open override func handleDesignColorsUpdated() {
        super.handleDesignColorsUpdated()
        if isEditing {
            self.textFieldGroupName.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
        } else {
            self.textFieldGroupName.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        }
        self.view.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
        self.memberListLabel.textColor = DPAGColorProvider.shared[.labelText]
        self.muteButton.tintColor = DPAGColorProvider.shared[.buttonTint]
        self.muteButtonView.backgroundColor = DPAGColorProvider.shared[.buttonBackground]
        self.moreButton.tintColor = DPAGColorProvider.shared[.buttonTint]
        self.moreButtonView.backgroundColor = DPAGColorProvider.shared[.buttonBackground]
        self.topView.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        self.buttonGroupImage.backgroundColor = DPAGColorProvider.shared[.imageSelectorBackground]
        self.buttonGroupImage.tintColor = DPAGColorProvider.shared[.imageSelectorTint]
        self.adminsHeaderLabel.textColor = DPAGColorProvider.shared[.labelText]
        self.editGroupButton.tintColor = DPAGColorProvider.shared[.buttonTint]
        self.membersHeaderLabel.textColor = DPAGColorProvider.shared[.labelText]
        if self.isAdmin {
            self.editGroupButtonView.backgroundColor = DPAGColorProvider.shared[.buttonBackground]
        } else {
            self.editGroupButtonView.backgroundColor = DPAGColorProvider.shared[.buttonBackgroundDisabled]
        }
        self.editGroupButton.setImage(DPAGImageProvider.shared[.kEdit]?.imageWithTintColor(DPAGColorProvider.shared[.buttonTint]), for: .normal)
        self.moreButton.setImage(DPAGImageProvider.shared[.kEllipsis]?.imageWithTintColor(DPAGColorProvider.shared[.buttonTint]), for: .normal)
        switch self.setSilentHelper.currentSilentState {
            case .none:
                self.muteButton.setImage(DPAGImageProvider.shared[.kBell]?.imageWithTintColor(DPAGColorProvider.shared[.buttonTint]), for: .normal)
            default:
                self.muteButton.setImage(DPAGImageProvider.shared[.kBellSlash]?.imageWithTintColor(DPAGColorProvider.shared[.buttonTint]), for: .normal)
        }
    }

    @objc
    override func handleViewTapped(_: Any?) {
        self.textFieldGroupName?.resignFirstResponder()
    }

    override func handleKeyboardWillHide(_ aNotification: Notification) {
        self.configureNavigationBar()
        super.handleKeyboardWillHide(aNotification, scrollView: self.scrollView)
    }

    override func handleKeyboardWillShow(_ aNotification: Notification) {
        self.setRightBarButtonItem(image: DPAGImageProvider.shared[.kImageBarButtonNavCheck], action: #selector(handleViewTapped(_:)), accessibilityLabelIdentifier: "navigation.done")
        super.handleKeyboardWillShow(aNotification, scrollView: self.scrollView, viewVisible: self.textFieldGroupName)
    }

    @objc
    private func selectImageForGroup(_: Any?) {
        PictureButtonHandler.handlePickPictureButtonTapped(viewControllerWithImagePicker: self)
    }

    lazy var rowActionDeleteMember: UITableViewRowAction = UITableViewRowAction(style: .destructive, title: DPAGLocalizedString("group.administration.row_action.remove_member")) { [weak self] _, indexPath in
        guard let strongSelf = self else { return }
        strongSelf.tableView(strongSelf.tableViewMember, commit: .delete, forRowAt: indexPath)
    }

    lazy var rowActionMoreMember: UITableViewRowAction = UITableViewRowAction(style: .normal, title: DPAGLocalizedString("group.administration.row_action.more")) { _, indexPath in
        let grantAdmin = AlertOption(title: DPAGLocalizedString("group.administration.action.grant_admin"),
                                     style: .default,
                                     accesibilityIdentifier: "group.administration.action.grant_admin",
                                     handler: { [weak self] in
                                         self?.grantAdminToMember(at: indexPath)
        })
        let cancel = AlertOption(title: DPAGLocalizedString("res.cancel"),
                                 style: .cancel,
                                 accesibilityIdentifier: "res.cancel",
                                 handler: { [weak self] in
                                     self?.tableViewMember.setEditing(false, animated: true)
                                     self?.tableViewAdmins.setEditing(false, animated: true)
        })
        let alertController = UIAlertController.controller(options: [grantAdmin, cancel], withStyle: .alert, accessibilityIdentifier: "action_more")
        self.presentAlertController(alertController)
    }

    lazy var rowActionDeleteAdmin: UITableViewRowAction = UITableViewRowAction(style: .destructive, title: DPAGLocalizedString("group.administration.row_action.remove_admin")) { [weak self] _, indexPath in
        guard let strongSelf = self else { return }
        strongSelf.tableView(strongSelf.tableViewAdmins, commit: .delete, forRowAt: indexPath)
    }

    private func exportStreamWithStreamGuid(_ streamGuid: String) {
        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in
            if let fileURLTemp = DPAGApplicationFacade.messageWorker.exportStreamToURLWithStreamGuid(streamGuid) {
                DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                    if let strongSelf = self {
                        let activityVC = DPAGActivityViewController(activityItems: [fileURLTemp], applicationActivities: nil)
                        activityVC.completionWithItemsHandler = { _, _, _, _ in
                            do {
                                try FileManager.default.removeItem(at: fileURLTemp)
                            } catch {
                                DPAGLog(error)
                            }
                        }
                        strongSelf.present(activityVC, animated: true) {
                            UINavigationBar.appearance().barTintColor = .white
                            UINavigationBar.appearance().tintColor = .black
                            UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: UIColor.black]
                        }
                    }
                }
            } else {
                DPAGProgressHUD.sharedInstance.hide(true)
            }
        }
    }

    func loadSilentTill() {
        guard let groupGuid = self.groupGuid else { return }
        DPAGApplicationFacade.chatRoomWorker.readGroupSilentTill(groupGuid: groupGuid) { responseObject, _, errorMessage in
            if errorMessage == nil {
                self.setSilentHelper.currentSilentState = SetSilentHelper.silentStateFor(silentDate: responseObject as? Date)
            }
        }
    }
    
}
