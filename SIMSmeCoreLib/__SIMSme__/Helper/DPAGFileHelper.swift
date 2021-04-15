//
//  DPAGFileHelper.m
//  Doqcuty
//
//  Created by Florian Plewka on 07.03.12.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation

public struct DPAGFileHelper {
    private init() {}

    private static func mr_applicationStorageDirectory() -> URL? {
        guard let applicationName = Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String else { return nil }
        return self.mr_directory(type: .applicationSupportDirectory)?.appendingPathComponent(applicationName)
    }

    private static func mr_url(forStoreName storeFileName: String) -> URL? {
        let pathForStoreName = self.mr_applicationStorageDirectory()?.appendingPathComponent(storeFileName)
        return pathForStoreName
    }

    private static func mr_directory(type: FileManager.SearchPathDirectory) -> URL? {
        try? FileManager().url(for: type, in: .userDomainMask, appropriateFor: nil, create: true)
    }

    static func createFolderInDocBase(forPathComponent comp: String, isExcludedFromBackup flag: Bool) throws -> URL? {
        guard let path = DPAGConstantsGlobal.documentsDirectoryURL?.appendingPathComponent(comp) else { return nil }
        if FileManager.default.fileExists(atPath: path.path) == false {
            try FileManager.default.createDirectory(at: path, withIntermediateDirectories: false, attributes: nil)
            try self.setBackupAttributeToItem(at: path, allowBackup: flag == false)
        }
        return path
    }

    public static func initModel() throws {
        if let url = self.mr_url(forStoreName: FILEHELPER_FILE_NAME_DATABASE) {
            try DPAGFileHelper.setBackupAttributeToItem(at: url.deletingLastPathComponent(), allowBackup: false)
        }
    }

    public static func changeDBProtection() throws {
        if let url = self.mr_url(forStoreName: FILEHELPER_FILE_NAME_DATABASE) {
            try (url as NSURL).setResourceValue(URLFileProtection.completeUnlessOpen, forKey: .fileProtectionKey)
        }
    }

    static func setBackupAttributeToItem(at url: URL, allowBackup _: Bool) throws {
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var urlMutable = url
        try urlMutable.setResourceValues(resourceValues)
    }

    static func setFolderRightsForBackup(allowBackupFlag: Bool) throws {
        guard let url = self.mr_url(forStoreName: FILEHELPER_FILE_NAME_DATABASE) else { return }
        let manager = FileManager.default
        try self.setBackupAttributeToItem(at: url, allowBackup: allowBackupFlag)
        guard let aesKeyPath = try DPAGFileHelper.createFolderInDocBase(forPathComponent: CryptoHelperExtended.AES_KEY_FOLDER_NAME_PBDKF, isExcludedFromBackup: allowBackupFlag == false) else { return }
        try self.setBackupAttributeToItem(at: aesKeyPath, allowBackup: allowBackupFlag)
        if let fileEnumerator = manager.enumerator(at: aesKeyPath, includingPropertiesForKeys: nil) {
            for filePath in fileEnumerator {
                if let fileURL = filePath as? URL {
                    try self.setBackupAttributeToItem(at: fileURL, allowBackup: allowBackupFlag)
                } else if let fileName = filePath as? String {
                    try self.setBackupAttributeToItem(at: aesKeyPath.appendingPathComponent(fileName), allowBackup: allowBackupFlag)
                }
            }
        }
    }
}
