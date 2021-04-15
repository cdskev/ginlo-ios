//
//  DPAGFetchedResultsControllerCounter.swift
//  SIMSmeCoreLib
//
//  Created by RBU on 10/01/2017.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import UIKit

public typealias DPAGFetchedResultsControllerCounterUpdateBlock = (Int) -> Void

public class DPAGFetchedResultsControllerCounter: NSObject {
    var fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult>?

    var updateBlock: DPAGFetchedResultsControllerCounterUpdateBlock

    init(counterUpdateBlock: @escaping DPAGFetchedResultsControllerCounterUpdateBlock) {
        self.updateBlock = counterUpdateBlock

        super.init()
    }

    deinit {
        self.fetchedResultsController?.delegate = nil
    }

    public func load() -> Int {
        var retVal: Int?

        self.fetchedResultsController?.managedObjectContext.performAndWait {
            if let fetchedResultsController = self.fetchedResultsController {
                do {
                    try fetchedResultsController.performFetch()
                } catch {
                    DPAGLog(error)
                }

                retVal = self.fetchedResultsController?.fetchedObjects?.count
            }
        }

        return retVal ?? 0
    }
}

extension DPAGFetchedResultsControllerCounter: NSFetchedResultsControllerDelegate {
    public func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        let count = controller.fetchedObjects?.count ?? 0

        self.performBlockOnMainThread { [weak self] in

            self?.updateBlock(count)
        }
    }
}

public class DPAGFetchedResultsControllerCounterSingleChats: DPAGFetchedResultsControllerCounter {
    override public init(counterUpdateBlock: @escaping DPAGFetchedResultsControllerCounterUpdateBlock) {
        super.init(counterUpdateBlock: counterUpdateBlock)

        let fetchRequestSingle = NSFetchRequest<NSFetchRequestResult>(entityName: SIMSStream.entityName())

        fetchRequestSingle.sortDescriptors = []

        fetchRequestSingle.predicate = NSCompoundPredicate(orPredicateWithSubpredicates:
            [
                NSPredicate(format: "messages.@count > 0"),
                NSCompoundPredicate(andPredicateWithSubpredicates:
                    [
                        NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSStream.lastMessageDate), rightNotExpression: NSExpression(forConstantValue: nil)),
                        NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSStream.isConfirmed), rightExpression: NSExpression(forConstantValue: NSNumber(value: true)))
                    ])
            ])

        self.fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequestSingle, managedObjectContext: NSManagedObjectContext.mr_backgroundFetch(), sectionNameKeyPath: nil, cacheName: nil)

        self.fetchedResultsController?.delegate = self
    }
}

public class DPAGFetchedResultsControllerCounterGroupChats: DPAGFetchedResultsControllerCounter {
    override public init(counterUpdateBlock: @escaping DPAGFetchedResultsControllerCounterUpdateBlock) {
        super.init(counterUpdateBlock: counterUpdateBlock)

        let fetchRequestGroup = NSFetchRequest<NSFetchRequestResult>(entityName: SIMSGroupStream.entityName())

        fetchRequestGroup.sortDescriptors = []

        self.fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequestGroup, managedObjectContext: NSManagedObjectContext.mr_backgroundFetch(), sectionNameKeyPath: nil, cacheName: nil)

        self.fetchedResultsController?.delegate = self
    }
}

public class DPAGFetchedResultsControllerCounterGroupChatsWithManaged: DPAGFetchedResultsControllerCounter {
    override public init(counterUpdateBlock: @escaping DPAGFetchedResultsControllerCounterUpdateBlock) {
        super.init(counterUpdateBlock: counterUpdateBlock)

        let fetchRequestGroup = NSFetchRequest<NSFetchRequestResult>(entityName: SIMSGroupStream.entityName())

        fetchRequestGroup.predicate = NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSGroupStream.group?.type), rightNotExpression: NSExpression(forConstantValue: DPAGGroupType.restricted.rawValue))
        fetchRequestGroup.sortDescriptors = []

        self.fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequestGroup, managedObjectContext: NSManagedObjectContext.mr_backgroundFetch(), sectionNameKeyPath: nil, cacheName: nil)

        self.fetchedResultsController?.delegate = self
    }
}

public class DPAGFetchedResultsControllerCounterGroupChatsRestricted: DPAGFetchedResultsControllerCounter {
    override public init(counterUpdateBlock: @escaping DPAGFetchedResultsControllerCounterUpdateBlock) {
        super.init(counterUpdateBlock: counterUpdateBlock)

        let fetchRequestGroup = NSFetchRequest<NSFetchRequestResult>(entityName: SIMSGroupStream.entityName())

        fetchRequestGroup.predicate = NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSGroupStream.group?.type), rightExpression: NSExpression(forConstantValue: DPAGGroupType.restricted.rawValue))
        fetchRequestGroup.sortDescriptors = []

        self.fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequestGroup, managedObjectContext: NSManagedObjectContext.mr_backgroundFetch(), sectionNameKeyPath: nil, cacheName: nil)

        self.fetchedResultsController?.delegate = self
    }
}

public class DPAGFetchedResultsControllerCounterChannelChats: DPAGFetchedResultsControllerCounter {
    override public init(counterUpdateBlock: @escaping DPAGFetchedResultsControllerCounterUpdateBlock) {
        super.init(counterUpdateBlock: counterUpdateBlock)

        let fetchRequestChannel = NSFetchRequest<NSFetchRequestResult>(entityName: SIMSChannelStream.entityName())

        fetchRequestChannel.sortDescriptors = []

        self.fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequestChannel, managedObjectContext: NSManagedObjectContext.mr_backgroundFetch(), sectionNameKeyPath: nil, cacheName: nil)

        self.fetchedResultsController?.delegate = self
    }
}

public typealias DPAGFetchedResultsControllerCounterTimedMessagesUpdateBlock = (Int, Bool) -> Void

public class DPAGFetchedResultsControllerCounterTimedMessages: NSObject, NSFetchedResultsControllerDelegate {
    var fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult>?

    var updateBlock: DPAGFetchedResultsControllerCounterTimedMessagesUpdateBlock

    public init(streamGuid: String, counterTimedMessagesUpdateBlock: @escaping DPAGFetchedResultsControllerCounterTimedMessagesUpdateBlock) {
        self.updateBlock = counterTimedMessagesUpdateBlock

        super.init()

        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: SIMSMessageToSend.entityName())

        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \SIMSMessageToSend.dateToSend, ascending: true)]

        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates:
            [
                NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessageToSend.streamGuid), rightExpression: NSExpression(forConstantValue: streamGuid))
            ])

        self.fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: NSManagedObjectContext.mr_backgroundFetch(), sectionNameKeyPath: nil, cacheName: nil)

        self.fetchedResultsController?.delegate = self
    }

    public func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        let count = controller.fetchedObjects?.count ?? 0

        var hasFailedMessages = false

        if let fetchedObjects = controller.fetchedObjects {
            for msgObj in fetchedObjects {
                if let msg = msgObj as? SIMSMessageToSend, msg.sendingState.uintValue == DPAGMessageState.sentFailed.rawValue {
                    hasFailedMessages = true
                    break
                }
            }
        }

        self.performBlockOnMainThread { [weak self] in

            self?.updateBlock(count, hasFailedMessages)
        }
    }

    public func load() {
        self.fetchedResultsController?.managedObjectContext.performAndWait {
            if let fetchedResultsController = self.fetchedResultsController {
                do {
                    try fetchedResultsController.performFetch()
                } catch {
                    DPAGLog(error)
                }

                self.controllerDidChangeContent(fetchedResultsController)
            }
        }
    }
}
