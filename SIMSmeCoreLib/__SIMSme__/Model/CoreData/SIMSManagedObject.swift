//
//  SIMSManagedObject.swift
//  SIMSme
//
//  Created by RBU on 19/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import Foundation

class SIMSManagedObjectInstance: NSManagedObject, SIMSManagedObjectInstanceProtocol {}

protocol SIMSManagedObjectInstanceProtocol {}

class SIMSManagedObject: SIMSManagedObjectInstance, SIMSManagedObjectProtocol {
    @NSManaged var guid: String?
}

protocol SIMSManagedObjectProtocol {}

extension SIMSManagedObjectProtocol where Self: SIMSManagedObject {
    static func findFirst(byGuid guid: String?, in localContext: NSManagedObjectContext) -> Self? {
        guard let guid = guid else {
            return nil
        }

        return Self.mr_findFirst(with: NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \Self.guid), rightExpression: NSExpression(forConstantValue: guid)), in: localContext)
    }
}

extension SIMSManagedObjectInstanceProtocol where Self: SIMSManagedObjectInstance {
    static func findAll(in localContext: NSManagedObjectContext, relationshipKeyPathsForPrefetching: [String] = []) throws -> [Self] {
        try Self.findAll(in: localContext, with: nil, relationshipKeyPathsForPrefetching: relationshipKeyPathsForPrefetching)
    }

    static func findAll(in localContext: NSManagedObjectContext, with predicate: NSPredicate?, relationshipKeyPathsForPrefetching: [String] = []) throws -> [Self] {
        try Self.findAll(in: localContext, with: predicate, sortDescriptors: nil, relationshipKeyPathsForPrefetching: relationshipKeyPathsForPrefetching)
    }

    static func findAll(in localContext: NSManagedObjectContext, with predicate: NSPredicate?, sortDescriptors: [NSSortDescriptor]?, relationshipKeyPathsForPrefetching: [String] = []) throws -> [Self] {
        let fetchRequest = NSFetchRequest<Self>(entityName: Self.mr_entityName())

        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.predicate = predicate
        fetchRequest.sortDescriptors = sortDescriptors
        fetchRequest.relationshipKeyPathsForPrefetching = relationshipKeyPathsForPrefetching

        return try localContext.fetch(fetchRequest)
    }
}

class SIMSManagedObjectMessage: SIMSManagedObject {
    @NSManaged var rawSignature: String?
    @NSManaged var rawSignature256: String?
    @NSManaged var attachment: String?
    @NSManaged var attachmentHash: String?
    @NSManaged var attachmentHash256: String?
    @NSManaged var data: String?
    @NSManaged var dataSignature: String?
    @NSManaged var dataSignature256: String?
    @NSManaged private(set) var messageType: NSNumber?
    @NSManaged private(set) var options: NSNumber?
    // @NSManaged var sectionTitle: String?
    @NSManaged var sendingState: NSNumber

    var optionsMessage: DPAGMessageOptions {
        get {
            DPAGMessageOptions(rawValue: self.options?.intValue ?? 0)
        }
        set {
            self.options = NSNumber(value: newValue.rawValue)
        }
    }

    var typeMessage: DPAGMessageType {
        get {
            DPAGMessageType(rawValue: self.messageType?.intValue ?? DPAGMessageType.unknown.rawValue) ?? .unknown
        }
        set {
            self.messageType = NSNumber(value: newValue.rawValue)
        }
    }
}
