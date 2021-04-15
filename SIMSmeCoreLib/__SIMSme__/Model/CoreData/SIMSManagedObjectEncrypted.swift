//
//  SIMSManagedObjectEncrypted.swift
//  SIMSme
//
//  Created by RBU on 19/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import UIKit

class SIMSManagedObjectEncrypted: SIMSManagedObject {
    @NSManaged var checksumRelationship: SIMSChecksum?
    @NSManaged var keyRelationship: SIMSKey?
    @NSManaged var attribute: String?

    var attrDictInternal: [String: Any]?

    var attrDictBefore: [String: Any]?
    // var attrDictChanged: [String: Any]?

    var attributesBefore: String?

    func beforeSave() throws {
        if !self.isDeleted {
            try self.encryptAttributes()
        }
    }

    func attrDict() -> [String: Any]? {
        // save on different threads changes the encrypted attributes only
        if self.attrDictInternal != nil, (self.attribute == nil && self.attributesBefore == nil) || self.attribute == self.attributesBefore {
            return self.attrDictInternal
        }

        guard let attribute = self.attribute else {
            self.attrDictInternal = [:]
            return self.attrDictInternal
        }

        guard CryptoHelper.sharedInstance?.isPrivateKeyInMemory() ?? false else {
            return nil
        }

        self.attributesBefore = self.attribute
        if let savedInstance = DPAGApplicationFacade.cache.getDecryptedDict(attribute) {
            self.attrDictInternal = savedInstance
            self.attrDictBefore = savedInstance
            return self.attrDictInternal
        }

        DPAGLog("Decrypt AttrDict for obj:%@", self.guid ?? "<unknown")

        if attribute.isEmpty == false, let key = self.keyRelationship {
            let jsonString = CryptoHelper.sharedInstance?.decryptToStringNoFault(encryptedString: attribute, with: key)

            var dictForJson: [String: Any]?

            do {
                if let data = jsonString?.data(using: .utf8) {
                    dictForJson = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any]
                }
            } catch {
                DPAGLog(error)
            }

            if let dictForJson = dictForJson {
                self.attrDictInternal = dictForJson
                self.attrDictBefore = self.attrDictInternal
                DPAGApplicationFacade.cache.setDecryptedDict(attribute, dict: dictForJson)
                // self.attrDictChanged = nil
            } else {
                self.attrDictInternal = nil
            }
        } else {
            self.attrDictInternal = [:]
        }

        return self.attrDictInternal
    }

    func setAttributeWithKey(_ key: String, andValue value: Any) {
        if self.attrDict() == nil {
            return
        }

        self.attrDictInternal?[key] = value
        self.changed(self.attribute)
    }

    func encryptAttributes() throws {
        if self.attrDict() != nil {
            if let encryptAttr = try self.getEncryptedAttributes() {
                self.attribute = encryptAttr
                self.attrDictInternal = nil
            }
        }
    }

    func getAttribute(_ key: String) -> Any? {
        if self.attrDict() == nil {
            return nil
        }
        return self.attrDict()?[key]
    }

    func getAttributeKeys() -> [String]? {
        guard let attrDict = self.attrDict() else {
            return nil
        }
        return Array(attrDict.keys)
    }

    func removeAttribute(_ key: String) {
        if self.attrDict() == nil {
            return
        }
        _ = self.attrDictInternal?.removeValue(forKey: key)
        self.changed(self.attribute)
    }

    func getEncryptedAttributes() throws -> String? {
        if !self.hasChanges {
            return self.attribute
        }

        guard let attrDict = self.attrDict() else {
            return self.attribute
        }

        if attrDict.count == 0 {
            return nil
        }

        guard let attrString = attrDict.JSONString, attrString.isEmpty == false, let key = self.keyRelationship else {
            return nil
        }

        // self.attrDictChanged = self.createCurrentChangedAttributesDict()

        // TODO: Schlüssel auf aktualität prüfen vor dem verschlüsseln, eventuell neuen holen und speichern
        return try CryptoHelper.sharedInstance?.encrypt(string: attrString, with: key)
    }

    /*
     func createCurrentChangedAttributesDict() -> [String: Any]?
     {
     var attrDictChanged = [String: Any]()

     if self.attrDictBefore != nil && self.attrDict() != nil
     {
     for keyDict in self.attrDictBefore!.keys
     {
     if (self.attrDictBefore![keyDict] != self.attrDict()![keyDict])
     {
     attrDictChanged[keyDict] = self.attrDict()![keyDict]
     }
     }
     for keyDict in self.attrDict()!.keys
     {
     if (self.attrDict()![keyDict] != self.attrDictBefore![keyDict])
     {
     attrDictChanged[keyDict] = self.attrDict()![keyDict]
     }
     }
     }
     return attrDictChanged
     }
     */
    func changed(_ attrNew: String?) {
        // only by using the setter the context notifies a change
        self.attribute = attrNew
    }
}
