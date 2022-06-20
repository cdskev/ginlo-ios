//
//  DPAGFetchedResultsControllerChatStream.swift
//  SIMSmeCoreLib
//
//  Created by RBU on 10/01/2017.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import UIKit

public typealias DPAGFetchedResultsControllerChatStreamUpdateBlock = ([DPAGFetchedResultsControllerChange], [[DPAGDecryptedMessage]]) -> Void

public class DPAGFetchedResultsControllerChatStreamBase: NSObject {
  var changes: [DPAGFetchedResultsControllerChange] = []
  
  var fetchRequest: NSFetchRequest<NSFetchRequestResult>?
  var fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult>?
  
  var messages: [[DPAGDecryptedMessage]] = []
  
  var updateBlock: DPAGFetchedResultsControllerChatStreamUpdateBlock
  
  let streamGuid: String
  
  init(streamGuid: String, contentUpdateBlock: @escaping DPAGFetchedResultsControllerChatStreamUpdateBlock) {
    self.streamGuid = streamGuid
    self.updateBlock = contentUpdateBlock
    super.init()
  }
  
  deinit {
    self.fetchedResultsController?.delegate = nil
  }
  
  public func load() -> [[DPAGDecryptedMessage]] {
    self.messages
  }
  
  public func load(_: [IndexPath]) {}
  
  public func sectionNameforSection(_ section: Int) -> String? {
    var retVal: String?
    self.fetchedResultsController?.managedObjectContext.performAndWait {
      if (self.fetchedResultsController?.sections?.count ?? 0) > section {
        retVal = self.fetchedResultsController?.sections?[section].name
      }
    }
    return retVal
  }
  
  func initFetchedResultsController() {}
  
  public func receivedSignificantTimeChangeNotification() {
    self.fetchedResultsController?.delegate = nil
    self.fetchedResultsController?.managedObjectContext.performAndWait {
      self.fetchedResultsController?.managedObjectContext.reset()
    }
    self.initFetchedResultsController()
    self.messages = self.load()
    let messages = self.messages
    self.performBlockOnMainThread { [weak self] in
      self?.updateBlock([], messages)
      self?.fetchedResultsController?.delegate = self
    }
  }
}

