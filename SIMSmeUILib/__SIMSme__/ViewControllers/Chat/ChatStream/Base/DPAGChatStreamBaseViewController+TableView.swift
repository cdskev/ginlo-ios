//
//  DPAGChatCellBaseViewController.swift
//  SIMSme
//
//  Created by RBU on 01/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import SIMSmeCore
import UIKit

extension DPAGChatCellBaseViewController {
    @objc
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let sectionHeader = tableView.dequeueReusableHeaderFooterView(withIdentifier: "header") as? (UITableViewHeaderFooterView & DPAGChatStreamSectionHeaderViewProtocol) else {
            return nil
        }
        sectionHeader.sectionTitle = self.titleForSection(section)
        return sectionHeader
    }

    @objc(tableView:cellForRowAtIndexPath:)
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = self.cellForMessageAtIndexPath(indexPath)
        cell?.setNeedsUpdateConstraints()
        cell?.updateConstraintsIfNeeded()
        if tableView.isEditing {
            cell?.selectionStyle = .default
        }
        if let cellSimple = cell as? DPAGSimpleMessageCellProtocol {
            cellSimple.labelText?.isUserInteractionEnabled = (tableView.isEditing == false)
        }
        return cell ?? UITableViewCell(style: .default, reuseIdentifier: "???")
    }

    @objc
    func titleForSection(_: Int) -> String? {
        nil
    }

    @objc
    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        DPAGChatStreamBaseViewController.sectionHeaderHeight + 16
    }

    @objc
    func tableView(_: UITableView, viewForFooterInSection _: Int) -> UIView? {
        let retVal = UIView(frame: CGRect(origin: .zero, size: CGSize(width: 0, height: 1)))
        retVal.backgroundColor = .clear
        return retVal
    }

    @objc
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if section == tableView.numberOfSections - 1 {
            return 1
        }
        return 0
    }

    @objc(tableView:didSelectRowAtIndexPath:)
    func tableView(_: UITableView, didSelectRowAt _: IndexPath) {
        self.dismissInputController(completion: nil)
    }

    @objc(tableView:shouldShowMenuForRowAtIndexPath:)
    func tableView(_: UITableView, shouldShowMenuForRowAt _: IndexPath) -> Bool {
        true
    }

    @objc(tableView:canPerformAction:forRowAtIndexPath:withSender:)
    func tableView(_: UITableView, canPerformAction _: Selector, forRowAt _: IndexPath, withSender _: Any?) -> Bool {
        false
    }

    @objc
    func tableView(_: UITableView, willDisplayHeaderView view: UIView, forSection _: Int) {
        self.visibleTableHeaders.insert(view)
    }

    @objc
    func tableView(_: UITableView, didEndDisplayingHeaderView view: UIView, forSection _: Int) {
        self.visibleTableHeaders.remove(view)
    }

    @objc
    func scrollViewWillBeginDragging(_: UIScrollView) {
        self.showTopHeader()
    }

    @objc
    func scrollViewDidEndDragging(_: UIScrollView, willDecelerate decelerate: Bool) {
        if decelerate == false {
            self.hideTopHeader()
        }
    }

    @objc
    func scrollViewDidEndDecelerating(_: UIScrollView) {
        self.hideTopHeader()
    }

    func showTopHeader() {
        NSObject.cancelPreviousPerformRequests(withTarget: self)

        for viewHeader in self.visibleTableHeaders where viewHeader.alpha != 1 {
            UIView.animate(withDuration: 0.2, animations: {
                viewHeader.alpha = 1
            })
        }
    }

    func hideTopHeader() {
        if self.visibleTableHeaders.count < 2 {
            return
        }

        var headerTop: UIView?
        var minY: CGFloat = CGFloat(MAXFLOAT)

        for viewHeader in self.visibleTableHeaders {
            let contentHeight: CGFloat = (self.tableView.contentOffset.y + self.tableView.contentInset.top - viewHeader.frame.size.height)

            if viewHeader.frame.origin.y < minY, viewHeader.frame.origin.y >= contentHeight {
                minY = viewHeader.frame.origin.y
                headerTop = viewHeader
            }
        }

        let offsetY: CGFloat = (5 + (self.tableView.tableHeaderView?.frame.size.height ?? 0))

        if headerTop != nil, minY > offsetY {
            self.perform(#selector(animateHideTopHeader(_:)), with: headerTop, afterDelay: 0.5)
        }
    }

    @objc
    private func animateHideTopHeader(_ headerTop: UIView) {
        UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseOut, animations: {
            headerTop.alpha = 0
        }, completion: nil)
    }

    @objc(tableView:didEndDisplayingCell:forRowAtIndexPath:)
    func tableView(_: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt _: IndexPath) {
        if let cellMessage = cell as? (UITableViewCell & DPAGMessageCellProtocol), let cellWithProgress = cellMessage.decryptedMessage.cellWithProgress as? (UITableViewCell & DPAGMessageCellProtocol), cellWithProgress == cellMessage {
            cellMessage.decryptedMessage.attachmentProgress = 0
            cellMessage.decryptedMessage.cellWithProgress = nil
        }
    }

    @objc(tableView:estimatedHeightForRowAtIndexPath:)
    func tableView(_: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        var retVal: CGFloat = UITableView.automaticDimension
        if let message = self.decryptedMessageForIndexPath(indexPath, returnUnknownDecMessage: true) {
            if message.messageType == .unknown {
                retVal = 55
            } else {
                retVal = self.heightForMessage(message)
            }
        }
        return retVal
    }

    @objc(tableView:heightForRowAtIndexPath:)
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if self.isScrollTableViewToBottomAnimated {
            return self.tableView(tableView, estimatedHeightForRowAt: indexPath)
        }
        var messageUnchecked: DPAGDecryptedMessage?
        tryC {
            messageUnchecked = self.decryptedMessageForIndexPath(indexPath)
        }
        .catch { exception in

            DPAGLog("%@", exception)
        }
        .finally {}
        guard let message = messageUnchecked else { return 0 }
        let retVal = self.heightForMessage(message)
        return ceil(retVal)
    }

    func heightForMessage(_ decMessage: DPAGDecryptedMessage) -> CGFloat {
        var retVal: CGFloat = UITableView.automaticDimension
        guard self.tableView.frame.size.width > 0 else { return retVal }
        var cellHeight: CGFloat = 50
        var isNormalGroupOrIAmAdmin: Bool = true
//        DPAGLog("Loading tableView:%@", decMessage.messageGuid)
        
        if let ownAccountGuid = DPAGApplicationFacade.cache.account?.guid, let group = DPAGApplicationFacade.cache.group(for: self.streamGuid) {
            if group.groupType == .announcement && !group.adminGuids.contains(ownAccountGuid) {
                isNormalGroupOrIAmAdmin = false
            }
        }
        let preferredHeight: CGFloat = decMessage.preferredCellHeightForTableSize(self.tableView.frame.size, category: AppConfig.preferredContentSizeCategory())
        if shouldUsePreferredSizes && preferredHeight > 0 {
            retVal = preferredHeight
        } else {
            var cell: (UITableViewCell & DPAGMessageCellProtocol)?
            if decMessage.isSelfDestructive, !decMessage.isOwnMessage {
                cell = self.cellForHeightForDestructiveMessage(decMessage)
            } else if decMessage.errorType != .none, decMessage.errorType != .notChecked {
                if decMessage.isSystemGenerated && isNormalGroupOrIAmAdmin {
                    cell = self.cellForHeightForSystemMessage(decMessage)
                } else if decMessage.isSystemGenerated == false {
                    cell = self.cellForHeightForSimpleTextMessage(decMessage)
                }
            } else {
                switch decMessage.contentType {
                    case .voiceRec:
                        cell = self.cellForHeightForVoiceMessage(decMessage)
                    case .plain, .avCallInvitation:
                        if decMessage.isSystemGenerated && isNormalGroupOrIAmAdmin {
                            cell = self.cellForHeightForSystemMessage(decMessage)
                        } else if decMessage.isSystemGenerated == false {
                            cell = self.cellForHeightForSimpleTextMessage(decMessage)
                        }
                    case .controlMsgNG:
                        cell = self.cellForHeightForSimpleTextMessage(decMessage)
                    case .oooStatusMessage:
                        cell = self.cellForHeightForSimpleTextMessage(decMessage)
                    case .textRSS:
                        cell = self.cellForHeightForSimpleTextMessage(decMessage)
                    case .image:
                        cell = self.cellForHeightForImageMessage(decMessage)
                    case .video:
                        cell = self.cellForHeightForVideoMessage(decMessage)
                    case .location:
                        cell = self.cellForHeightForLocationMessage(decMessage)
                    case .contact:
                        cell = self.cellForHeightForContactMessage(decMessage)
                    case .file:
                        cell = self.cellForHeightForFileMessage(decMessage)
                }
            }
            if let sizingCell = cell {
                sizingCell.configureCellWithMessage(decMessage, forHeightMeasurement: true)
                sizingCell.setNeedsUpdateConstraints()
                sizingCell.updateConstraintsIfNeeded()
                cellHeight = sizingCell.calculateHeightForConfiguredSizingCellWidth(self.tableView.bounds.width)
            } else {
                cellHeight = 0
            }
            decMessage.setPreferredCellHeight(cellHeight, forTableSize: self.tableView.frame.size, preferredContentSizeCategory: AppConfig.preferredContentSizeCategory())
            retVal = cellHeight
        }
        return retVal
    }

    func cellForMessageAtIndexPath(_ indexPath: IndexPath) -> UITableViewCell? {
        guard let decMessage = self.decryptedMessageForIndexPath(indexPath) else { return nil }
        var cell: UITableViewCell?
        var isNormalGroupOrIAmAdmin: Bool = true
        
        if let ownAccountGuid = DPAGApplicationFacade.cache.account?.guid, let group = DPAGApplicationFacade.cache.group(for: self.streamGuid) {
            if group.groupType == .announcement && !group.adminGuids.contains(ownAccountGuid) {
                isNormalGroupOrIAmAdmin = false
            }
        }
        if decMessage.isSelfDestructive, !decMessage.isOwnMessage {
            cell = self.tableView(tableView, cellForDestructionMessage: decMessage, forIndexPath: indexPath)
            cell?.accessibilityIdentifier = "cell-\(indexPath.section)-\(indexPath.row)-destruct"
        } else if decMessage.errorType != .none, decMessage.errorType != .notChecked {
            if decMessage.isSystemGenerated && isNormalGroupOrIAmAdmin {
                cell = self.tableView(tableView, cellForSystemTextMessage: decMessage, forIndexPath: indexPath)
                cell?.accessibilityIdentifier = "cell-\(indexPath.section)-\(indexPath.row)-plain-system"
            } else if decMessage.isSystemGenerated == false  {
                cell = self.tableView(tableView, cellForSimpleTextMessage: decMessage, forIndexPath: indexPath)
                cell?.accessibilityIdentifier = "cell-\(indexPath.section)-\(indexPath.row)-plain-normal"
            }
        } else {
            switch decMessage.contentType {
                case .voiceRec:
                    cell = self.tableView(tableView, cellForVoiceRecMessage: decMessage, forIndexPath: indexPath)
                    cell?.accessibilityIdentifier = "cell-\(indexPath.section)-\(indexPath.row)-voice"
                case .image:
                    cell = self.tableView(tableView, cellForImageMessage: decMessage, forIndexPath: indexPath)
                    cell?.accessibilityIdentifier = "cell-\(indexPath.section)-\(indexPath.row)-image"
                case .video:
                    cell = self.tableView(tableView, cellForVideoMessage: decMessage, forIndexPath: indexPath)
                    cell?.accessibilityIdentifier = "cell-\(indexPath.section)-\(indexPath.row)-video"
                case .location:
                    cell = self.tableView(tableView, cellForLocationMessage: decMessage, forIndexPath: indexPath)
                    cell?.accessibilityIdentifier = "cell-\(indexPath.section)-\(indexPath.row)-location"
                case .contact:
                    cell = self.tableView(tableView, cellForContactMessage: decMessage, forIndexPath: indexPath)
                    cell?.accessibilityIdentifier = "cell-\(indexPath.section)-\(indexPath.row)-contact"
                case .file:
                    cell = self.tableView(tableView, cellForFileMessage: decMessage, forIndexPath: indexPath)
                    cell?.accessibilityIdentifier = "cell-\(indexPath.section)-\(indexPath.row)-file"
                case .oooStatusMessage:
                    cell = self.tableView(tableView, cellForSimpleTextMessage: decMessage, forIndexPath: indexPath)
                    cell?.accessibilityIdentifier = "cell-\(indexPath.section)-\(indexPath.row)-oooStatus"
                case .textRSS:
                    cell = self.tableView(tableView, cellForSimpleTextMessage: decMessage, forIndexPath: indexPath)
                    cell?.accessibilityIdentifier = "cell-\(indexPath.section)-\(indexPath.row)-textRSS"
                case .avCallInvitation:
                    cell = self.tableView(tableView, cellForSimpleTextMessage: decMessage, forIndexPath: indexPath)
                    cell?.accessibilityIdentifier = "cell-\(indexPath.section)-\(indexPath.row)-plain-normal"
                case .plain, .controlMsgNG:
                    if decMessage.isSystemGenerated && isNormalGroupOrIAmAdmin {
                        cell = self.tableView(tableView, cellForSystemTextMessage: decMessage, forIndexPath: indexPath)
                        cell?.accessibilityIdentifier = "cell-\(indexPath.section)-\(indexPath.row)-plain-system"
                    } else if decMessage.isSystemGenerated == false  {
                        cell = self.tableView(tableView, cellForSimpleTextMessage: decMessage, forIndexPath: indexPath)
                        cell?.accessibilityIdentifier = "cell-\(indexPath.section)-\(indexPath.row)-plain-normal"
                    }
                }
        }
        if let cell = cell as? DPAGMessageCellProtocol {
            cell.configureCellWithMessage(decMessage, forHeightMeasurement: false)
            cell.streamDelegate = self
        }
        return cell
    }

    func tableView(_ tableView: UITableView, cellForContactMessage decMessage: DPAGDecryptedMessage, forIndexPath indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: decMessage.isOwnMessage ? DPAGChatStreamBaseViewController.ContactMessageRightCellIdentifier : DPAGChatStreamBaseViewController.ContactMessageLeftCellIdentifier, for: indexPath)

        return cell
    }

    func tableView(_ tableView: UITableView, cellForDestructionMessage _: DPAGDecryptedMessage, forIndexPath indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: DPAGChatStreamBaseViewController.DestructionMessageLeftCellIdentifier, for: indexPath)

        return cell
    }

    func tableView(_ tableView: UITableView, cellForFileMessage decMessage: DPAGDecryptedMessage, forIndexPath indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: decMessage.isOwnMessage ? DPAGChatStreamBaseViewController.FileMessageRightCellIdentifier : DPAGChatStreamBaseViewController.FileMessageLeftCellIdentifier, for: indexPath)

        return cell
    }

    func tableView(_ tableView: UITableView, createCellForImageMessage decMessage: DPAGDecryptedMessage, forIndexPath indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: decMessage.isOwnMessage ? DPAGChatStreamBaseViewController.ImageMessageRightCellIdentifier : DPAGChatStreamBaseViewController.ImageMessageLeftCellIdentifier, for: indexPath)

        return cell
    }

    func tableView(_ tableView: UITableView, cellForImageMessage decMessage: DPAGDecryptedMessage, forIndexPath indexPath: IndexPath) -> UITableViewCell {
        let cell = self.tableView(tableView, createCellForImageMessage: decMessage, forIndexPath: indexPath)

        return cell
    }

    func tableView(_ tableView: UITableView, cellForLocationMessage decMessage: DPAGDecryptedMessage, forIndexPath indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: decMessage.isOwnMessage ? DPAGChatStreamBaseViewController.LocationMessageRightCellIdentifier : DPAGChatStreamBaseViewController.LocationMessageLeftCellIdentifier, for: indexPath)

        return cell
    }

    func tableView(_ tableView: UITableView, createCellForSimpleTextMessage decMessage: DPAGDecryptedMessage, forIndexPath indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: decMessage.isOwnMessage ? DPAGChatStreamBaseViewController.SimpleMessageRightCellIdentifier : DPAGChatStreamBaseViewController.SimpleMessageLeftCellIdentifier, for: indexPath)
        return cell
    }
}

