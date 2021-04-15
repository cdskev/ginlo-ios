//
//  DPAGDevicesWorker.swift
//  SIMSmeCore
//
//  Created by RBU on 28.11.17.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import UIKit

public enum DPAGErrorDevice: Error {
    case errDatabase
}

public class DPAGDevice {
    public var guid: String?
    public var accountGuid: String?
    public var publicKey: String?
    public var pkSign256: String?
    public var language: String?
    public var appName: String?
    public var appVersion: String?
    public var os: String?
    public var deviceName: String?
    public var deviceType: String?
    public var deviceLastOnline: String?

    public init(deviceDict: [AnyHashable: Any]) {
        self.guid = deviceDict[DPAGStrings.JSON.Device.GUID] as? String
        self.accountGuid = deviceDict[DPAGStrings.JSON.Device.ACCOUNT_GUID] as? String
        self.publicKey = deviceDict[DPAGStrings.JSON.Device.PUBLIC_KEY] as? String
        self.pkSign256 = deviceDict[DPAGStrings.JSON.Device.PK_SIGN] as? String
        self.language = deviceDict[DPAGStrings.JSON.Device.LANGUAGE] as? String
        self.appName = deviceDict[DPAGStrings.JSON.Device.APP_NAME] as? String
        self.appVersion = deviceDict[DPAGStrings.JSON.Device.APP_VERSION] as? String
        self.os = deviceDict[DPAGStrings.JSON.Device.OS_IDENTIFIER] as? String

        if let name = deviceDict[DPAGStrings.JSON.Device.DEVICE_NAME] as? String, name.count > 0 {
            if let deviceNameData = Data(base64Encoded: name, options: Data.Base64DecodingOptions.ignoreUnknownCharacters) {
                self.deviceName = String(data: deviceNameData, encoding: .utf8)
            }
        }

        self.deviceType = deviceDict[DPAGStrings.JSON.Device.DEVICE_TYPE] as? String
        self.deviceLastOnline = deviceDict[DPAGStrings.JSON.Device.LAST_ONLINE] as? String
    }

    public func isTempDevice() -> Bool {
        self.deviceType == "tempDevice"
    }
}

@objc
public protocol DPAGDevicesWorkerProtocol: AnyObject {
    func getDevices(withResponse response: @escaping DPAGServiceResponseBlock)
    func deleteDevice(_ guid: String, withResponse response: @escaping DPAGServiceResponseBlock)
    func renameDevice(_ guid: String, newName: String, withResponse response: @escaping DPAGServiceResponseBlock)
    func createShareExtensionDevice(withResponse response: DPAGServiceResponseBlock?) throws
}

public class DPAGDevicesWorker: DPAGDevicesWorkerProtocol {
    let devicesDAO = DevicesDAO()

    public func createShareExtensionDevice(withResponse response: DPAGServiceResponseBlock?) throws {
        guard let account = DPAGApplicationFacade.cache.account else { return }

        let deviceGuid = DPAGFunctionsGlobal.uuid(prefix: .device)
        let devicePasstoken = DPAGFunctionsGlobal.uuid()
        let deviceSharedSecret = DPAGFunctionsGlobal.uuid()
        let devicePublicKey = try CryptoHelper.sharedInstance?.getPublicKeyFromPrivateKey()

        let deviceDict = try devicesDAO.extensionDeviceDictionary(withAccount: account,
                                                                  guid: deviceGuid,
                                                                  passToken: devicePasstoken,
                                                                  sharedSecret: deviceSharedSecret,
                                                                  publicKey: devicePublicKey)

        if let deviceDict = deviceDict, let deviceJSON = deviceDict.JSONString {
            DPAGApplicationFacade.server.createShareExtensionDevice(accountGuid: account.guid, device: deviceJSON) { _, errorCode, errorMessage in

                if let errorMessage = errorMessage {
                    response?(nil, errorCode, errorMessage)
                    return
                }

                DPAGApplicationFacade.preferences.isShareExtensionEnabled = true

                DPAGApplicationFacade.preferences.shareExtensionDeviceGuid = deviceGuid
                DPAGApplicationFacade.preferences.shareExtensionDevicePasstoken = devicePasstoken

                response?(nil, nil, nil)
            }
        } else {
            throw DPAGErrorDevice.errDatabase
        }
    }

    public func getDevices(withResponse response: @escaping DPAGServiceResponseBlock) {
        DPAGApplicationFacade.server.getDevices(withResponse: response)
    }

    public func deleteDevice(_ guid: String, withResponse response: @escaping DPAGServiceResponseBlock) {
        DPAGApplicationFacade.server.deleteDevice(guid: guid, withResponse: response)
    }

    public func renameDevice(_ guid: String, newName: String, withResponse response: @escaping DPAGServiceResponseBlock) {
        DPAGApplicationFacade.server.renameDevice(guid: guid, newName: newName, withResponse: response)
    }
}
