//
//  DPAGConstantsGlobal.swift
//  SIMSme
//
//  Created by RBU on 15/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import AFNetworking
import AVFoundation
import UIKit

public typealias DPAGProgressBlock = (Progress, Bool) -> Void
public typealias DPAGCompletion = () -> Void

public typealias DPAGServiceResponseBlock = (_ responseObject: Any?, _ errorCode: String?, _ errorMessage: String?) -> Void

public protocol DPAGProgressHUDWithProgressDelegate: AnyObject {
    func setProgress(_ progress: CGFloat, withText text: String?)
}

public enum DPAGConstantsGlobal {
    public static let isTestFlight = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"

    public static let kSystemChatAccountGuid = "0:{00000000-0000-0000-0000-000000000000}"

    public static let documentsDirectory = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true).first

    public static let documentsDirectoryURL = try? FileManager().url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)

    static let libraryDirectoryURL = try? FileManager().url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    public static let loggingURL = DPAGConstantsGlobal.libraryDirectoryURL?.appendingPathComponent("ginloLogs")

    public static let kChatMaxWidthObjects: CGFloat = 220

    public static let kProfileImageSize = CGSize(width: 200, height: 200)
}

public struct DPAGFunctionsGlobal {
    private init() {}

    public static func uuid() -> String {
        UUID().uuidString
    }

    public static func uuid(prefix: DPAGGuidPrefix) -> String {
        if prefix == .none {
            return self.uuid()
        }
        return String(format: "%@{%@}", prefix.rawValue, self.uuid())
    }

    static func address(_ o: UnsafeRawPointer) -> Int {
        Int(bitPattern: o)
    }

    static func synchronizedReturnWithError<T>(_ lockObj: Any, closure: () throws -> T) throws -> T {
        objc_sync_enter(lockObj)
        defer { objc_sync_exit(lockObj) }

        let retVal: T = try closure()

        return retVal
    }

    static func synchronizedReturn<T>(_ lockObj: Any, closure: () -> T) -> T {
        if AppConfig.buildConfigurationMode == .DEBUG {
            let currentTime = Int64(Date().timeIntervalSince1970 * 1_000)
            // DPAGLog("Enter Sync %i Thread:%@", address(unsafeAddressOf(lockObj)), NSThread.currentThread())

            objc_sync_enter(lockObj)
            defer { objc_sync_exit(lockObj) }

            let currentTime2 = Int64(Date().timeIntervalSince1970 * 1_000)
            if (currentTime2 - currentTime) > Int64(10), Thread.isMainThread {
                DPAGLog("Enter Sync needs more than 10 ms  %i Thread:%@ Object: \(lockObj)", address(Unmanaged.passUnretained(lockObj as AnyObject).toOpaque()), Thread.current)
            }

            let retVal: T = closure()

            let currentTime3 = Int64(Date().timeIntervalSince1970 * 1_000)
            if (currentTime3 - currentTime) > Int64(40) {
                DPAGLog("Object Synced more than 40 ms %i Thread:%@ Object: \(lockObj)", address(Unmanaged.passUnretained(lockObj as AnyObject).toOpaque()), Thread.current)
            }
            // DPAGLog("Leave Sync %i", address(unsafeAddressOf(lockObj)))

            return retVal
        } else {
            objc_sync_enter(lockObj)
            defer { objc_sync_exit(lockObj) }

            let retVal: T = closure()

            return retVal
        }
    }

    public static func synchronizedWithError(_ lockObj: Any, block: () throws -> Void) throws {
        objc_sync_enter(lockObj)
        defer { objc_sync_exit(lockObj) }

        try block()
    }