extension DPAGChatStreamBaseViewController {
    func lastVisibleIndexPath() -> IndexPath? {
        var lastVisibleIndexPath: IndexPath?
        if self.tableView.visibleCells.count > 0 {
            if let indexPathsForVisibleRows = self.tableView.indexPathsForVisibleRows {
                lastVisibleIndexPath = indexPathsForVisibleRows.last
                if let lastVisibleCell = self.tableView.visibleCells.last {
                    let lastCellFrame = lastVisibleCell.frame
                    let offsetToBottom = self.tableView.contentOffset.y + self.tableView.frame.size.height - lastCellFrame.origin.y
                    if self.tableView.visibleCells.count > 1, offsetToBottom < self.tableView.contentInset.bottom {
                        if indexPathsForVisibleRows.count > 1 {
                            lastVisibleIndexPath = indexPathsForVisibleRows[indexPathsForVisibleRows.count - 2]
                        } else {
                            lastVisibleIndexPath = indexPathsForVisibleRows.last
                        }
                    }
                }
            }
        }
        return lastVisibleIndexPath
    }

    func scrollToRowAtIndexPath(_ indexPath: IndexPath?, animated: Bool) {
        guard let indexPath = indexPath else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.tableView.scrollToRow(at: indexPath, at: .bottom, animated: animated)
        }
    }

    func scrollTableViewToBottomAnimated(_ animated: Bool) {
        self.isScrollTableViewToBottomAnimated = true
        let contentHeight: CGFloat = (self.tableView.frame.height /* + self.tableView.contentOffset.y*/ - self.tableView.contentInset.bottom - self.tableView.contentInset.top)
        let contentHeightAvailable = self.tableView.contentSize.height - self.tableView.contentOffset.y
        if contentHeightAvailable >= contentHeight {
            let contentOffsetY = self.tableView.contentSize.height - self.tableView.frame.size.height + self.tableView.contentInset.bottom + self.tableView.adjustedContentInset.bottom
            let contentOffset: CGPoint = CGPoint(x: 0, y: contentOffsetY)
            let contentSizeSmallEnoughToBeAnimated = (self.tableView.bounds.size.height * 2) > (self.tableView.contentSize.height - self.tableView.contentOffset.y)
            self.tableView.setContentOffset(contentOffset, animated: animated && contentSizeSmallEnoughToBeAnimated)
        }
        self.isScrollTableViewToBottomAnimated = false
    }

    @objc(tableView:willDisplayCell:forRowAtIndexPath:)
    func tableView(_: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let cellVoice = cell as? DPAGVoiceMessageCellProtocol {
            if DPAGApplicationFacadeUIBase.audioHelper.delegatePlayMessage == cellVoice.decryptedMessage, DPAGApplicationFacadeUIBase.audioHelper.audioPlayer?.isPlaying ?? false {
                DPAGApplicationFacadeUIBase.audioHelper.delegatePlay = cellVoice
                cellVoice.didStartPlaying()
            }
        }
        guard cell is DPAGMessageCellProtocol else { return }
        self.performBlockInBackground { [weak self] in
            guard let strongSelf = self else { return }
            var idxPathsToCheck: [IndexPath] = []
            var idxPathCheck = indexPath
            for _ in 0 ..< 10 {
                if idxPathCheck.row > 0 {
                    idxPathCheck = IndexPath(row: idxPathCheck.row - 1, section: idxPathCheck.section)
                    idxPathsToCheck.append(idxPathCheck)
                } else if idxPathCheck.section > 0 {
                    idxPathCheck = IndexPath(row: strongSelf.messages[idxPathCheck.section - 1].count - 1, section: idxPathCheck.section - 1)
                    idxPathsToCheck.append(idxPathCheck)
                } else {
                    break
                }
            }
            strongSelf.fetchedResultsController.load(idxPathsToCheck)
        }
    }

    @objc(tableView:canEditRowAtIndexPath:)
    func tableView(_: UITableView, canEditRowAt _: IndexPath) -> Bool {
        // Return NO if you do not want the specified item to be editable.

        // if let indexPathMsg = self.indexPathWithoutNewMessages(indexPath)
        // {
        return true
        // }
        // return false
    }

    @objc
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
//        DPAGLog("scrollViewDidScroll \(scrollView.contentSize) : \(scrollView.contentOffset) : \(scrollView.contentInset)")
        let height = scrollView.frame.size.height
        let contentYoffset = scrollView.contentOffset.y
        let distanceFromBottom = scrollView.contentSize.height - contentYoffset
        if distanceFromBottom <= height + 10 {
            self.isAtEndOfScreen = true
        } else {
            self.isAtEndOfScreen = false
        }
    }

    @objc
    func cancelEdit() {
        self.tableView.setEditing(false, animated: true)
        self.tableView.separatorStyle = .none
        for cell in self.tableView.visibleCells {
            cell.selectionStyle = .none
            if let cellSimple = cell as? (UITableViewCell & DPAGSimpleMessageCellProtocol) {
                cellSimple.labelText?.isUserInteractionEnabled = true
            }
        }
        self.updateNavigationBarForEditing()
    }

    private func updateNavigationBarForEditing() {
        if self.tableView.isEditing, let barButtonCancelEdit = self.barButtonCancelEdit {
            self.navigationItemButtonsNoEditRight = self.navigationItem.rightBarButtonItems
            self.navigationItem.rightBarButtonItems = [barButtonCancelEdit]
            self.navigationItemTitleView = self.navigationItem.titleView
            self.navigationItemTitle = self.title
            self.navigationItem.leftBarButtonItems = []
            self.title = DPAGLocalizedString("chat.messages.action.title")
        } else {
            if let navigationItemTitle = self.navigationItemTitle {
                self.title = navigationItemTitle
            }
            if let navigationItemTitleView = self.navigationItemTitleView {
                self.navigationItem.titleView = navigationItemTitleView
            }
            if let navigationItemButtonsNoEditRight = self.navigationItemButtonsNoEditRight {
                self.navigationItem.rightBarButtonItems = navigationItemButtonsNoEditRight
            }
            self.navigationItem.leftBarButtonItems = nil
        }
    }

    @objc(tableView:editActionsForRowAtIndexPath:)
    func tableView(_: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        guard let decMessage = self.decryptedMessageForIndexPath(indexPath) else { return [] }
        let titleInfo = DPAGLocalizedString("chat.message.action.info")
        let titleDelete = DPAGLocalizedString("chat.message.action.delete")
        let infoAction = UITableViewRowAction(style: .default, title: titleInfo) { [weak self] _, _ in
            self?.dismissInputController(completion: { [weak self] in
                if let strongSelf = self {
                    strongSelf.openInfoForMessage(decMessage)
                }
            })
        }
        infoAction.backgroundColor = DPAGColorProvider.shared[.defaultViewBackgroundInverted]
        let deleteAction = UITableViewRowAction(style: .destructive, title: titleDelete) { [weak self] _, indexPath in
            self?.dismissInputController(completion: { [weak self] in
                self?.onDeleteMessageSelected(decMessage: decMessage, indexPath: indexPath)
            })
        }
        guard decMessage.isOwnMessage else { return [deleteAction] }
        if let decryptedMessage = decMessage as? DPAGDecryptedMessageGroup {
            if decMessage.isSystemGenerated == false, self.hasMessageInfo(), decryptedMessage.recipients.count > 0 {
                switch decryptedMessage.groupType {
                    case .restricted:
                        return [deleteAction]
                    case .managed, .default, .announcement:
                        return [infoAction, deleteAction]
                }
            }
        } else if let decMessagePrivate = decMessage as? DPAGDecryptedMessagePrivate {
            if decMessagePrivate.isSystemChat == false, self.hasMessageInfo(), decMessage.isSystemGenerated == false {
                return [infoAction, deleteAction]
            }
        }
        return [deleteAction]
    }
}

extension DPAGChatStreamBaseViewController {
    private func onDeleteMessageSelected(decMessage: DPAGDecryptedMessage, indexPath: IndexPath) {
        let optionDelete = AlertOption(titleKey: "chat.list.action.confirm.delete.message", style: .destructive) { [weak self] in
            if let messageNow = self?.decryptedMessageForIndexPath(indexPath), messageNow.messageGuid == decMessage.messageGuid {
                self?.deleteChatStreamMessage(decMessage.messageGuid)
            }
        }
        let optionCancel = AlertOption.cancelOption()
        let options = [optionDelete, optionCancel]
        let alertController = UIAlertController.controller(options: options, titleKey: "chat.list.title.confirm.delete.message", withStyle: .alert)
        self.presentAlertController(alertController)
    }
}

extension DPAGChatCellBaseViewController: UITableViewDataSourcePrefetching {
    func tableView(_: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        for indexPath in indexPaths {
            _ = self.decryptedMessageForIndexPath(indexPath)
        }
    }
}
