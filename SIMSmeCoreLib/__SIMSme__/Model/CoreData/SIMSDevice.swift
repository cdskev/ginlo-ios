//
//  SIMSDevice.swift
//  SIMSme
//
//  Created by RBU on 19/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import Foundation

class SIMSDevice: SIMSManagedObjectEncrypted {
    @NSManaged var account_guid: String?
    @NSManaged var key_guid: String?
    @NSManaged var ownDevice: NSNumber?
    @NSManaged var pass_token: String?
    @NSManaged var public_key: String?
    @NSManaged var additionalData: String?

    // Insert code here to add functionality to your managed object subclass

    private static let NAME = "name"
    private static let PASS_TOKEN = "passToken"
    private static let SHARED_SECRET = "sharedSecret"
    private static let PUB_RSA_FINGERPRINT = "pubRsaFingerprint"
    private static let SIGNED_PUB_RSA_FINGERPRINT = "signedPubRsaFingerprint"

    @objc
    public class func entityName() -> String {
        DPAGStrings.CoreData.Entities.DEVICE
    }

    var name: String? {
        get {
            let aName = self.getAttribute(SIMSDevice.NAME) as? String

            return aName
        }
        set {
            if let aName = newValue {
                self.setAttributeWithKey(SIMSDevice.NAME, andValue: aName)
            }
        }
    }

    var passToken: String? {
        get {
            let aPassToken = self.getAttribute(SIMSDevice.PASS_TOKEN) as? String

            return aPassToken
        }
        set {
            if let aPassToken = newValue {
                self.setAttributeWithKey(SIMSDevice.PASS_TOKEN, andValue: aPassToken)
            }
        }
    }

    var sharedSecret: String? {
        get {
            let aSharedSecret = self.getAttribute(SIMSDevice.SHARED_SECRET) as? String

            return aSharedSecret
        }
        set {
            if let aSharedSecret = newValue {
                self.setAttributeWithKey(SIMSDevice.SHARED_SECRET, andValue: aSharedSecret)
            }
        }
    }

    var publicRSAFingerprint: String? {
        get {
            let aPublicRSAFingerprint = self.getAttribute(SIMSDevice.PUB_RSA_FINGERPRINT) as? String

            return aPublicRSAFingerprint
        }
        set {
            if let aPublicRSAFingerprint = newValue {
                self.setAttributeWithKey(SIMSDevice.PUB_RSA_FINGERPRINT, andValue: aPublicRSAFingerprint)
            }
        }
    }

    var signedPublicRSAFingerprint: String? {
        get {
            let aSignedPublicRSAFingerprint = self.getAttribute(SIMSDevice.SIGNED_PUB_RSA_FINGERPRINT) as? String

            return aSignedPublicRSAFingerprint
        }
        set {
            if let aSignedPublicRSAFingerprint = newValue {
                self.setAttributeWithKey(SIMSDevice.SIGNED_PUB_RSA_FINGERPRINT, andValue: aSignedPublicRSAFingerprint)
            }
        }
    }

    func deviceDictionary(type: String) throws -> [String: [String: Any]] {
        if self.keyRelationship == nil && type != "extension" {
            return [:]
        }

        let model = DPAGApplicationFacade.model

        let signData = self.signedPublicRSAFingerprint ?? ""

        let deviceToken = DPAGApplicationFacade.preferences.deviceToken
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "SIMSme-noIdent"
        let apnIdentifier: String
        let passToken = self.passToken ?? ""

        if deviceToken == DPAGStrings.Notification.Push.TOKEN_POSTPONED.rawValue || deviceToken == DPAGStrings.Notification.Push.TOKEN_FAILED.rawValue {
            apnIdentifier = ""
        } else if let deviceToken = deviceToken, type != "extension" {
            apnIdentifier = DPAGApplicationFacade.preferences.apnIdentifierWithBundleIdentifier(bundleIdentifier, deviceToken: deviceToken)
        } else {
            apnIdentifier = ""
        }

        DPAGLog("apnIdentifier   %@", apnIdentifier)

        var features: [String] = []

        features.append("\(DPAGMessageFeatureVersion.voiceRec.rawValue)")
        features.append("\(DPAGMessageFeatureVersion.publicProfile.rawValue)")
        features.append("\(DPAGMessageFeatureVersion.file.rawValue)")
        features.append("\(DPAGMessageFeatureVersion.pushWithParameter.rawValue)")
        features.append("\(DPAGMessageFeatureVersion.confirmGroupMessages.rawValue)")
        features.append("\(DPAGMessageFeatureVersion.managedRestrictedGroupInvPush.rawValue)")

        features.append("\(DPAGMessageFeatureVersion.tempDeviceSupport.rawValue)")
        features.append("\(DPAGMessageFeatureVersion.oooStatusMessages.rawValue)")
        features.append("\(DPAGMessageFeatureVersion.textRSS.rawValue)")

        if DPAGApplicationFacade.preferences.supportMultiDevice {
            features.append("\(DPAGMessageFeatureVersion.multiDeviceSupport.rawValue)")
        }

        if ProcessInfo.processInfo.arguments.contains("UITestWithDisabledSystemInfo") {
            features.append("\(DPAGMessageFeatureVersion.disabledSystemInfo.rawValue)")
        }

        let deviceGuid = self.guid ?? ""
        let accountGuid = self.account_guid ?? ""
        let publicKey = self.public_key ?? ""
        let language = model.language ?? ""
        let appName = model.appName ?? ""
        let appVersion = model.appVersion ?? ""
        let keyGuid = self.keyRelationship?.guid ?? ""
        let attributes = type != "extension" ? (try self.getEncryptedAttributes() ?? "") : ""
        let trackingGuid = DPAGApplicationFacade.preferences.deviceTrackingGuid

        let osName = DPAGApplicationFacade.accountManager.getOsName()

        let deviceDict: [String: [String: Any]] = [
            DPAGStrings.JSON.Device.OBJECT_KEY: [
                DPAGStrings.JSON.Device.GUID: deviceGuid,
                DPAGStrings.JSON.Device.ACCOUNT_GUID: accountGuid,
                DPAGStrings.JSON.Device.PUBLIC_KEY: publicKey,
                DPAGStrings.JSON.Device.PK_SIGN: signData,
                DPAGStrings.JSON.Device.PASSTOKEN: passToken,
                DPAGStrings.JSON.Device.LANGUAGE: language,
                DPAGStrings.JSON.Device.APN_IDENTIFIER: apnIdentifier,
                DPAGStrings.JSON.Device.APP_NAME: appName,
                DPAGStrings.JSON.Device.APP_VERSION: appVersion,
                DPAGStrings.JSON.Device.OS_IDENTIFIER: osName,
                DPAGStrings.JSON.Device.KEY_GUID: keyGuid,
                DPAGStrings.JSON.Device.DATA: attributes,
                DPAGStrings.JSON.Device.FEATURES: features,
                DPAGStrings.JSON.Device.TRACKING_GUID: trackingGuid,
                DPAGStrings.JSON.Device.DEVICE_TYPE: type
            ]
        ]

        return deviceDict
    }
}
