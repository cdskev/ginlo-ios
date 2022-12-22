//
//  DPAGChatsListViewController+TableView.swift
// ginlo
//
//  Created by RBU on 07/04/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

protocol DPAGChatsListSearchResultsViewDelegate: NSObjectProtocol {
  func createCell(_ tableView: UITableView, stream: DPAGDecryptedStream, indexPath: IndexPath, searchText: String?) -> UITableViewCell
  func openStream(_ tableView: UITableView, stream: DPAGDecryptedStream, indexPath: IndexPath)
}

extension DPAGChatsListViewController {
  func scrollToStream(_ streamGuid: String) {
    if let idx = self.streams.firstIndex(of: streamGuid) {
      self.tableView.scrollToRow(at: IndexPath(row: idx, section: 0), at: .middle, animated: true)
    }
  }
  
  func streamForIndexPath(_ indexPath: IndexPath) -> DPAGDecryptedStream? {
    let streamGuid = self.streams[indexPath.row]
    let decStream = DPAGApplicationFacade.cache.decryptedStream(streamGuid: streamGuid, in: nil)
    
    return decStream
  }
  
  func streamForIndexPathCached(_ indexPath: IndexPath) -> DPAGDecryptedStream? {
    let streamGuid = self.streams[indexPath.row]
    let decStream = DPAGApplicationFacade.cache.decryptedStream(streamGuid: streamGuid)
    
    return decStream
  }
}