extension DPAGFetchedResultsControllerChatStreamBase: NSFetchedResultsControllerDelegate {
  public func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
    guard controller == self.fetchedResultsController else { return }
    switch type {
      case .insert:
        if let newIndexPath = newIndexPath, indexPath == nil {
          DPAGLog("attempt insertRowsAtIndexPaths at \(newIndexPath)")
          if let aMessage = anObject as? SIMSManagedObjectMessage, let guid = aMessage.guid {
            self.changes.append(DPAGFetchedResultsControllerRowChange(changeType: .insert, guid: guid, changedIndexPath: newIndexPath, changedIndexPathMovedTo: nil))
            _ = DPAGApplicationFacade.cache.decryptedMessage(aMessage, in: controller.managedObjectContext)
          }
        }
      case .delete:
        if let indexPath = indexPath {
          DPAGLog("attempt deleteRowsAtIndexPaths at \(indexPath)")
          if let aMessage = anObject as? SIMSManagedObjectMessage, let guid = aMessage.guid {
            self.changes.append(DPAGFetchedResultsControllerRowChange(changeType: .delete, guid: guid, changedIndexPath: indexPath, changedIndexPathMovedTo: nil))
          }
        }
      case .update:
        if let indexPath = indexPath {
          DPAGLog("attempt reloadRowsAtIndexPaths at \(indexPath)")
          if let aMessage = anObject as? SIMSManagedObjectMessage, let guid = aMessage.guid {
            self.changes.append(DPAGFetchedResultsControllerRowChange(changeType: .update, guid: guid, changedIndexPath: indexPath, changedIndexPathMovedTo: nil))
            _ = DPAGApplicationFacade.cache.decryptedMessage(aMessage, in: controller.managedObjectContext)
          }
        }
      case .move:
        if let indexPath = indexPath, let newIndexPath = newIndexPath {
          DPAGLog("attempt move with moveRowAt from \(indexPath) to \(newIndexPath)")
          if let aMessage = anObject as? SIMSManagedObjectMessage, let guid = aMessage.guid {
            self.changes.append(DPAGFetchedResultsControllerRowChange(changeType: .move, guid: guid, changedIndexPath: indexPath, changedIndexPathMovedTo: newIndexPath))
          }
        }
      @unknown default:
        DPAGLog("Switch with unknown value: \(type.rawValue)", level: .warning)
    }
  }
  
  public func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange _: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
    guard controller == self.fetchedResultsController else { return }
    switch type {
      case .insert:
        self.changes.append(DPAGFetchedResultsControllerSectionChange(changeType: type, changedSection: sectionIndex))
        DPAGLog("attempt insertSections at \(sectionIndex)")
        // self.messages.insert([], at: sectionIndex)
      case .delete:
        self.changes.append(DPAGFetchedResultsControllerSectionChange(changeType: type, changedSection: sectionIndex))
        DPAGLog("attempt deleteSections at \(sectionIndex)")
        // self.messages.remove(at: sectionIndex)
      case .update:
        self.changes.append(DPAGFetchedResultsControllerSectionChange(changeType: type, changedSection: sectionIndex))
        DPAGLog("attempt reloadSections at \(sectionIndex)")
      default:
        break
    }
  }
  
  public func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    guard controller == self.fetchedResultsController else { return }
    DPAGLog("attempt beginUpdates")
    self.changes = []
  }
  
  public func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    let changesRow = self.changes.compactMap { ($0 as? DPAGFetchedResultsControllerRowChange) }
    let changesSection = self.changes.compactMap { ($0 as? DPAGFetchedResultsControllerSectionChange) }
    let changesRowDelete = changesRow.filter { change -> Bool in
      change.changeType == .delete || change.changeType == .move
    }
    let changesRowInsert = changesRow.filter { change -> Bool in
      change.changeType == .insert || change.changeType == .move
    }
    let changesRowUpdate = changesRow.filter { change -> Bool in
      change.changeType == .update
    }
    let changesSectionDelete = changesSection.filter { change -> Bool in
      change.changeType == .delete
    }
    let changesSectionInsert = changesSection.filter { change -> Bool in
      change.changeType == .insert
    }
    let changesRowDeleteOrdered = changesRowDelete.sorted { (change1, change2) -> Bool in
      change1.changedIndexPath.section > change2.changedIndexPath.section || (change1.changedIndexPath.section == change2.changedIndexPath.section && change1.changedIndexPath.row >= change2.changedIndexPath.row)
    }
    let changesRowInsertOrdered = changesRowInsert.sorted { (change1, change2) -> Bool in
      if change1.changeType == .move, let changedIndexPathMovedTo1 = change1.changedIndexPathMovedTo {
        if change2.changeType == .move, let changedIndexPathMovedTo2 = change2.changedIndexPathMovedTo {
          return changedIndexPathMovedTo1.section < changedIndexPathMovedTo2.section || (changedIndexPathMovedTo1.section == changedIndexPathMovedTo2.section && changedIndexPathMovedTo1.row <= changedIndexPathMovedTo2.row)
        }
        return changedIndexPathMovedTo1.section < change2.changedIndexPath.section || (changedIndexPathMovedTo1.section == change2.changedIndexPath.section && changedIndexPathMovedTo1.row <= change2.changedIndexPath.row)
      } else if change2.changeType == .move, let changedIndexPathMovedTo2 = change2.changedIndexPathMovedTo {
        return change1.changedIndexPath.section < changedIndexPathMovedTo2.section || (change1.changedIndexPath.section == changedIndexPathMovedTo2.section && change1.changedIndexPath.row <= changedIndexPathMovedTo2.row)
      }
      return change1.changedIndexPath.section < change2.changedIndexPath.section || (change1.changedIndexPath.section == change2.changedIndexPath.section && change1.changedIndexPath.row <= change2.changedIndexPath.row)
    }
    let changesSectionDeleteOrdered = changesSectionDelete.sorted { (change1, change2) -> Bool in
      change1.changedSection >= change2.changedSection
    }
    let changesSectionInsertOrdered = changesSectionInsert.sorted { (change1, change2) -> Bool in
      change1.changedSection <= change2.changedSection
    }
    var messages = self.messages
    for change in changesRowUpdate {
      var sectionContent = messages[change.changedIndexPath.section]
      if let decMessage = DPAGApplicationFacade.cache.decryptedMessage(messageGuid: change.guid, in: nil) {
        sectionContent.remove(at: change.changedIndexPath.row)
        sectionContent.insert(decMessage, at: change.changedIndexPath.row)
        messages[change.changedIndexPath.section] = sectionContent
      } else {
        if let msg: SIMSManagedObjectMessage = SIMSMessage.findFirst(byGuid: change.guid, in: controller.managedObjectContext) ?? SIMSMessageToSend.findFirst(byGuid: change.guid, in: controller.managedObjectContext) {
          if let decMessage = DPAGApplicationFacade.cache.decryptedMessage(msg, in: controller.managedObjectContext) {
            sectionContent.remove(at: change.changedIndexPath.row)
            sectionContent.insert(decMessage, at: change.changedIndexPath.row)
            messages[change.changedIndexPath.section] = sectionContent
          }
        }
      }
    }
    for change in changesRowDeleteOrdered {
      var sectionContent = messages[change.changedIndexPath.section]
      sectionContent.remove(at: change.changedIndexPath.row)
      messages[change.changedIndexPath.section] = sectionContent
    }
    for change in changesSectionDeleteOrdered {
      messages.remove(at: change.changedSection)
    }
    for change in changesSectionInsertOrdered {
      messages.insert([], at: change.changedSection)
    }
    for change in changesRowInsertOrdered {
      if change.changeType == .move, let changedIndexPathMovedTo = change.changedIndexPathMovedTo {
        var sectionContent = messages[changedIndexPathMovedTo.section]
        if let decMessage = DPAGApplicationFacade.cache.decryptedMessage(messageGuid: change.guid, in: nil) {
          sectionContent.insert(decMessage, at: changedIndexPathMovedTo.row)
          messages[changedIndexPathMovedTo.section] = sectionContent
        } else {
          if let msg: SIMSManagedObjectMessage = SIMSMessage.findFirst(byGuid: change.guid, in: controller.managedObjectContext) ?? SIMSMessageToSend.findFirst(byGuid: change.guid, in: controller.managedObjectContext) {
            if let decMessage = DPAGApplicationFacade.cache.decryptedMessage(msg, in: controller.managedObjectContext) {
              sectionContent.insert(decMessage, at: changedIndexPathMovedTo.row)
              messages[changedIndexPathMovedTo.section] = sectionContent
            }
          }
        }
      } else {
        var sectionContent = messages[change.changedIndexPath.section]
        if let decMessage = DPAGApplicationFacade.cache.decryptedMessage(messageGuid: change.guid, in: nil) {
          sectionContent.insert(decMessage, at: change.changedIndexPath.row)
          messages[change.changedIndexPath.section] = sectionContent
        } else {
          if let msg: SIMSManagedObjectMessage = SIMSMessage.findFirst(byGuid: change.guid, in: controller.managedObjectContext) ?? SIMSMessageToSend.findFirst(byGuid: change.guid, in: controller.managedObjectContext) {
            if let decMessage = DPAGApplicationFacade.cache.decryptedMessage(msg, in: controller.managedObjectContext) {
              sectionContent.insert(decMessage, at: change.changedIndexPath.row)
              messages[change.changedIndexPath.section] = sectionContent
            }
          }
        }
      }
    }
    let changes = self.changes
    self.messages = messages
    self.performBlockOnMainThread { [weak self] in
      self?.updateBlock(changes, messages)
    }
  }
}