    public static func synchronized(_ lockObj: Any, block: DPAGCompletion) {
        if AppConfig.buildConfigurationMode == .DEBUG {
            let currentTime = Int64(Date().timeIntervalSince1970 * 1_000)
            // DPAGLog("Enter Sync %i Thread:%@", address(unsafeAddressOf(lockObj)), NSThread.currentThread())
            objc_sync_enter(lockObj)
            defer { objc_sync_exit(lockObj) }

            let currentTime2 = Int64(Date().timeIntervalSince1970 * 1_000)
            if (currentTime2 - currentTime) > Int64(10), Thread.isMainThread {
                DPAGLog("Enter Sync needs more than 10 ms  %i Thread:%@ Object: \(lockObj)", address(Unmanaged.passUnretained(lockObj as AnyObject).toOpaque()), Thread.current)
            }

            block()

            let currentTime3 = Int64(Date().timeIntervalSince1970 * 1_000)
            if (currentTime3 - currentTime) > Int64(40), Thread.isMainThread {
                DPAGLog("Object Synced more than 40 ms %i Thread:%@ Object: \(lockObj)", address(Unmanaged.passUnretained(lockObj as AnyObject).toOpaque()), Thread.current)
            }
            if (currentTime3 - currentTime) > Int64(100), !Thread.isMainThread {
                DPAGLog("Object Synced more than 100 ms %i Thread:%@ Object: \(lockObj)", address(Unmanaged.passUnretained(lockObj as AnyObject).toOpaque()), Thread.current)
            }
            // DPAGLog("Leave Sync %i", address(unsafeAddressOf(lockObj)))
        } else {
            objc_sync_enter(lockObj)
            defer { objc_sync_exit(lockObj) }

            block()
        }
    }

    public static func DPAGLocalizedString(_ key: String, comment: String? = nil) -> String {
        let value = self.DPAGLocalizedString(key, bundle: Bundle.main, comment: comment)

        if value == key, let path = Bundle.main.path(forResource: "Base", ofType: "lproj"), let bundleBase = Bundle(path: path) {
            return self.DPAGLocalizedString(key, bundle: bundleBase, comment: comment)
        }

        return value
    }

    private static func DPAGLocalizedString(_ key: String, bundle: Bundle, comment _: String? = nil) -> String {
        if AppConfig.isShareExtension {
            return bundle.localizedString(forKey: key, value: nil, table: nil)
        } else if AppConfig.isNotificationExtension {
            return bundle.localizedString(forKey: key, value: nil, table: nil)
        } else {
            var string = ""
            if DPAGApplicationFacade.preferences.isWhiteLabelBuild {
                if let ident = DPAGApplicationFacade.preferences.mandantIdent {
                    string = bundle.localizedString(forKey: key, value: nil, table: ident.lowercased())
                    if string == key {
                        string = bundle.localizedString(forKey: key, value: nil, table: nil)
                    }
                }
            } else {
                string = bundle.localizedString(forKey: key, value: nil, table: nil)
            }
            return string
        }
    }

    public static func pathForCustomTMPDirectory() -> URL? {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    }

    public static func pathForVoiceRecording() -> URL? {
        let outputUrl = self.pathForCustomTMPDirectory()?.appendingPathComponent("voice").appendingPathExtension("m4a")
        return outputUrl
    }

    public static func unlockChilkat(_ license: String) throws {
        var status: Int = 0
        if let glob = CkoGlobal() {
            status = glob.unlockStatus.intValue
            if status == 2 {
                return
            }
            let success: Bool = glob.unlockBundle(license)
            if success != true {
                DPAGLog("Chilkat Lib could not be unlocked!" + (glob.lastErrorText ?? "???"))
                throw DPAGErrorCrypto.errCko
            }
            status = glob.unlockStatus.intValue
        } else {
            DPAGLog("Chilkat Lib could not be unlocked! - could not find CkoGlobal()")
            throw DPAGErrorCrypto.errCko
        }
        if status == 2 {
            NSLog("CHILKAT:: Unlocked using purchased unlock code.")
        } else {
            NSLog("CHILKAT:: Unlocked in trial mode.")
        }
    }

    public static func getLogs() -> Data? {
        appLogger.getLogs()
    }

    static func printBacktrace() {
        if AppConfig.buildConfigurationMode == .DEBUG {
            let callStackSymbols = Thread.callStackSymbols
            for callStackSymbol in callStackSymbols {
                NSLog("%@\n", callStackSymbol)
            }
        }
    }
}

func DPAGLocalizedString(_ key: String, comment: String? = nil) -> String {
    DPAGFunctionsGlobal.DPAGLocalizedString(key, comment: comment)
}

public class DPAGHelperEx: NSObject {
    class func getErrorMessageIdentifier(errorObject: [AnyHashable: Any]) -> String? {
        if let errorIdentifier = errorObject["ident"] as? String {
            DPAGLog("service error: %@", errorIdentifier)

            let key = String(format: "service.%@", errorIdentifier)

            return key
        }
        return nil
    }

