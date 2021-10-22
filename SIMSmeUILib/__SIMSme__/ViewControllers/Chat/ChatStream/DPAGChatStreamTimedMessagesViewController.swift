//
//  DPAGChatStreamTimedMessagesViewController.swift
// ginlo
//
//  Created by RBU on 11/05/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import SIMSmeCore
import UIKit

class DPAGChatStreamTimedMessagesViewController: DPAGChatStreamBaseViewController, UITableViewDataSource, UITableViewDelegate {
    lazy var fetchedResultsControllerMessagesTimed: DPAGFetchedResultsControllerChatStreamTimedMessages = DPAGFetchedResultsControllerChatStreamTimedMessages(streamGuid: self.streamGuid) { [weak self] changes, messages in

        guard let strongSelf = self, strongSelf.isViewLoaded else {
            self?.messages = messages
            return
        }

        var hasNewRows = false
        var scrollToEnd = false

        CATransaction.begin()

        strongSelf.tableView.beginUpdates()

        strongSelf.messages = messages

        if changes.count > 0 {
            for change in changes {
                if let changedRow = change as? DPAGFetchedResultsControllerRowChange {
                    switch change.changeType {
                    case .update:
                        strongSelf.tableView.reloadRows(at: [changedRow.changedIndexPath], with: .none)
                    case .insert:
                        strongSelf.tableView.insertRows(at: [changedRow.changedIndexPath], with: .automatic)
                        hasNewRows = true
                    case .delete:
                        strongSelf.tableView.deleteRows(at: [changedRow.changedIndexPath], with: .automatic)
                    case .move:
                        if let changedIndexPathMovedTo = changedRow.changedIndexPathMovedTo {
                            strongSelf.tableView.moveRow(at: changedRow.changedIndexPath, to: changedIndexPathMovedTo)
                        }
                    @unknown default:
                        DPAGLog("Switch with unknown value: \(change.changeType.rawValue)", level: .warning)
                    }
                } else if let changedSection = change as? DPAGFetchedResultsControllerSectionChange {
                    switch change.changeType {
                    case .update:
                        strongSelf.tableView.reloadSections(IndexSet(integer: changedSection.changedSection), with: .none)
                    case .insert:
                        strongSelf.tableView.insertSections(IndexSet(integer: changedSection.changedSection), with: .automatic)
                        hasNewRows = true
                    case .delete:
                        strongSelf.tableView.deleteSections(IndexSet(integer: changedSection.changedSection), with: .automatic)
                    default:
                        break
                    }
                }
            }
        } else {
            strongSelf.tableView.reloadData()
        }
        scrollToEnd = (strongSelf.scrollToEnd || (hasNewRows && strongSelf.isAtEndOfScreen))

        CATransaction.setCompletionBlock { [weak self] in
            // animation has finished
            if scrollToEnd {
                self?.scrollTableViewToBottomAnimated(true)
            }
        }

        strongSelf.tableView.endUpdates()

        CATransaction.commit()

        // [self performSelectorOnMainThread:@selector(updateLoadMoreButtonVisibility) withObject:nil waitUntilDone:YES]

        if hasNewRows {
            strongSelf.performBlockInBackground { [weak self] in

                if let tableView = self?.tableView {
                    self?.performBlockOnMainThread { [weak self] in
                        self?.scrollViewDidScroll(tableView)
                    }
                }
                self?.updateNewMessagesCountAndBadge()
            }

            if DPAGSimsMeController.sharedInstance.chatsListViewController.tableView.numberOfRows(inSection: 0) > 0 {
                DPAGSimsMeController.sharedInstance.chatsListViewController.tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: false)
            }
        }
    }

    override init(streamGuid: String, streamState: DPAGChatStreamState) {
        super.init(streamGuid: streamGuid, streamState: streamState)
    }

    override var fetchedResultsController: DPAGFetchedResultsControllerChatStreamBase {
        self.fetchedResultsControllerMessagesTimed
    }

    override func configureNavBar() {}

    func isEditingEnabled() -> Bool {
        false
    }

    override func hasMessageInfo() -> Bool {
        false
    }
}

class DPAGChatStreamTimedMessagesPrivateViewController: DPAGChatStreamTimedMessagesViewController {
    override init(streamGuid: String, streamState _: DPAGChatStreamState) {
        super.init(streamGuid: streamGuid, streamState: .readOnly)

        self.showsInputController = false
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        self.setup()

        self.title = DPAGLocalizedString("chat.timedMessages.title") // self.stream?.contact?.contactName

        DPAGSendMessageViewOptions.sharedInstance.messageGuidCitation = nil
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
}

class DPAGChatStreamTimedMessagesGroupViewController: DPAGChatStreamTimedMessagesViewController {
    var group: DPAGGroup?

    override init(streamGuid: String, streamState _: DPAGChatStreamState) {
        self.group = DPAGApplicationFacade.cache.group(for: streamGuid)

        super.init(streamGuid: streamGuid, streamState: .readOnly)

        self.showsInputController = false
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        self.setup()

        self.title = DPAGLocalizedString("chat.timedMessages.title") // self.stream?.group?.groupName
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if self.state != .write {
            self.updateInputStateAnimated(false, canShowAlert: false, forceDisabled: true)
        }
    }
}
