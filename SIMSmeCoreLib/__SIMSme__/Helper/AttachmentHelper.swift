//
//  AttachmentHelper.swift
//  SIMSmeCore
//
//  Created by Robert Burchert on 07.08.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation

public struct AttachmentHelper {
    private init() {}

    public static func attachmentAlreadySavedForGuid(_ guid: String?) -> Bool {
        if let path = self.attachmentFilePath(guid: guid)?.path {
            return FileManager.default.fileExists(atPath: path)
        }
        return false
    }

    static func attachmentFilePath(guid: String?) -> URL? {
        guard let attachmentGuid = guid else {
            return nil
        }
        let filename = "att_" + attachmentGuid

        let path = DPAGConstantsGlobal.documentsDirectoryURL?.appendingPathComponent(filename, isDirectory: false)

        return path
    }
}