extension DPAGChatsListViewController: UITableViewDataSource {
  func numberOfSections(in tableView: UITableView) -> Int {
    if tableView == self.tableView, self.fetchedResultsController.fetchedResultsController?.delegate != nil {
      return 1
    } else {
      return 0
    }
  }
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if tableView == self.tableView {
      if section == 0 {
        var rc = 0
        self.queueSyncVars.sync(flags: .barrier) {
          rc = self.streams.count
        }
        return rc
      }
    }
    return 0
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    guard let stream = self.streamForIndexPath(indexPath) else {
      return UITableViewCell(style: .default, reuseIdentifier: "???")
    }
    return self.createCell(tableView, stream: stream, indexPath: indexPath, searchText: nil)
  }
  
  func tableView(_: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
    guard let stream = self.streamForIndexPathCached(indexPath) else { return UITableView.automaticDimension }
    
    if let streamSingle = stream as? DPAGDecryptedStreamPrivate {
      if DPAGApplicationFacade.preferences.streamVisibilityNew {
        if streamSingle.newMessagesCount == 0 {
          return 0
        }
      } else if DPAGApplicationFacade.preferences.streamVisibilitySingle == false {
        return 0
      }
    } else if let streamChannel = stream as? DPAGDecryptedStreamChannel {
      if DPAGApplicationFacade.preferences.streamVisibilityNew {
        if streamChannel.newMessagesCount == 0 {
          return 0
        }
      } else if DPAGApplicationFacade.preferences.streamVisibilityChannel == false {
        return 0
      }
    } else if let streamGroup = stream as? DPAGDecryptedStreamGroup, let group = DPAGApplicationFacade.cache.group(for: streamGroup.guid) {
      if DPAGApplicationFacade.preferences.streamVisibilityNew {
        if streamGroup.newMessagesCount == 0 {
          return 0
        }
      } else {
        if group.groupType == .restricted {
          if DPAGApplicationFacade.preferences.streamVisibilityChannel == false {
            return 0
          }
        } else {
          if DPAGApplicationFacade.preferences.streamVisibilityGroup == false {
            return 0
          }
        }
      }
    }
    return 97
  }
  
  func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    guard let stream = self.streamForIndexPath(indexPath) else { return UITableView.automaticDimension }
    if let streamSingle = stream as? DPAGDecryptedStreamPrivate {
      if DPAGApplicationFacade.preferences.streamVisibilityNew {
        if streamSingle.newMessagesCount == 0 {
          return 0
        }
      } else if DPAGApplicationFacade.preferences.streamVisibilitySingle == false {
        return 0
      }
    } else if let streamChannel = stream as? DPAGDecryptedStreamChannel {
      if DPAGApplicationFacade.preferences.streamVisibilityNew {
        if streamChannel.newMessagesCount == 0 {
          return 0
        }
      } else if DPAGApplicationFacade.preferences.streamVisibilityChannel == false {
        return 0
      }
    } else if let streamGroup = stream as? DPAGDecryptedStreamGroup, let group = DPAGApplicationFacade.cache.group(for: streamGroup.guid) {
      if DPAGApplicationFacade.preferences.streamVisibilityNew {
        if streamGroup.newMessagesCount == 0 {
          return 0
        }
      } else {
        if group.groupType == .restricted {
          if DPAGApplicationFacade.preferences.streamVisibilityChannel == false {
            return 0
          }
        } else {
          if DPAGApplicationFacade.preferences.streamVisibilityGroup == false {
            return 0
          }
        }
      }
    }
    return UITableView.automaticDimension
  }
  
  func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
    0
  }
  
  func tableView(_: UITableView, heightForFooterInSection _: Int) -> CGFloat {
    0
  }
  
  func tableView(_: UITableView, viewForHeaderInSection _: Int) -> UIView? {
    nil
  }
  
  func tableView(_: UITableView, viewForFooterInSection _: Int) -> UIView? {
    nil
  }
  
  func createCell(_ tableView: UITableView, stream: DPAGDecryptedStream, indexPath: IndexPath, searchText: String?) -> UITableViewCell {
    var cell: (UITableViewCell & DPAGChatOverviewBaseCellProtocol)?
    var streamName = "\(indexPath.section)-\(indexPath.row)"
    if let nameOfStream = stream.name {
      streamName = nameOfStream
    }
    cell?.accessibilityIdentifier = streamName
    if let streamSingle = stream as? DPAGDecryptedStreamPrivate, let contactGuid = streamSingle.contactGuid, let contact = DPAGApplicationFacade.cache.contact(for: contactGuid) {
      if DPAGApplicationFacade.preferences.streamVisibilityNew {
        if streamSingle.newMessagesCount == 0 {
          let hiddenCell = tableView.dequeueReusableCell(withIdentifier: DPAGChatsListViewController.SettingsCellHiddenIdentifier, for: indexPath)
          hiddenCell.setNeedsUpdateConstraints()
          hiddenCell.updateConstraintsIfNeeded()
          hiddenCell.accessibilityIdentifier = "hiddenCell-\(indexPath.section)-\(indexPath.row)"
          return hiddenCell
        }
      } else if DPAGApplicationFacade.preferences.streamVisibilitySingle == false {
        let hiddenCell = tableView.dequeueReusableCell(withIdentifier: DPAGChatsListViewController.SettingsCellHiddenIdentifier, for: indexPath)
        hiddenCell.setNeedsUpdateConstraints()
        hiddenCell.updateConstraintsIfNeeded()
        hiddenCell.accessibilityIdentifier = "hiddenCell-\(indexPath.section)-\(indexPath.row)"
        return hiddenCell
      }
      if streamSingle.isSystemChat || contact.isConfirmed {
        if let cellPrivate = tableView.dequeueReusableCell(withIdentifier: DPAGChatsListViewController.ChatOverviewCellIdentifier, for: indexPath) as? (UITableViewCell & DPAGChatContactCellProtocol) {
          cellPrivate.setLabelNameHighlight(searchText)
          cellPrivate.configureCellWithStream(streamSingle)
          cell = cellPrivate
          cell?.accessibilityIdentifier = (streamSingle.isSystemChat ? "system-" : "private-") + streamName
        }
      } else if let cellPrivate = tableView.dequeueReusableCell(withIdentifier: DPAGChatsListViewController.ChatConfirmContactCellIdentifier, for: indexPath) as? (UITableViewCell & DPAGChatContactConfirmCellProtocol) {
        cellPrivate.configureCellWithStream(streamSingle)
        cellPrivate.delegateConfirm = self
        cell = cellPrivate
        cell?.accessibilityIdentifier = "private-request-" + streamName
      }
    } else if let streamChannel = stream as? DPAGDecryptedStreamChannel {
      if DPAGApplicationFacade.preferences.streamVisibilityNew {
        if streamChannel.newMessagesCount == 0 {
          let hiddenCell = tableView.dequeueReusableCell(withIdentifier: DPAGChatsListViewController.SettingsCellHiddenIdentifier, for: indexPath)
          hiddenCell.setNeedsUpdateConstraints()
          hiddenCell.updateConstraintsIfNeeded()
          hiddenCell.accessibilityIdentifier = "hiddenCell-\(indexPath.section)-\(indexPath.row)"
          return hiddenCell
        }
      } else if DPAGApplicationFacade.preferences.streamVisibilityChannel == false {
        let hiddenCell = tableView.dequeueReusableCell(withIdentifier: DPAGChatsListViewController.SettingsCellHiddenIdentifier, for: indexPath)
        hiddenCell.setNeedsUpdateConstraints()
        hiddenCell.updateConstraintsIfNeeded()
        hiddenCell.accessibilityIdentifier = "hiddenCell-\(indexPath.section)-\(indexPath.row)"
        return hiddenCell
      }
      
      switch streamChannel.feedType {
        case .channel:
          if let cellChannel = tableView.dequeueReusableCell(withIdentifier: DPAGChatsListViewController.ChannelCellIdentifier, for: indexPath) as? (UITableViewCell & DPAGChannelCellProtocol) {
            cellChannel.setLabelNameHighlight(searchText)
            cellChannel.configureCellWithStream(streamChannel)
            cell = cellChannel
            cell?.accessibilityIdentifier = "channel-" + streamName
          }
      }
    } else if let streamGroup = stream as? DPAGDecryptedStreamGroup, let group = DPAGApplicationFacade.cache.group(for: streamGroup.guid) {
      if DPAGApplicationFacade.preferences.streamVisibilityNew {
        if streamGroup.newMessagesCount == 0 {
          let hiddenCell = tableView.dequeueReusableCell(withIdentifier: DPAGChatsListViewController.SettingsCellHiddenIdentifier, for: indexPath)
          hiddenCell.setNeedsUpdateConstraints()
          hiddenCell.updateConstraintsIfNeeded()
          hiddenCell.accessibilityIdentifier = "hiddenCell-\(indexPath.section)-\(indexPath.row)"
          
          return hiddenCell
        }
      } else {
        if group.groupType == .restricted {
          if DPAGApplicationFacade.preferences.streamVisibilityChannel == false {
            let hiddenCell = tableView.dequeueReusableCell(withIdentifier: DPAGChatsListViewController.SettingsCellHiddenIdentifier, for: indexPath)
            hiddenCell.setNeedsUpdateConstraints()
            hiddenCell.updateConstraintsIfNeeded()
            hiddenCell.accessibilityIdentifier = "hiddenCell-\(indexPath.section)-\(indexPath.row)"
            return hiddenCell
          }
        } else {
          if DPAGApplicationFacade.preferences.streamVisibilityGroup == false {
            let hiddenCell = tableView.dequeueReusableCell(withIdentifier: DPAGChatsListViewController.SettingsCellHiddenIdentifier, for: indexPath)
            hiddenCell.setNeedsUpdateConstraints()
            hiddenCell.updateConstraintsIfNeeded()
            hiddenCell.accessibilityIdentifier = "hiddenCell-\(indexPath.section)-\(indexPath.row)"
            return hiddenCell
          }
        }
      }
      
      if group.isConfirmed {
        if let cellGroup = tableView.dequeueReusableCell(withIdentifier: DPAGChatsListViewController.GroupChatCellIdentifier, for: indexPath) as? (UITableViewCell & DPAGChatGroupCellProtocol) {
          cellGroup.setLabelNameHighlight(searchText)
          cellGroup.configureCellWithStream(streamGroup)
          cell = cellGroup
          cell?.accessibilityIdentifier = "group-" + streamName
        }
      } else if let cellGroup = tableView.dequeueReusableCell(withIdentifier: DPAGChatsListViewController.GroupChatConfirmCellIdentifier, for: indexPath) as? (UITableViewCell & DPAGChatOverviewNotConfirmedBaseCellProtocol) {
        cellGroup.configureCellWithStream(streamGroup)
        cellGroup.delegateConfirm = self
        cell = cellGroup
        cell?.accessibilityIdentifier = "group-request-" + streamName
      }
    }
    cell?.setAnimating(stream.guid == self.loadingChatGuid)
    cell?.setNeedsUpdateConstraints()
    cell?.updateConstraintsIfNeeded()
    cell?.setSelected(stream.guid == self.lastSelectedStreamGuid, animated: false)
    if cell != nil && stream.guid == self.lastSelectedStreamGuid {
      tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
    }
    return cell ?? UITableViewCell(style: .default, reuseIdentifier: "???")
  }
  
  func tableView(_: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    if indexPath.section == 0, indexPath.row < self.streams.count {
      let stream = self.streamForIndexPath(indexPath)
      if let streamPrivate = stream as? DPAGDecryptedStreamPrivate, let contactGuid = streamPrivate.contactGuid, let contact = DPAGApplicationFacade.cache.contact(for: contactGuid) {
        return contact.isConfirmed
      } else if let streamGroup = stream as? DPAGDecryptedStreamGroup, let group = DPAGApplicationFacade.cache.group(for: streamGroup.guid) {
        return group.isConfirmed
      } else if stream is DPAGDecryptedStreamChannel {
        return true
      }
    }
    return false
  }
  
  func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
    var isChannel = false
    var isChannelService = false
    var isGroup = false
    var isSingle = false
    var isSystemGuid = false
    var isConfirmed = true
    var hasInfo = true
    var hasUnreadMessages = false
    var canScan = true
    var streamGuidToEdit: String?
    var stream: DPAGDecryptedStream?
    
    if indexPath.section == 0, indexPath.row < self.streams.count {
      stream = self.streamForIndexPath(indexPath)
      streamGuidToEdit = stream?.guid
      if let privateStream = stream as? DPAGDecryptedStreamPrivate {
        isSingle = true
        if let contactGuid = privateStream.contactGuid, let contact = DPAGApplicationFacade.cache.contact(for: contactGuid) {
          isConfirmed = contact.isConfirmed
          isSystemGuid = privateStream.isSystemChat
          hasInfo = contact.isDeleted == false
          canScan = contact.confidence != .high
        }
      } else if let groupStream = stream as? DPAGDecryptedStreamGroup, let group = DPAGApplicationFacade.cache.group(for: groupStream.guid) {
        isGroup = true
        isConfirmed = group.isConfirmed
        hasInfo = (group.groupType != .restricted)
      } else if let channelStream = stream as? DPAGDecryptedStreamChannel {
        isChannel = true
        isChannelService = false
        hasUnreadMessages = channelStream.newMessagesCount > 0
      }
    }
    guard let streamGuid = streamGuidToEdit, isConfirmed else { return [] }
    var titleMore = "-", titleDestructive = "-", titleInfo = "-", titleExport = "-"
    let titleScan = DPAGLocalizedString("chat.list.action.scanContact")
    let titleMarkAsRead = DPAGLocalizedString("chat.list.action.markAsRead")
    if isChannel {
      titleMore = isChannelService ? DPAGLocalizedString("chat.list.action.more.service") : DPAGLocalizedString("chat.list.action.more.channel")
      titleDestructive = isChannelService ? DPAGLocalizedString("chat.list.action.removeMessages.service") : DPAGLocalizedString("chat.list.action.removeMessages.channel")
      titleInfo = isChannelService ? DPAGLocalizedString("chat.list.action.showInfo.service") : DPAGLocalizedString("chat.list.action.showInfo.channel")
    } else if isGroup {
      titleMore = DPAGLocalizedString("chat.list.action.more.group")
      titleInfo = DPAGLocalizedString("chat.list.action.showInfo.group")
      titleExport = DPAGLocalizedString("chat.list.action.export.group")
    } else { // if (isSingle)
      titleMore = DPAGLocalizedString("chat.list.action.more.single")
      titleDestructive = DPAGLocalizedString("chat.list.action.delete.single")
      titleInfo = DPAGLocalizedString("chat.list.action.showInfo.single")
      titleExport = DPAGLocalizedString("chat.list.action.export.single")
    }
    let moreAction = UITableViewRowAction(style: .default, title: titleMore) { [weak self] _, indexPath in
      if let strongSelf = self {
        strongSelf.tableView.setEditing(false, animated: true)
        var options = [AlertOption]()
        var deleteChatOption: AlertOption?
        if isConfirmed, !isChannel, DPAGApplicationFacade.preferences.isChatExportAllowed {
          let exportChatOption = AlertOption(title: DPAGLocalizedString(titleExport), style: .default, image: DPAGImageProvider.shared[.kShare], accesibilityIdentifier: titleExport, handler: {
            self?.presentExportChatWarning(streamGuid: streamGuid)
          })
          options.append(exportChatOption)
        }
        if hasInfo {
          let showInfoOption = AlertOption(title: DPAGLocalizedString(titleInfo), style: .default, image: DPAGImageProvider.shared[.kEye], accesibilityIdentifier: titleInfo, handler: {
            self?.showStreamInfoWithGuid(streamGuid)
          })
          options.append(showInfoOption)
        }
        if hasInfo, isSingle, canScan {
          let scanOption = AlertOption(title: DPAGLocalizedString(titleScan), style: .default, image: DPAGImageProvider.shared[.kScan], accesibilityIdentifier: titleScan, handler: {
            self?.scanContactWithStreamGuid(streamGuid)
          })
          options.append(scanOption)
        }
        if hasUnreadMessages {
          let unreadMessagesOption = AlertOption(title: DPAGLocalizedString(titleMarkAsRead), style: .default, image: DPAGImageProvider.shared[.kEyeGlasses], accesibilityIdentifier: titleMarkAsRead, handler: {
            self?.markMessagesAsRead(streamGuid: streamGuid, indexPath: indexPath)
          })
          options.append(unreadMessagesOption)
        }
        if let groupStream = stream as? DPAGDecryptedStreamGroup, let group = DPAGApplicationFacade.cache.group(for: groupStream.guid), group.isConfirmed {
          if group.guidOwner == DPAGApplicationFacade.cache.account?.guid {
            titleDestructive = DPAGLocalizedString("chat.list.action.delete.group")
            deleteChatOption = AlertOption(title: DPAGLocalizedString(titleDestructive), style: .destructive, image: DPAGImageProvider.shared[.kDeleteLeft], accesibilityIdentifier: titleDestructive, handler: {
              self?.deleteGroupStream(streamGuid)
            })
          } else {
            titleDestructive = DPAGLocalizedString("chat.list.action.leave.group")
            deleteChatOption = AlertOption(title: DPAGLocalizedString(titleDestructive), style: .destructive, image: DPAGImageProvider.shared[.kArrowSquareUp], accesibilityIdentifier: titleDestructive, handler: {
              self?.leaveGroupStream(streamGuid)
            })
          }
        } else if isChannel {
          titleDestructive = isChannelService ? DPAGLocalizedString("chat.list.action.unsubscribe.service") : DPAGLocalizedString("chat.list.action.unsubscribe.channel")
          deleteChatOption = AlertOption(title: DPAGLocalizedString(titleDestructive), style: .destructive, image: DPAGImageProvider.shared[.kArrowSquareUp], accesibilityIdentifier: titleDestructive, handler: {
            self?.deleteStreamWithGuid(streamGuid)
          })
        } else {
          titleDestructive = DPAGLocalizedString("chat.list.action.delete.single")
          deleteChatOption = AlertOption(title: DPAGLocalizedString(titleDestructive), style: .destructive, image: DPAGImageProvider.shared[.kDeleteLeft], accesibilityIdentifier: titleDestructive, handler: {
            self?.deleteStreamWithGuid(streamGuid)
          })
        }
        if let deleteChatOption = deleteChatOption {
          options.append(deleteChatOption)
        }
        let cancelOption = AlertOption(title: DPAGLocalizedString("res.cancel"), style: .cancel)
        options.append(cancelOption)
        let alertController = UIAlertController.controller(options: options, withStyle: .alert, accessibilityIdentifier: "action_more")
        self?.presentAlertController(alertController)
      }
    }
    moreAction.backgroundColor = .gray
    let titleDelete = self.tableView(tableView, titleForDeleteConfirmationButtonForRowAt: indexPath)
    if titleDelete == nil {
      return [moreAction]
    }
    if isSystemGuid {
      let deleteAction = UITableViewRowAction(style: .destructive, title: titleDelete) { [weak self] _, indexPath in
        if let strongSelf = self {
          strongSelf.tableView.setEditing(false, animated: true)
          if indexPath.row >= strongSelf.streams.count {
            return
          }
          let stream = strongSelf.streamForIndexPath(indexPath)
          var actionSheetTitle: String?
          var actionTitle: String?
          if let privateStream = stream as? DPAGDecryptedStreamPrivate, let contactGuid = privateStream.contactGuid, let contact = DPAGApplicationFacade.cache.contact(for: contactGuid), contact.isConfirmed {
            actionSheetTitle = "chat.list.title.confirm.delete.singlechat"
            actionTitle = "chat.list.action.confirm.delete.singlechat"
          }
          if let actionSheetTitle = actionSheetTitle, let actionTitle = actionTitle {
            let optionDelete = AlertOption(title: DPAGLocalizedString(actionTitle), style: .destructive, accesibilityIdentifier: actionTitle, handler: { [weak self] in
              self?.deleteStreamWithGuid(streamGuid)
            })
            let optionCancel = AlertOption(title: DPAGLocalizedString("res.cancel"), style: .cancel)
            let alertController = UIAlertController.controller(options: [optionDelete, optionCancel], titleKey: actionSheetTitle, withStyle: .alert)
            self?.presentAlertController(alertController)
          }
        }
      }
      deleteAction.backgroundColor = .red
      return [deleteAction]
    } else {
      let deleteAction = UITableViewRowAction(style: .destructive, title: titleDelete) { [weak self] _, indexPath in
        if let strongSelf = self {
          strongSelf.tableView.setEditing(false, animated: true)
          if indexPath.row >= strongSelf.streams.count {
            return
          }
          let stream = strongSelf.streamForIndexPath(indexPath)
          var actionSheetTitle: String?
          var actionTitle: String?
          if let privateStream = stream as? DPAGDecryptedStreamPrivate, let contactGuid = privateStream.contactGuid, let contact = DPAGApplicationFacade.cache.contact(for: contactGuid), contact.isConfirmed {
            actionSheetTitle = "chat.list.title.confirm.clear.chat"
            actionTitle = "chat.list.action.confirm.clear.chat"
          } else if let groupStream = stream as? DPAGDecryptedStreamGroup, let group = DPAGApplicationFacade.cache.group(for: groupStream.guid), group.isConfirmed {
            actionSheetTitle = "chat.list.title.confirm.clear.chat"
            actionTitle = "chat.list.action.confirm.clear.chat"
          } else if stream as? DPAGDecryptedStreamChannel != nil {
            actionSheetTitle = isChannelService ? "chat.list.title.confirm.unsubscribe.service" : "chat.list.title.confirm.clear.chat"
            actionTitle = isChannelService ? "chat.list.action.confirm.unsubscribe.service" : "chat.list.action.confirm.clear.chat"
          }
          if let actionSheetTitle = actionSheetTitle, let actionTitle = actionTitle {
            let clearChatOption = AlertOption(title: DPAGLocalizedString(actionTitle), style: .destructive, accesibilityIdentifier: actionTitle, handler: { [weak self] in
              self?.clearStreamWithGuid(streamGuid)
            })
            let optionCancel = AlertOption(title: DPAGLocalizedString("res.cancel"), style: .cancel)
            let alertController = UIAlertController.controller(options: [clearChatOption, optionCancel], titleKey: actionSheetTitle, withStyle: .alert)
            self?.presentAlertController(alertController)
          }
        }
      }
      deleteAction.backgroundColor = .red
      return [deleteAction, moreAction]
    }
  }
  
  func tableView(_: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
    if indexPath.row >= self.streams.count {
      return nil
    }
    var retVal: String?
    let stream = self.streamForIndexPath(indexPath)
    if let privateStream = stream as? DPAGDecryptedStreamPrivate, let contactGuid = privateStream.contactGuid, let contact = DPAGApplicationFacade.cache.contact(for: contactGuid) {
      let isSystemGuid = privateStream.isSystemChat
      if contact.isConfirmed == false {
        retVal = nil
      } else if isSystemGuid {
        retVal = DPAGLocalizedString("chat.list.action.delete.single")
      } else {
        retVal = DPAGLocalizedString("chat.list.action.removeMessages.single")
      }
    } else if let groupStream = stream as? DPAGDecryptedStreamGroup, let group = DPAGApplicationFacade.cache.group(for: groupStream.guid) {
      if group.isConfirmed == false {
        retVal = nil
      } else if group.groupType != .default && group.isDeleted == false {
        retVal = DPAGLocalizedString("chat.list.action.removeMessages.group")
      } else if group.groupType == .restricted {
        retVal = DPAGLocalizedString("chat.list.action.delete.single")
      } else {
        retVal = DPAGLocalizedString("chat.list.action.removeMessages.group")
      }
    } else if let channelStream = stream as? DPAGDecryptedStreamChannel {
      if channelStream.mandatory {
        return nil
      }
      switch channelStream.feedType {
        case .channel:
          retVal = DPAGLocalizedString("chat.list.action.removeMessages.channel")
      }
    }
    
    return retVal
  }
  
  func tableView(_: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
    if editingStyle == UITableViewCell.EditingStyle.delete {
      if indexPath.row >= self.streams.count {
        return
      }
      let stream = self.streamForIndexPath(indexPath)
      var actionSheetTitle: String?
      var actionTitle: String?
      if let privateStream = stream as? DPAGDecryptedStreamPrivate, let contactGuid = privateStream.contactGuid, let contact = DPAGApplicationFacade.cache.contact(for: contactGuid), contact.isConfirmed {
        actionSheetTitle = "chat.list.title.confirm.clear.chat"
        actionTitle      = "chat.list.action.confirm.clear.chat"
      } else if let groupStream = stream as? DPAGDecryptedStreamGroup, let group = DPAGApplicationFacade.cache.group(for: groupStream.guid), group.isConfirmed {
        actionSheetTitle = "chat.list.title.confirm.clear.chat"
        actionTitle      = "chat.list.action.confirm.clear.chat"
      } else if stream as? DPAGDecryptedStreamChannel != nil {
        actionSheetTitle = "chat.list.title.confirm.unsubscribe.channel"
        actionTitle = "chat.list.action.confirm.unsubscribe.channel"
      }
      if let streamGuid = stream?.guid, let actionSheetTitle = actionSheetTitle, let actionTitle = actionTitle {
        let clearChatOption = AlertOption(title: DPAGLocalizedString(actionTitle), style: .destructive, accesibilityIdentifier: actionTitle, handler: { [weak self] in
          self?.clearStreamWithGuid(streamGuid)
        })
        let optionCancel = AlertOption(title: DPAGLocalizedString("res.cancel"), style: .cancel)
        let alertController = UIAlertController.controller(options: [clearChatOption, optionCancel], titleKey: actionSheetTitle, withStyle: .alert)
        self.presentAlertController(alertController)
      }
    }
  }
  
  func tableView(_: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
    guard indexPath.section == 0 else { return }
    self.fetchedResultsController.fetchedResultsController?.managedObjectContext.perform { [weak self] in
      guard let strongSelf = self else { return }
      var idxPathsToCheck: [IndexPath] = []
      var idxPathCheck = indexPath
      for _ in 0 ..< 10 {
        if idxPathCheck.row < strongSelf.streams.count - 1 {
          idxPathCheck = IndexPath(row: idxPathCheck.row + 1, section: idxPathCheck.section)
          idxPathsToCheck.append(idxPathCheck)
        } else {
          break
        }
      }
      strongSelf.fetchedResultsController.load(indexPaths: idxPathsToCheck)
    }
    //        if cell.isSelected {
    //            cell.selectionStyle = UITableViewCell.SelectionStyle.blue
    //        }
  }
}

extension DPAGChatsListViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    if indexPath.section == 0 {
      guard let stream = self.streamForIndexPath(indexPath) else { return }
      self.lastSelectedStreamGuid = stream.guid
      self.openStream(tableView, stream: stream, indexPath: indexPath)
    }
  }
}

extension DPAGChatsListViewController {
  private func presentExportChatWarning(streamGuid: String) {
    let actionOK = UIAlertAction(titleIdentifier: "res.ok", style: .destructive, handler: { [weak self] _ in
      if let strongSelf = self {
        strongSelf.exportStreamWithStreamGuid(streamGuid)
      }
    })
    self.presentAlert(alertConfig: AlertConfig(titleIdentifier: "chat.message.exportChat.warning.title", messageIdentifier: "chat.message.exportChat.warning.message", cancelButtonAction: .cancelDefault, otherButtonActions: [actionOK]))
  }
  
  private func markMessagesAsRead(streamGuid: String, indexPath: IndexPath) {
    self.performBlockInBackground { [weak self] in
      DPAGApplicationFacade.messageWorker.markStreamMessagesAsRead(streamGuid: streamGuid)
      self?.performBlockOnMainThread {
        self?.tableView.reloadRows(at: [indexPath], with: .automatic)
      }
    }
  }
}