public class DPAGFetchedResultsControllerChatStream: DPAGFetchedResultsControllerChatStreamBase {
  override public init(streamGuid: String, contentUpdateBlock: @escaping DPAGFetchedResultsControllerChatStreamUpdateBlock) {
    super.init(streamGuid: streamGuid, contentUpdateBlock: contentUpdateBlock)
    self.initFetchedResultsController()
  }
  
  override func initFetchedResultsController() {
    super.initFetchedResultsController()
    let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: SIMSMessage.entityName())
    fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \SIMSMessage.messageOrderId, ascending: true), NSSortDescriptor(keyPath: \SIMSMessage.dateSendServer, ascending: false)]
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates:
                                                  [
                                                    NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessage.stream), rightNotExpression: NSExpression(forConstantValue: nil)),
                                                    NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessage.stream?.guid), rightExpression: NSExpression(forConstantValue: self.streamGuid))
                                                  ])
    self.fetchRequest = fetchRequest
    self.fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: NSManagedObjectContext.mr_backgroundFetch(), sectionNameKeyPath: "sectionTitle", cacheName: nil)
  }
  
  override public func load() -> [[DPAGDecryptedMessage]] {
    self.fetchedResultsController?.managedObjectContext.performAndWait {
      var messages: [[DPAGDecryptedMessage]] = []
      let blockFetched = {
        if let sections = self.fetchedResultsController?.sections?.reversed(), let managedObjectContext = self.fetchedResultsController?.managedObjectContext {
          var msgLoadCount = 20
          var msgIsNew = true
          let accountGuid = DPAGApplicationFacade.cache.account?.guid
          for sectionInfo in sections {
            var sectionContent = [DPAGDecryptedMessage]()
            let isPrivateKeyDecrypted = CryptoHelper.sharedInstance?.isPrivateKeyDecrypted() ?? false
            if let objects = sectionInfo.objects?.reversed() {
              for msgObj in objects {
                if let message = msgObj as? SIMSMessage {
                  msgIsNew = msgIsNew && (message.fromAccountGuid != accountGuid) && (message.dateReadLocal == nil && message.attributes?.dateReadLocal == nil)
                  let blockUnknown = {
                    let messageGuid = message.guid ?? ""
                    let type = "Unknown"
                    let decMessage: DPAGDecryptedMessage
                    switch message.typeMessage {
                      case .channel:
                        decMessage = DPAGDecryptedMessageChannel(messageGuid: messageGuid, contentType: type)
                      case .private:
                        decMessage = DPAGDecryptedMessagePrivate(messageGuid: messageGuid, contentType: type)
                      case .group:
                        decMessage = DPAGDecryptedMessageGroup(messageGuid: messageGuid, contentType: type)
                      case .unknown:
                        return
                    }
                    sectionContent.append(decMessage)
                  }
                  if msgIsNew || msgLoadCount > 0 {
                    if isPrivateKeyDecrypted {
                      if let decryptedMessage = DPAGApplicationFacade.cache.decryptedMessage(message, in: managedObjectContext) {
                        sectionContent.append(decryptedMessage)
                      } else {
                        blockUnknown()
                      }
                    } else {
                      blockUnknown()
                    }
                  } else {
                    blockUnknown()
                  }
                }
                msgLoadCount -= 1
              }
            }
            messages.append(sectionContent.reversed())
          }
        }
        self.messages = messages.reversed()
        self.fetchedResultsController?.delegate = self
      }
      do {
        try self.fetchedResultsController?.performFetch()
        blockFetched()
      } catch {
        let errorNS = error as NSError
        if errorNS.code == 134_060, (errorNS.userInfo["reason"] as? String)?.range(of: "out of order") != nil {
          do {
            try DPAGApplicationFacade.persistance.saveWithError { localContext in
              let allMessages = try SIMSMessage.findAll(in: localContext, with: self.fetchRequest?.predicate)
              DPAGLog("fetchedResultsController reordering #\(allMessages.count) messages")
              let allMessagesSorted = allMessages.sorted { (msg1, msg2) -> Bool in
                let retVal = msg1.sectionTitleDate.compare(msg2.sectionTitleDate)
                if retVal == .orderedSame {
                  let retVal2 = msg1.messageOrderId?.compare(msg2.messageOrderId ?? NSNumber()) ?? .orderedSame
                  if retVal2 == .orderedSame {
                    let retVal3 = msg1.dateSendServer?.compare(msg2.dateSendServer ?? Date()) ?? .orderedSame
                    return retVal3 == .orderedDescending
                  }
                  return retVal2 == .orderedAscending
                }
                return retVal == .orderedAscending
              }
              for i in 0 ..< allMessagesSorted.count {
                let msg = allMessagesSorted[i]
                msg.messageOrderId = NSNumber(value: i)
              }
            }
            try self.fetchedResultsController?.performFetch()
            blockFetched()
          } catch {
            DPAGLog("fetchedResultsController reorder messages failed with \(error)", level: .error)
          }
        } else {
          DPAGLog("fetchedResultsController fetched with error \(error)", level: .error)
        }
      }
    }
    return self.messages
  }
  
  override public func load(_ indexPaths: [IndexPath]) {
    guard let fetchedResultsController = self.fetchedResultsController else { return }
    fetchedResultsController.managedObjectContext.performAndWait {
      for indexPath in indexPaths {
        if let sections = fetchedResultsController.sections, sections.count > indexPath.section, sections[indexPath.section].numberOfObjects > indexPath.row, let message = fetchedResultsController.object(at: indexPath) as? SIMSMessage, let messageGuid = message.guid {
          if DPAGApplicationFacade.cache.decryptedMessageFast(messageGuid: messageGuid) == nil, let decMessage = DPAGApplicationFacade.cache.decryptedMessage(message, in: fetchedResultsController.managedObjectContext) {
            var sectionContent = self.messages[indexPath.section]
            sectionContent[indexPath.row] = decMessage
            self.messages[indexPath.section] = sectionContent
          }
        }
      }
    }
  }
}

