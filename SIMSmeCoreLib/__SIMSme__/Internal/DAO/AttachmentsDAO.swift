//
//  AttachmentsDAO.swift
//  SIMSmeCore
//
//  Created by Robert Burchert on 02.08.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import Foundation

protocol AttachmentsDAOProtocol {
    func allAttachments() throws -> [String: String]
}

class AttachmentsDAO: AttachmentsDAOProtocol {
    func allAttachments() throws -> [String: String] {
        let predicate = NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessage.attachment), rightNotExpression: NSExpression(forConstantValue: nil))
        var allAttachmentsCache: [String: String] = [:]

        try DPAGApplicationFacade.persistance.loadWithError { localContext in

            let fetchRequest = NSFetchRequest<NSDictionary>(entityName: SIMSMessage.entityName())

            fetchRequest.propertiesToFetch = [SIMS_ATTACHMENT]
            fetchRequest.resultType = .dictionaryResultType
            fetchRequest.predicate = predicate

            let allAttachments = try localContext.fetch(fetchRequest)

            for attachmentMsgDict in allAttachments {
                if let attachment = attachmentMsgDict[SIMS_ATTACHMENT] as? String {
                    allAttachmentsCache[attachment] = ""
                }
            }
        }

        return allAttachmentsCache
    }
}
