//
//  DevicesDAO.swift
//  SIMSmeCore
//
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

typealias DeviceDictionary = [String: [String: Any]]

protocol DevicesDAOProtocol {
    func extensionDeviceDictionary(withAccount account: DPAGAccount, guid: String, passToken: String, sharedSecret: String, publicKey: String?) throws -> DeviceDictionary?

    func ownDeviceDictionary() throws -> DeviceDictionary?
}

class DevicesDAO: DevicesDAOProtocol {
    func extensionDeviceDictionary(withAccount account: DPAGAccount, guid: String, passToken: String, sharedSecret: String, publicKey: String?) throws -> DeviceDictionary? {
        var deviceDictionary: DeviceDictionary?

        try DPAGApplicationFacade.persistance.loadWithError { localContext in
            guard let device = SIMSDevice.mr_createEntity(in: localContext) else { return }

            device.guid = guid
            device.name = UIDevice.current.name
            device.passToken = passToken
            device.account_guid = account.guid
            device.public_key = publicKey
            device.sharedSecret = sharedSecret
            device.publicRSAFingerprint = publicKey?.sha1()
            device.ownDevice = 0

            let signData = try DPAGCryptoHelper.newAccountCrypto()?.signData(data: device.publicRSAFingerprint ?? "")
            device.signedPublicRSAFingerprint = signData

            deviceDictionary = try device.deviceDictionary(type: "extension")

            device.mr_deleteEntity(in: localContext)

            localContext.reset()
        }

        return deviceDictionary
    }

    func ownDeviceDictionary() throws -> DeviceDictionary? {
        var deviceDictionary: DeviceDictionary?

        try DPAGApplicationFacade.persistance.loadWithError { localContext in

            if let device = SIMSDevice.mr_findFirst(with: NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSDevice.ownDevice), rightExpression: NSExpression(forConstantValue: NSNumber(value: 1))), in: localContext) ?? SIMSDevice.mr_findFirst(in: localContext) {
                deviceDictionary = try device.deviceDictionary(type: "permanent")
            }
        }

        return deviceDictionary
    }
}
