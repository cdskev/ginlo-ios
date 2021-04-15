//
//  DPAGMediaWorker.swift
//  SIMSmeCore
//
//  Created by Robert Burchert on 17.10.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import UIKit

public protocol DPAGMediaWorkerProtocol: AnyObject {
    func loadFileViewAttachments() -> [DPAGMediaViewAttachmentProtocol]
    func loadMediaViewAttachments(selectedMediaType: DPAGMediaSelectionOptions) -> DPAGMediaViewAttachments
}

public struct DPAGMediaViewAttachments {
    public let numberOfVideos: Int
    public let numberOfImages: Int
    public let numberOfVoiceRecs: Int
    public let numberOfFiles: Int

    public let mediaAttachments: [DPAGMediaViewAttachmentProtocol]
}

class DPAGMediaWorker: DPAGMediaWorkerProtocol {
    let mediaDAO: MediaDAOProtocol = MediaDAO()

    func loadMediaViewAttachments(selectedMediaType: DPAGMediaSelectionOptions) -> DPAGMediaViewAttachments {
        var medias: [DPAGMediaViewAttachmentProtocol] = []
        var numberOfVideos = 0
        var numberOfImages = 0
        var numberOfVoiceRecs = 0
        var numberOfFiles = 0

        let allFileAttachments = DPAGAttachmentWorker.allAttachmentGuidsWithInternalCopies(false)
        let attachments = self.mediaDAO.loadMediaViewAttachments(selectedMediaType: selectedMediaType, allFileAttachmentGuids: allFileAttachments)

        for decAttachment in attachments {
            switch decAttachment.attachmentType {
            case .video:
                numberOfVideos += 1

            case .image:
                numberOfImages += 1

            case .voiceRec:
                numberOfVoiceRecs += 1

            case .file:
                numberOfFiles += 1

            case .unknown:
                break
            }
            medias.append(DPAGMediaViewAttachment(messageGuid: decAttachment.messageGuid, decryptedAttachment: decAttachment))
        }

        return DPAGMediaViewAttachments(numberOfVideos: numberOfVideos, numberOfImages: numberOfImages, numberOfVoiceRecs: numberOfVoiceRecs, numberOfFiles: numberOfFiles, mediaAttachments: medias)
    }

    func loadFileViewAttachments() -> [DPAGMediaViewAttachmentProtocol] {
        let allFileAttachments = DPAGAttachmentWorker.allAttachmentGuidsWithInternalCopies(false)

        let mediaViewAttachmentsRetVal: [DPAGMediaViewAttachmentProtocol] = self.mediaDAO.loadFileViewAttachments(allFileAttachmentGuids: allFileAttachments).reduce(into: []) { mediaViewAttachments, decAttachment in
            mediaViewAttachments.append(DPAGMediaViewAttachment(messageGuid: decAttachment.messageGuid, decryptedAttachment: decAttachment))
        }

        return mediaViewAttachmentsRetVal
    }
}
