//
//  DPAGNewFileChatViewController.swift
//  SIMSme
//
//  Created by RBU on 29/01/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGNewFileChatViewController: DPAGReceiverSelectionViewController, DPAGNewFileChatViewControllerProtocol {
    private weak var delegate: DPAGNewChatDelegate?

    private let fileURL: URL

    private var fileSize: Int64 = 0

    private var cleanUpOnDisappear = false

    init(delegate: DPAGNewChatDelegate?, fileURL: URL) {
        self.delegate = delegate
        self.fileURL = fileURL

        super.init()

        NotificationCenter.default.addObserver(self, selector: #selector(appUIReadyWithPrivateKey), name: DPAGStrings.Notification.Application.UI_IS_READY_WITH_PRIVATE_KEY, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc
    private func appUIReadyWithPrivateKey() {
        self.cleanUpOnDisappear = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        self.title = DPAGLocalizedString("chats.title.newFileChat")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        var fileAttributesRead: [FileAttributeKey: Any]?

        do {
            fileAttributesRead = try FileManager.default.attributesOfItem(atPath: self.fileURL.path)
        } catch let error as NSError {
            DPAGLog(error)
        }

        let actionOK = UIAlertAction(titleIdentifier: "res.ok", style: .default, handler: { [weak self] _ in

            self?.navigationController?.popViewController(animated: true)
        })

        if let fileAttributes = fileAttributesRead {
            if let fileType = fileAttributes[.type] as? FileAttributeType, fileType == .typeDirectory {
                var errorMessage = "chat.message.fileOpen.error.foldersNotImplemented.message"
                let filename = fileURL.lastPathComponent

                if filename.hasSuffix("pages") || filename.hasSuffix("numbers") || filename.hasSuffix("keynote") || filename.hasSuffix("key") {
                    errorMessage = "chat.message.fileOpen.error.foldersNotImplemented.message.pages"
                }
                self.presentAlert(alertConfig: AlertConfig(titleIdentifier: "attention", messageIdentifier: errorMessage, otherButtonActions: [actionOK]))
            } else if let fileSize = fileAttributes[.size] as? NSNumber {
                self.fileSize = fileSize.int64Value

                if fileSize.uint64Value <= 0 || fileSize.uint64Value > DPAGApplicationFacade.preferences.maxFileSize || (AppConfig.isShareExtension && !DPAGHelper.canPerformRAMBasedJSON(ofSize: UInt(fileSize.uint64Value))) {
                    self.presentAlert(alertConfig: AlertConfig(titleIdentifier: "attention", messageIdentifier: "chat.message.fileOpen.error.fileSize.message", otherButtonActions: [actionOK]))
                }
            } else {
                self.presentAlert(alertConfig: AlertConfig(titleIdentifier: "attention", messageIdentifier: "chat.message.fileOpen.error.fileSizeNotAvailable.message", otherButtonActions: [actionOK]))
            }
        } else {
            self.presentAlert(alertConfig: AlertConfig(titleIdentifier: "attention", messageIdentifier: "chat.message.fileOpen.error.fileNotAvailable.message", otherButtonActions: [actionOK]))
        }

        if self.presentedViewController == nil {
            if DPAGApplicationFacade.preferences.canSendMedia == false {
                self.presentAlert(alertConfig: AlertConfig(titleIdentifier: "mdm.alert.actionNotAllowed.title", messageIdentifier: "mdm.alert.actionNotAllowed.message", otherButtonActions: [actionOK]))
            }
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        if self.cleanUpOnDisappear {
            try? FileManager.default.removeItem(at: self.fileURL)
        }
    }

    override func didSelectReceiver(_ receiver: DPAGObject) {
        var message = DPAGLocalizedString("chat.message.fileOpen.willSendTo.message")
        var persons = ""
        var guidContact: String?
        var guidGroup: String?

        if let group = receiver as? DPAGGroup, let groupName = group.name {
            guidGroup = group.guid
            persons = groupName
        } else if let contact = receiver as? DPAGContact {
            guidContact = contact.guid
            persons = contact.displayName
        }

        message = String(format: message, self.fileURL.lastPathComponent, DPAGFormatter.fileSize.string(fromByteCount: self.fileSize), persons)

        let actionOK = UIAlertAction(titleIdentifier: "res.ok", style: .default, handler: { [weak self] _ in

            guard let strongSelf = self else { return }

            strongSelf.cleanUpOnDisappear = false

            if let contactGuid = guidContact {
                NotificationCenter.default.post(name: DPAGStrings.Notification.Menu.MENU_SHOW_CHATS, object: nil, userInfo: [DPAGStrings.Notification.Menu.MENU_SHOW_CHATS__USERINFO_KEY__CONTACT_GUID: contactGuid, DPAGStrings.Notification.Menu.MENU_SHOW_CHATS__USERINFO_KEY__FILE_URL: strongSelf.fileURL])
            } else if let groupGuid = guidGroup {
                strongSelf.delegate?.startChatWithGroup(groupGuid, fileURL: strongSelf.fileURL)
            }
        })

        self.presentAlert(alertConfig: AlertConfig(titleIdentifier: "chat.message.fileOpen.willSendTo.title", messageIdentifier: message, cancelButtonAction: .cancelDefault, otherButtonActions: [actionOK]))
    }
}
