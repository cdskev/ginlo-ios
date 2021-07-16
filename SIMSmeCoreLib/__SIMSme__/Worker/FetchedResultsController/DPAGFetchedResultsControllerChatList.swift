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
            if let newIndexPath = newIndexPath, indexPath == nil {
                if let aStream = anObject as? SIMSMessageStream, let guid = aStream.guid {
                    self.changes.append(DPAGFetchedResultsControllerRowChange(changeType: .insert, guid: guid, changedIndexPath: newIndexPath, changedIndexPathMovedTo: nil))
                    DPAGApplicationFacade.cache.updateDecryptedStream(streamGuid: guid, stream: aStream, in: controller.managedObjectContext)
                }
            }

        case .delete:
            if let indexPath = indexPath {
                if let aStream = anObject as? SIMSMessageStream, let guid = aStream.guid {
                    self.changes.append(DPAGFetchedResultsControllerRowChange(changeType: .delete, guid: guid, changedIndexPath: indexPath, changedIndexPathMovedTo: nil))
                }
            }
        case .update:
            if let indexPath = indexPath {
                if let aStream = anObject as? SIMSMessageStream, let guid = aStream.guid {
                    self.changes.append(DPAGFetchedResultsControllerRowChange(changeType: .update, guid: guid, changedIndexPath: indexPath, changedIndexPathMovedTo: nil))
                    DPAGApplicationFacade.cache.updateDecryptedStream(streamGuid: guid, stream: aStream, in: controller.managedObjectContext)
                }
            }
        case .move:
            if let indexPath = indexPath, let newIndexPath = newIndexPath {
                if indexPath.row == newIndexPath.row, indexPath.section == newIndexPath.section {
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
                    }
                    break
                } else {
                    if let aStream = anObject as? SIMSMessageStream, let guid = aStream.guid {
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
                    }
                }
            }

        @unknown default:
            DPAGLog("Switch with unknown value: \(type.rawValue)", level: .warning)
        }
    }

    public func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        if controller != self.fetchedResultsController {
            return
        }
        DPAGLog("attempt list beginUpdates")
        self.changes = []
    }

    public func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        let changes = self.changes
        let streams: [String] = controller.fetchedObjects?.compactMap { (res) -> String? in
            (res as? SIMSMessageStream)?.guid
        } ?? []
        self.performBlockOnMainThread { [weak self] in
            self?.updateBlock(changes, streams)
        }
    }
}