public class DPAGFetchedResultsControllerChatStreamTimedMessages: DPAGFetchedResultsControllerChatStreamBase {
  override public init(streamGuid: String, contentUpdateBlock: @escaping DPAGFetchedResultsControllerChatStreamUpdateBlock) {
    super.init(streamGuid: streamGuid, contentUpdateBlock: contentUpdateBlock)
    self.initFetchedResultsController()
  }
  
  override func initFetchedResultsController() {
    super.initFetchedResultsController()
    let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: SIMSMessageToSend.entityName())
    fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \SIMSMessageToSend.dateToSend, ascending: true), NSSortDescriptor(keyPath: \SIMSMessageToSend.dateCreated, ascending: true)]
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates:
                                                  [
                                                    NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessageToSend.streamGuid), rightExpression: NSExpression(forConstantValue: streamGuid))
                                                  ])
    self.fetchRequest = fetchRequest
    self.fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: NSManagedObjectContext.mr_backgroundFetch(), sectionNameKeyPath: "sectionTitle", cacheName: nil)
  }
  
  override public func load() -> [[DPAGDecryptedMessage]] {
    self.fetchedResultsController?.managedObjectContext.performAndWait {
      var messages: [[DPAGDecryptedMessage]] = []
      let blockFetched = {
        if let sections = self.fetchedResultsController?.sections?.reversed(), let managedObjectContext = self.fetchedResultsController?.managedObjectContext {
          var msgLoadCount = 20
          for sectionInfo in sections {
            var sectionContent = [DPAGDecryptedMessage]()
            if let objects = sectionInfo.objects?.reversed() {
              for msgObj in objects {
                if let message = msgObj as? SIMSMessageToSend {
                  let blockUnknown = {
                    let messageGuid = message.guid ?? ""
                    let type = "Unknown"
                    let decMessage: DPAGDecryptedMessage
                    switch message.typeMessage {
                      case .channel:
                        decMessage = DPAGDecryptedMessageChannel(messageGuid: messageGuid, contentType: type)
                      case .private:
                        decMessage = DPAGDecryptedMessagePrivate(messageGuid: messageGuid, contentType: type)
                      case .group:
                        decMessage = DPAGDecryptedMessageGroup(messageGuid: messageGuid, contentType: type)
                      case .unknown:
                        return
                    }
                    sectionContent.append(decMessage)
                  }
                  if msgLoadCount > 0 {
                    if let decryptedMessage = DPAGApplicationFacade.cache.decryptedMessage(message, in: managedObjectContext) {
                      sectionContent.append(decryptedMessage)
                    } else {
                      blockUnknown()
                    }
                  } else {
                    blockUnknown()
                  }
                }
                msgLoadCount -= 1
              }
            }
            messages.append(sectionContent.reversed())
          }
        }
        self.messages = messages.reversed()
        self.fetchedResultsController?.delegate = self
      }
      do {
        try self.fetchedResultsController?.performFetch()
        blockFetched()
      } catch let error as NSError {
        if error.code == 134_060, (error.userInfo["reason"] as? String)?.range(of: "out of order") != nil {
          DPAGLog("Out of Order Fetch")
          do {
            try DPAGApplicationFacade.persistance.saveWithError { localContext in
              let allMessages = try SIMSMessage.findAll(in: localContext, with: self.fetchRequest?.predicate)
              let allMessagesSorted = allMessages.sorted { (msg1, msg2) -> Bool in
                let retVal = msg1.sectionTitleDate.compare(msg2.sectionTitleDate)
                if retVal == .orderedSame {
                  let retVal2 = msg1.messageOrderId?.compare(msg2.messageOrderId ?? NSNumber()) ?? .orderedSame
                  if retVal2 == .orderedSame {
                    let retVal3 = msg1.dateSendServer?.compare(msg2.dateSendServer ?? Date()) ?? .orderedSame
                    return retVal3 == .orderedDescending
                  }
                  return retVal2 == .orderedAscending
                }
                return retVal == .orderedAscending
              }
              for i in 0 ..< allMessagesSorted.count {
                let msg = allMessagesSorted[i]
                msg.messageOrderId = NSNumber(value: i)
              }
            }
            try self.fetchedResultsController?.performFetch()
            blockFetched()
          } catch {
            DPAGLog(error)
          }
        }
        DPAGLog(error.localizedDescription)
      } catch {
        DPAGLog(error)
      }
    }
    return self.messages
  }
  
  override public func load(_ indexPaths: [IndexPath]) {
    self.fetchedResultsController?.managedObjectContext.performAndWait {
      for indexPath in indexPaths {
        if let message = self.fetchedResultsController?.object(at: indexPath) as? SIMSMessageToSend, let messageGuid = message.guid, let managedObjectContext = self.fetchedResultsController?.managedObjectContext {
          if DPAGApplicationFacade.cache.decryptedMessageFast(messageGuid: messageGuid) == nil, let decMessage = DPAGApplicationFacade.cache.decryptedMessage(message, in: managedObjectContext) {
            var sectionContent = self.messages[indexPath.section]
            sectionContent.replaceSubrange(indexPath.row ..< indexPath.row + 1, with: [decMessage])
            self.messages[indexPath.section] = sectionContent
          }
        }
      }
    }
  }
}
