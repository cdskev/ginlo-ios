//
//  DPAGFetchedResultsControllerChatList.swift
//  SIMSmeCoreLib
//
//  Created by RBU on 11/01/2017.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import UIKit

public protocol DPAGFetchedResultsControllerChange {
    var changeType: NSFetchedResultsChangeType { get }
}

public struct DPAGFetchedResultsControllerRowChange: DPAGFetchedResultsControllerChange {
    public let changeType: NSFetchedResultsChangeType
    public let guid: String
    public let changedIndexPath: IndexPath
    public let changedIndexPathMovedTo: IndexPath?
}

public struct DPAGFetchedResultsControllerSectionChange: DPAGFetchedResultsControllerChange {
    public let changeType: NSFetchedResultsChangeType
    public let changedSection: Int
}

public typealias DPAGFetchedResultsControllerChatListUpdateBlock = ([DPAGFetchedResultsControllerChange], [String]) -> Void

public class DPAGFetchedResultsControllerChatList: NSObject {
    var changes: [DPAGFetchedResultsControllerChange] = []

    var fetchRequest: NSFetchRequest<NSFetchRequestResult>?
    public fileprivate(set) var fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult>?

    var streams: [String] = []

    var updateBlock: DPAGFetchedResultsControllerChatListUpdateBlock

    public init(contentUpdateBlock: @escaping DPAGFetchedResultsControllerChatListUpdateBlock) {
        self.updateBlock = contentUpdateBlock

        super.init()

        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: SIMSMessageStream.entityName())

        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \SIMSMessageStream.lastMessageDate, ascending: false)]

        fetchRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates:
            [
                NSCompoundPredicate(andPredicateWithSubpredicates: [
                    NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessageStream.streamType), rightExpression: NSExpression(forConstantValue: DPAGStreamType.single.rawValue)),
                    NSCompoundPredicate(orPredicateWithSubpredicates:
                        [
                            NSCompoundPredicate(andPredicateWithSubpredicates:
                                [
                                    NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessageStream.lastMessageDate), rightNotExpression: NSExpression(forConstantValue: nil)),
                                    NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessageStream.isConfirmed), rightExpression: NSExpression(forConstantValue: NSNumber(value: true)))
                                ]),
                            NSCompoundPredicate(andPredicateWithSubpredicates:
                                [
                                    NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessageStream.isConfirmed), rightExpression: NSExpression(forConstantValue: NSNumber(value: false))),
                                    NSPredicate(format: "messages.@count > 0")
                                ])

                        ])
                ]),
                NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessageStream.streamType), rightExpression: NSExpression(forConstantValue: DPAGStreamType.group.rawValue)),
                NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessageStream.streamType), rightExpression: NSExpression(forConstantValue: DPAGStreamType.channel.rawValue))
            ])

        self.fetchRequest = fetchRequest
        self.fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: NSManagedObjectContext.mr_backgroundFetch(), sectionNameKeyPath: nil, cacheName: nil)
    }

    deinit {
        self.fetchedResultsController?.delegate = nil
    }

    public func load() -> [String] {
        self.fetchedResultsController?.managedObjectContext.performAndWait {
            do {
                try self.fetchedResultsController?.performFetch()

                if let fetchedObjects = self.fetchedResultsController?.fetchedObjects, let localContext = self.fetchedResultsController?.managedObjectContext {
                    var count = 0
                    for streamObj in fetchedObjects {
                        if let stream = streamObj as? SIMSMessageStream {
                            let streamGuid = stream.guid ?? ""

                            if count < 10 {
                                _ = DPAGApplicationFacade.cache.decryptedStream(stream: stream, in: localContext)
                            }

                            self.streams.append(streamGuid)

                            count += 1
                        }
                    }
                }

                self.fetchedResultsController?.delegate = self

            } catch {
                DPAGLog(error)
            }
        }

        return self.streams
    }

    public func load(indexPaths: [IndexPath]) {
        for indexPath in indexPaths {
            tryC {
                if indexPath.section == 0, (self.fetchedResultsController?.fetchedObjects?.count ?? 0) > indexPath.row, let stream = self.fetchedResultsController?.object(at: indexPath) as? SIMSMessageStream, let managedObjectContext = self.fetchedResultsController?.managedObjectContext {
                    if DPAGApplicationFacade.cache.decrypteStream(stream: stream) == nil {
                        _ = DPAGApplicationFacade.cache.decryptedStream(stream: stream, in: managedObjectContext)
                    }
                }
            }.catch { _ in }
        }
    }
}

extension DPAGFetchedResultsControllerChatList: NSFetchedResultsControllerDelegate {
    public func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:

            // IMPORT iOS 8 fix with iOS 9 SDK
            // iOS 9 / Swift 2.0 BUG with running 8.4
            if let newIndexPath = newIndexPath, indexPath == nil {
                DPAGLog("attempt list insertRowsAtIndexPaths at \(newIndexPath)")

                if let aStream = anObject as? SIMSMessageStream, let guid = aStream.guid {
                    self.changes.append(DPAGFetchedResultsControllerRowChange(changeType: .insert, guid: guid, changedIndexPath: newIndexPath, changedIndexPathMovedTo: nil))

                    DPAGApplicationFacade.cache.updateDecryptedStream(streamGuid: guid, stream: aStream, in: controller.managedObjectContext)

                    /* if let decryptedStream = DPAGApplicationFacade.cache.decryptedStream(aStream, in: controller.managedObjectContext)
                     {
                         self.streams.insert(decryptedStream, at: newIndexPath.row)
                     }
                     else
                     {
                         let streamGuid = aStream.guid ?? ""
                         let streamType = aStream.streamType.intValue
                         let decryptedStream = streamType == DPAGStreamType.channel.rawValue ? DPAGDecryptedStreamChannel(guid:streamGuid) : (streamType == DPAGStreamType.single.rawValue ? DPAGDecryptedStreamPrivate(guid:streamGuid) : DPAGDecryptedStreamGroup(guid:streamGuid))

                         self.streams.insert(decryptedStream, at: newIndexPath.row)
                     } */
                }
            }

        case .delete:

            if let indexPath = indexPath {
                DPAGLog("attempt list deleteRowsAtIndexPaths at \(indexPath)")

                if let aStream = anObject as? SIMSMessageStream, let guid = aStream.guid {
                    self.changes.append(DPAGFetchedResultsControllerRowChange(changeType: .delete, guid: guid, changedIndexPath: indexPath, changedIndexPathMovedTo: nil))

                    // self.streams.remove(at: indexPath.row)
                }
            }

        case .update:

            if let indexPath = indexPath {
                DPAGLog("attempt list reloadRowsAtIndexPaths at \(indexPath)")

                if let aStream = anObject as? SIMSMessageStream, let guid = aStream.guid {
                    self.changes.append(DPAGFetchedResultsControllerRowChange(changeType: .update, guid: guid, changedIndexPath: indexPath, changedIndexPathMovedTo: nil))

                    DPAGApplicationFacade.cache.updateDecryptedStream(streamGuid: guid, stream: aStream, in: controller.managedObjectContext)

                    /* if let decryptedStream = DPAGApplicationFacade.cache.decryptedStream(aStream, in: controller.managedObjectContext)
                     {
                         self.streams.replaceSubrange(indexPath.row..<indexPath.row+1, with: [decryptedStream])
                     }
                     else
                     {
                         let streamGuid = aStream.guid ?? ""
                         let streamType = aStream.streamType.intValue
                         let decryptedStream = streamType == DPAGStreamType.channel.rawValue ? DPAGDecryptedStreamChannel(guid:streamGuid) : (streamType == DPAGStreamType.single.rawValue ? DPAGDecryptedStreamPrivate(guid:streamGuid) : DPAGDecryptedStreamGroup(guid:streamGuid))

                         self.streams.replaceSubrange(indexPath.row..<indexPath.row+1, with: [decryptedStream])
                     } */
                }
            }

        case .move:

            if let indexPath = indexPath, let newIndexPath = newIndexPath {
                if indexPath.row == newIndexPath.row, indexPath.section == newIndexPath.section {
                    DPAGLog("attempt list reloadRowsAtIndexPaths for move at \(indexPath)")

                    if let aStream = anObject as? SIMSMessageStream, let guid = aStream.guid {
                        if self.changes.contains(where: { (change) -> Bool in
                            if let changeRow = change as? DPAGFetchedResultsControllerRowChange {
                                return changeRow.changeType == .update && changeRow.changedIndexPath == indexPath && changeRow.guid == guid
                            }
                            return false
                        }) {
                            break
                        }

                        self.changes.append(DPAGFetchedResultsControllerRowChange(changeType: .update, guid: guid, changedIndexPath: indexPath, changedIndexPathMovedTo: newIndexPath))

                        DPAGApplicationFacade.cache.updateDecryptedStream(streamGuid: guid, stream: aStream, in: controller.managedObjectContext)

                        /* if let decryptedStream = DPAGApplicationFacade.cache.decryptedStream(aStream, in: controller.managedObjectContext)
                         {
                             self.streams.replaceSubrange(indexPath.row..<indexPath.row+1, with: [decryptedStream])
                         }
                         else
                         {
                             let streamGuid = aStream.guid ?? ""
                             let streamType = aStream.streamType.intValue
                             let decryptedStream = streamType == DPAGStreamType.channel.rawValue ? DPAGDecryptedStreamChannel(guid:streamGuid) : (streamType == DPAGStreamType.single.rawValue ? DPAGDecryptedStreamPrivate(guid:streamGuid) : DPAGDecryptedStreamGroup(guid:streamGuid))

                             self.streams.replaceSubrange(indexPath.row..<indexPath.row+1, with: [decryptedStream])
                         } */
                    }
                    break
                } else {
                    DPAGLog("attempt list move with moveRowAt from \(indexPath) to \(newIndexPath)")

                    if let aStream = anObject as? SIMSMessageStream, let guid = aStream.guid {
                        // self.changes.append(DPAGFetchedResultsControllerRowChange(changeType: .move, changedIndexPath: indexPath, changedIndexPathMovedTo: newIndexPath))
                        self.changes.append(DPAGFetchedResultsControllerRowChange(changeType: .delete, guid: guid, changedIndexPath: indexPath, changedIndexPathMovedTo: nil))
                        self.changes.append(DPAGFetchedResultsControllerRowChange(changeType: .insert, guid: guid, changedIndexPath: newIndexPath, changedIndexPathMovedTo: nil))

                        if let idx = self.changes.firstIndex(where: { (change) -> Bool in
                            if let changeRow = change as? DPAGFetchedResultsControllerRowChange {
                                return changeRow.changeType == .update && changeRow.changedIndexPath == indexPath && changeRow.guid == guid
                            }
                            return false
                        }) {
                            self.changes.remove(at: idx)
                        }

                        /* let streamOld = self.streams.remove(at: indexPath.row)

                         if let decryptedStream = DPAGApplicationFacade.cache.decryptedStream(aStream, in: controller.managedObjectContext)
                         {
                             self.streams.insert(decryptedStream, at: newIndexPath.row)
                         }
                         else
                         {
                             let streamGuid = aStream.guid ?? ""
                             let streamType = aStream.streamType.intValue
                             let decryptedStream = streamType == DPAGStreamType.channel.rawValue ? DPAGDecryptedStreamChannel(guid:streamGuid) : (streamType == DPAGStreamType.single.rawValue ? DPAGDecryptedStreamPrivate(guid:streamGuid) : DPAGDecryptedStreamGroup(guid:streamGuid))

                             self.streams.insert(decryptedStream, at: newIndexPath.row)
                         } */
                    }
                }
            }

        @unknown default:
            DPAGLog("Switch with unknown value: \(type.rawValue)", level: .warning)
        }
    }

    /*
     public func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType)
     {
         switch (type)
         {
         case .Insert:
             self.idxSectionsInsert.append(sectionIndex)
             DPAGLog("attempt insertSections at \(sectionIndex)")
             self.streams.insert([], atIndex: sectionIndex)
             break

         case .Delete:
             self.idxSectionsDelete.append(sectionIndex)
             DPAGLog("attempt deleteSections at \(sectionIndex)")
             self.streams.removeAtIndex(sectionIndex)
             break

         case .Update:
             self.idxSectionsReload.append(sectionIndex)
             DPAGLog("attempt reloadSections at \(sectionIndex)")
             break

         default:
             break
         }
     }
     */
    public func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        if controller != self.fetchedResultsController {
            return
        }
        DPAGLog("attempt list beginUpdates")

        self.changes = []
    }

    public func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        DPAGLog("attempt list endUpdates")
        /*
         let changesRow = self.changes.flatMap { return ($0 as? DPAGFetchedResultsControllerRowChange) }

         let changesRowDelete = changesRow.filter { change -> Bool in
             return change.changeType == .delete
         }
         let changesRowInsert = changesRow.filter { change -> Bool in
             return change.changeType == .insert
         }

         let changesRowDeleteOrdered = changesRowDelete.sorted { (change1, change2) -> Bool in
             return change1.changedIndexPath.section > change2.changedIndexPath.section || (change1.changedIndexPath.section == change2.changedIndexPath.section && change1.changedIndexPath.row >= change2.changedIndexPath.row)
         }
         let changesRowInsertOrdered = changesRowInsert.sorted { (change1, change2) -> Bool in
             return change1.changedIndexPath.section < change2.changedIndexPath.section || (change1.changedIndexPath.section == change2.changedIndexPath.section && change1.changedIndexPath.row <= change2.changedIndexPath.row)
         }

         for change in changesRowDeleteOrdered
         {
             self.streams.remove(at: change.changedIndexPath.row)
         }

         for change in changesRowInsertOrdered
         {
             nil != DPAGApplicationFacade.cache.decryptedStreamForGuid(change.guid, in: controller.managedObjectContext)

             self.streams.insert(change.guid, at: change.changedIndexPath.row)
         }
         */
        let changes = self.changes
        let streams: [String] = controller.fetchedObjects?.compactMap { (res) -> String? in
            (res as? SIMSMessageStream)?.guid
        } ?? []

        self.performBlockOnMainThread { [weak self] in

            self?.updateBlock(changes, streams)
        }
    }
}