    class func getErrorCode(errorObject: [AnyHashable: Any]) -> String? {
        if let errorIdentifier = errorObject["ident"] as? String {
            DPAGLog("service error: %@", errorIdentifier)
            return errorIdentifier
        }
        return nil
    }

    private class func imageFilePath(forGroupGuid guid: String) -> URL? {
        let filename = String(format: "img_%@", guid)
        let path = DPAGConstantsGlobal.documentsDirectoryURL?.appendingPathComponent(filename)

        return path
    }

    public class func saveBase64Image(encodedImage encodedImageIn: String?, forGroupGuid guid: String) {
        guard var path = self.imageFilePath(forGroupGuid: guid), let encodedImage = encodedImageIn else {
            return
        }

        DPAGLog("path \(path)")

        do {
            try encodedImage.write(to: path, atomically: true, encoding: .utf8)

            DPAGUIImageHelper.removeCachedGroupImage(guid: guid)

            var resourceValues = URLResourceValues()

            resourceValues.isExcludedFromBackup = true

            try path.setResourceValues(resourceValues)
        } catch {
            DPAGLog("error: \(error)")
        }
    }

    public class func image(forGroupGuid guid: String) -> UIImage? {
        if let encodedImage = self.encodedImage(forGroupGuid: guid) {
            if let imageData = Data(base64Encoded: encodedImage, options: .ignoreUnknownCharacters) {
                return UIImage(data: imageData)
            }
        }
        return nil
    }

    class func imageExists(forGroupGuid guid: String) -> Bool {
        if let path = self.imageFilePath(forGroupGuid: guid) {
            return FileManager.default.fileExists(atPath: path.path)
        }
        return false
    }

//    private class func encodedImage(forGroupGuid guid: String, compression compressionQuality: CGFloat) -> String?
//    {
//        if let originalImage = self.image(forGroupGuid: guid), let originalCGImage = originalImage.cgImage
//        {
//            let scaledImage =
//                UIImage(cgImage: originalCGImage, scale: (originalImage.scale * min(originalImage.size.width, originalImage.size.height) / 150.0), orientation: (originalImage.imageOrientation))
//
//            let imgData = scaledImage.jpegData(compressionQuality: compressionQuality)
//            let encodedImage = imgData?.base64EncodedString(options: .lineLength64Characters)
//
//            return encodedImage
//        }
//        return nil
//    }

    class func removeEncodedImage(forGroupGuid guid: String) {
        if let path = self.imageFilePath(forGroupGuid: guid) {
            try? FileManager.default.removeItem(at: path)
        }
    }

    @objc
    public class func encodedImage(forGroupGuid guid: String) -> String? {
        if let path = self.imageFilePath(forGroupGuid: guid) {
            if let encodedImage = try? String(contentsOf: path, encoding: .utf8) {
                return encodedImage
            }
        }
        return nil
    }

    class func iv128Bit() -> Data {
        var iv = Data(count: 16)
        let ivCount = iv.count

        let result = iv.withUnsafeMutableBytes {
            // swiftlint:disable force_unwrapping
            SecRandomCopyBytes(kSecRandomDefault, ivCount, $0.bindMemory(to: UInt8.self).baseAddress!)
        }

        if result == errSecSuccess {
            return iv
        } else {
            DPAGLog("Problem generating random bytes")
            return iv
        }
    }

    private class func deleteCachedVideo(videoURL: URL) {
        if let attributes = try? FileManager.default.attributesOfItem(atPath: videoURL.path) {
            if let creationDate = attributes[.creationDate] as? Date {
                let secs = creationDate.timeIntervalSinceNow
                // mehr als 30 Minuten alt --> löschen
                if secs < TimeInterval(-60 * 30) {
                    try? FileManager.default.removeItem(at: videoURL)
                }
            }
        }
    }

    public class func clearInboxFolder() {
        if let inboxPath = DPAGConstantsGlobal.documentsDirectoryURL?.appendingPathComponent("Inbox"), let docDirectory = try? FileManager.default.contentsOfDirectory(atPath: inboxPath.path) {
            for file in docDirectory {
                try? FileManager.default.removeItem(at: inboxPath.appendingPathComponent(file))
            }
        }
    }

    public class func clearTempFolder() {
        if let directoryPath = DPAGFunctionsGlobal.pathForCustomTMPDirectory(), let tmpDirectory = try? FileManager.default.contentsOfDirectory(at: directoryPath, includingPropertiesForKeys: nil, options: FileManager.DirectoryEnumerationOptions()) {
            for file in tmpDirectory {
                // Zugeschnittenes Video...
                let isCapture = (file.pathComponents.last?.hasPrefix("capture") ?? false)
                let isTrim = (file.pathComponents.last?.hasPrefix("trim.") ?? false)
                let isSending = (file.pathComponents.last?.hasPrefix("sendingVideo") ?? false)

                if isTrim || isCapture || isSending {
                    // prüfen ob es schon länger daliegt
                    self.deleteCachedVideo(videoURL: file)
                    continue
                }
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    public class func clearTempFolderFiles(withExtension fileExtension: String) {
        if let directoryPath = DPAGFunctionsGlobal.pathForCustomTMPDirectory(), let tmpDirectory = try? FileManager.default.contentsOfDirectory(at: directoryPath, includingPropertiesForKeys: nil, options: FileManager.DirectoryEnumerationOptions()) {
            for file in tmpDirectory where file.pathExtension == fileExtension {
                try? FileManager.default.removeItem(at: file)
            }
        }
        self.clearCustomTempFolderFiles(withExtension: fileExtension)
    }

    private class func clearCustomTempFolderFiles(withExtension fileExtension: String) {
        if let directoryPath = DPAGFunctionsGlobal.pathForCustomTMPDirectory(), let tmpDirectory = try? FileManager.default.contentsOfDirectory(at: directoryPath, includingPropertiesForKeys: nil, options: FileManager.DirectoryEnumerationOptions()) {
            for file in tmpDirectory where file.pathExtension == fileExtension {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    class func clearDocumentsFolder() {
        if let documentsDirectory = DPAGConstantsGlobal.documentsDirectoryURL, let docDirectory = try? FileManager.default.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil, options: FileManager.DirectoryEnumerationOptions()) {
            for file in docDirectory {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    public class func color(forPlaceholderLetters letters: String) -> UIColor {
        var colorPlaceholder = DPAGColorProvider.ContactNameColor.A

        if letters.isEmpty {
            return colorPlaceholder
        }

        letters.enumerateSubstrings(in: letters.startIndex ..< letters.endIndex, options: String.EnumerationOptions.byComposedCharacterSequences) { substringEnum, _, _, stop in

            guard let substring = substringEnum else { return }

            switch substring {
            case "A", "0", "Α", "А", "Ä", "Á", "Â", "À":
                colorPlaceholder = DPAGColorProvider.ContactNameColor.A
            case "B", "1", "Β", "Б":
                colorPlaceholder = DPAGColorProvider.ContactNameColor.B
            case "C", "2", "Γ", "В", "Ç":
                colorPlaceholder = DPAGColorProvider.ContactNameColor.C
            case "D", "3", "Δ", "Г":
                colorPlaceholder = DPAGColorProvider.ContactNameColor.D
            case "E", "4", "Ε", "Д":
                colorPlaceholder = DPAGColorProvider.ContactNameColor.E
            case "F", "5", "Ζ", "Е":
                colorPlaceholder = DPAGColorProvider.ContactNameColor.F
            case "G", "6", "Η", "Ж":
                colorPlaceholder = DPAGColorProvider.ContactNameColor.G
            case "H", "7", "Θ", "З":
                colorPlaceholder = DPAGColorProvider.ContactNameColor.H
            case "I", "8", "Ι", "И", "İ":
                colorPlaceholder = DPAGColorProvider.ContactNameColor.I
            case "J", "9", "Κ", "Й":
                colorPlaceholder = DPAGColorProvider.ContactNameColor.J
            case "K", "Λ", "К":
                colorPlaceholder = DPAGColorProvider.ContactNameColor.K
            case "L", "Μ", "Л":
                colorPlaceholder = DPAGColorProvider.ContactNameColor.L
            case "M", "Ν", "М":
                colorPlaceholder = DPAGColorProvider.ContactNameColor.M
            case "N", "Ξ", "Н", "Ñ":
                colorPlaceholder = DPAGColorProvider.ContactNameColor.N
            case "O", "Ο", "О", "Ö":
                colorPlaceholder = DPAGColorProvider.ContactNameColor.O
            case "P", "Π", "П":
                colorPlaceholder = DPAGColorProvider.ContactNameColor.P
            case "Q", "Ρ", "Р":
                colorPlaceholder = DPAGColorProvider.ContactNameColor.Q
            case "R", "Σ", "С":
                colorPlaceholder = DPAGColorProvider.ContactNameColor.R
            case "S", "Τ", "Т", "Ş":
                colorPlaceholder = DPAGColorProvider.ContactNameColor.S
            case "T", "Υ", "У":
                colorPlaceholder = DPAGColorProvider.ContactNameColor.T
            case "U", "Φ", "Ф", "Ü":
                colorPlaceholder = DPAGColorProvider.ContactNameColor.U
            case "V", "Χ", "Х":
                colorPlaceholder = DPAGColorProvider.ContactNameColor.V
            case "W", "Ψ", "Ц":
                colorPlaceholder = DPAGColorProvider.ContactNameColor.W
            case "X", "Ω", "Ч":
                colorPlaceholder = DPAGColorProvider.ContactNameColor.X
            case "Y", "Ш":
                colorPlaceholder = DPAGColorProvider.ContactNameColor.Y
            case "Z", "Э":
                colorPlaceholder = DPAGColorProvider.ContactNameColor.Z
            default:
                break
            }
            stop = true
        }

        return colorPlaceholder
    }

    public class func isNetworkReachable() -> Bool {
        switch AFNetworkReachabilityManager.shared().networkReachabilityStatus {
        case .notReachable:
            return false
        case .reachableViaWiFi, .reachableViaWWAN, .unknown:
            return true
        @unknown default:
            DPAGLog("Switch with unknown value: \(AFNetworkReachabilityManager.shared().networkReachabilityStatus.rawValue)", level: .warning)
            return false
        }
    }

    public class func isVideoContentMimeType(_ contentMimeType: String) -> Bool {
        if contentMimeType.hasPrefix("video/") {
            return AVURLAsset.audiovisualMIMETypes().contains(contentMimeType) && AVURLAsset.isPlayableExtendedMIMEType(contentMimeType)
        }
        return false
    }

    public class func isImageContentMimeType(_ contentMimeType: String) -> Bool {
        if contentMimeType.hasPrefix("image/") {
            return true
        }
        return false
    }

    public class func isEmailValid(_ emailIn: String?) -> Bool {
        guard let email = emailIn else {
            return false
        }

        // Old one was @"^[A-Z0-9+.-_]+@[A-Z0-9.-]+.[A-Z]{2,}$"
        let regularExpression = ".+@.+\\.[A-Za-z]{2}[A-Za-z]*"

        let emailTest = NSPredicate(format: "SELF MATCHES %@", regularExpression)

        return emailTest.evaluate(with: email)
    }
}

extension Date {
    private static let timeLabelFormatter: DateFormatter = {
        let formatter = DateFormatter()

        formatter.dateFormat = "HH:mm"

        return formatter
    }()

    private static let dateLabelWithoutYearFormatter: DateFormatter = {
        let formatter = DateFormatter()

        formatter.dateFormat = "dd.MM."

        return formatter
    }()

    private static let timeLabelMediaFormatter: DateFormatter = {
        let formatter = DateFormatter()

        formatter.dateStyle = .short
        formatter.timeStyle = .short

        return formatter
    }()

    private static let timeLabelMediaFileFormatter: DateFormatter = {
        let formatter = DateFormatter()

        formatter.dateStyle = .short
        formatter.timeStyle = .none

        return formatter
    }()

    private static let dateLabelFormatter: DateFormatter = {
        let formatter = DateFormatter()

        formatter.dateStyle = .short

        return formatter
    }()

    public var timeLabel: String {
        Date.timeLabelFormatter.string(from: self)
    }

    public var dateLabel: String {
        Date.dateLabelFormatter.string(from: self)
    }

    public var timeLabelMedia: String {
        Date.timeLabelMediaFormatter.string(from: self)
    }

    public var timeLabelMediaFile: String {
        Date.timeLabelMediaFileFormatter.string(from: self)
    }

    public var dateLabelWithoutYear: String {
        Date.dateLabelWithoutYearFormatter.string(from: self)
    }
}
