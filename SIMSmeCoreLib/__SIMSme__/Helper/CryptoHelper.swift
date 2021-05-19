//
//  CryptoHelper.swift
//  SIMSmeCore
//
//  Created by Robert Burchert on 13.10.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CommonCrypto
import JFBCrypt

struct DPAGEncryptionGCM {
    let key: String
    let iv: String
    let aad: String
    let authTag: String
    let encryptedString: String
}

public enum DPAGErrorCrypto: Error {
    case errCko
    case errFileDoesNotExists(String)
    case errData
    case errGenerateKey(String)
    case errEncryption(String)
    case errKeychain
    case errEncoding(String)
    case errCrypt
    case errSIMSKey

    var localizedDescription: String {
        switch self {
            case let .errEncryption(errorMessage):
                return errorMessage
            case let .errGenerateKey(errorMessage):
                return errorMessage
            case let .errEncoding(errorMessage):
                return errorMessage
            case let .errFileDoesNotExists(errorMessage):
                return errorMessage
            case .errCko:
                return "errCko"
            case .errData:
                return "errData"
            case .errKeychain:
                return "errKeychain"
            case .errCrypt:
                return "errCrypt"
            case .errSIMSKey:
                return "errSIMSKey"
        }
    }
}

extension CkoCrypt2 {
    static func cryptDefault() throws -> CkoCrypt2 {
        guard let decryptCrypt = CkoCrypt2() else {
            throw DPAGErrorCrypto.errCko
        }
        if decryptCrypt.isUnlocked() == false {
            decryptCrypt.unlockCryptComponent()
        }
        decryptCrypt.cryptAlgorithm = "aes"
        decryptCrypt.cipherMode = "cbc"
        decryptCrypt.charset = "utf-8"
        decryptCrypt.keyLength = NSNumber(value: 256)
        return decryptCrypt
    }

    fileprivate static func crypt(hashAlgorithm: String?, cryptAlgorithm: String?, encodingMode: String) -> CkoCrypt2? {
        if let crypt = CkoCrypt2() {
            crypt.unlockCryptComponent()
            if let hashAlgorithm = hashAlgorithm {
                crypt.hashAlgorithm = hashAlgorithm
            }
            if let cryptAlgorithm = cryptAlgorithm {
                crypt.cryptAlgorithm = cryptAlgorithm
            }
            crypt.encodingMode = encodingMode

            return crypt
        }
        return nil
    }

    func unlockCryptComponent() {
        try? DPAGFunctionsGlobal.unlockChilkat(AppConfig.chilkatLicense)
    }
}

extension CkoRsa {
    fileprivate static func cryptRsa(encodingMode: String = "base64", littleEndian: Bool = false, charset: String = "utf-8", oaepPadding: Bool = true) throws -> CkoRsa {
        guard let crypt = CkoRsa() else {
            throw DPAGErrorCrypto.errCko
        }
        crypt.unlockRsaComponent()
        crypt.encodingMode = encodingMode
        crypt.littleEndian = littleEndian
        crypt.charset = charset
        crypt.oaepPadding = oaepPadding
        return crypt
    }

    func unlockRsaComponent()  {
        try? DPAGFunctionsGlobal.unlockChilkat(AppConfig.chilkatLicense)
    }

    func importPrivateKey(privateKey: String) throws {
        if self.importPrivateKey(privateKey) == false {
            DPAGLog("Chilkat Lib cannot import private key!")
            throw DPAGErrorCrypto.errCko
        }
    }

    func importPublicKey(publicKey: String) throws {
        if self.importPublicKey(publicKey) == false {
            DPAGLog("Chilkat Lib cannot import public key!")
            throw DPAGErrorCrypto.errCko
        }
    }
}

public struct CryptoHelperGenerator {
    private init() {}

    static func decodeTicketTan(tan: String) throws -> Data {
        let temp = tan.replacingOccurrences(of: "O", with: "0").replacingOccurrences(of: "I", with: "1").replacingOccurrences(of: "l", with: "1")
        let rawData = try CryptoHelperCoding.shared.decodeBase64(data: temp)
        let rawDataHash = try CryptoHelperCoding.shared.sha384Hash(data: rawData)
        return rawDataHash
    }

    static func generateTicketPassword(tan: String) throws -> String? {
        let rawData = try self.decodeTicketTan(tan: tan)
        var retVal: String?
        try rawData.withUnsafeBytes { body in
            guard let bytes = body.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return
            }
            let key = Data(bytes: bytes + 128 / 8, count: 128 / 8)
            let iv = Data(bytes: bytes + 256 / 8, count: 128 / 8)
            if let ivEncoded = JFBCrypt.encode(iv, ofLength: Int32(iv.count)) {
                let password = try CryptoHelperCoding.shared.encodeBase64(data: key)
                let salt = String(format: "%@%@", "$2a$10$", ivEncoded)
                if let rc = JFBCrypt.hashPassword(password, withSalt: salt) {
                    retVal = String(rc[rc.index(rc.startIndex, offsetBy: salt.count)...])
                }
            }
        }
        return retVal
    }

    static func generateTransId(tan: String, publicKey pk: String, account accountGuid: String) throws -> String? {
        let fingerPrint = try CryptoHelperCoding.shared.shaHash(value: pk)
        let concat = String(format: "%@%@", tan, fingerPrint)
        let key1 = try CryptoHelperCoding.shared.shaHash(value: concat)
        let ivData = try CryptoHelperCoding.shared.decodeHex(data: try CryptoHelperCoding.shared.shaHash(value: accountGuid))
        let salt = String(format: "$2a$04$%@", JFBCrypt.encode(ivData, ofLength: Int32(ivData.count)))
        let rc = JFBCrypt.hashPassword(key1, withSalt: salt)
        return rc
    }

    public static func createTicketTan() throws -> String {
        guard let temp = CryptoHelperCoding.shared.base64Encoder?.genRandomBytesENC(NSNumber(value: 144 / 8)) else {
            throw DPAGErrorCrypto.errEncoding(CryptoHelperCoding.shared.base64Encoder?.lastErrorText ?? "no encoder")
        }
        let validChars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz0123456789"
        let cs = CharacterSet(charactersIn: validChars).inverted
        var rc = temp
        while let range = rc.rangeOfCharacter(from: cs) {
            rc = rc.replacingCharacters(in: range, with: String(validChars[validChars.index(validChars.startIndex, offsetBy: Int(arc4random_uniform(UInt32(validChars.count))))]))
        }
        return rc
    }
}

public struct CryptoHelperVerifier {
    private init() {}

    static func verifyData(data: String?, withSignature signature: String?, forPublicKey pubKey: String?) throws -> Bool {
        try self.verifyData(data: data, withSignature: signature, forPublicKey: pubKey, hashAlg: "sha-1")
    }

    public static func verifyData256(data: String?, withSignature signature: String?, forPublicKey pubKey: String?) throws -> Bool {
        try self.verifyData(data: data, withSignature: signature, forPublicKey: pubKey, hashAlg: "sha-256")
    }

    static func verifyDataRaw256(data: String?, withSignature signature: String?, forPublicKey pubKey: String?) throws -> Bool {
        try self.verifyData(data: data, withSignature: signature, forPublicKey: pubKey, hashAlg: "sha-256", raw: true)
    }

    private static func verifyData(data: String?, withSignature signature: String?, forPublicKey pubKey: String?, hashAlg: String, raw: Bool = false) throws -> Bool {
        guard let data = data, let signature = signature, let pubKey = pubKey else { return false }
        let verifyData = try CkoRsa.cryptRsa()
        verifyData.importPublicKey(pubKey)
        if raw {
            let rawData = Data(base64Encoded: data, options: .ignoreUnknownCharacters)
            let sigData = Data(base64Encoded: signature, options: .ignoreUnknownCharacters)
            let rc1 = verifyData.verifyBytes(rawData, hashAlg: hashAlg, sigData: sigData)
            return rc1
        } else {
            let sigData = Data(base64Encoded: signature, options: .ignoreUnknownCharacters)
            let rc1 = verifyData.verifyBytes(data.data(using: .utf8), hashAlg: hashAlg, sigData: sigData)
            return rc1
        }
    }
}

struct CryptoHelperDecrypter {
    private init() {}
    
    static func decrypt(encryptedString: String, withAesKey decAesKeyXML: String) throws -> Data? {
        guard let decAesKeyDict = try XMLReader.dictionary(forXMLString: decAesKeyXML) else {
            return nil
        }
        return try self.decrypt(encryptedString: encryptedString, withAesKeyDict: decAesKeyDict)
    }

    static func decrypt(encryptedData: Data, withAesKey decAesKeyXML: String) throws -> Data? {
        guard let decAesKeyDict = try XMLReader.dictionary(forXMLString: decAesKeyXML) else {
            return nil
        }
        return try self.decrypt(encryptedData: encryptedData, withAesKeyDict: decAesKeyDict)
    }

    static func decrypt(encryptedData: Data, withAesKeyDict dict: [AnyHashable: Any]) throws -> Data {
        guard dict.isEmpty == false, encryptedData.isEmpty == false else {
            throw DPAGErrorCrypto.errEncryption("dict == nil || encryptedData == nil")
        }
        let decryptCrypt = try CkoCrypt2.cryptDefault()
        if let key = dict["key"] as? String {
            decryptCrypt.setEncodedKey(key, encoding: "base64")
        }
        if let iv = dict["iv"] as? String {
            decryptCrypt.setEncodedIV(iv, encoding: "base64")
        }
        guard let decryptedData = decryptCrypt.decryptBytes(encryptedData), decryptedData.isEmpty == false else {
            throw DPAGErrorCrypto.errEncryption("Fehler beim Entschlüsseln eines Strings." + decryptCrypt.lastErrorText)
        }
        return decryptedData
    }

    static func decrypt(encryptedString: String, withAesKeyDict dict: [AnyHashable: Any]) throws -> Data {
        guard dict.isEmpty == false, encryptedString.isEmpty == false else {
            throw DPAGErrorCrypto.errEncryption("dict == nil || encryptedString == nil")
        }
        let decryptCrypt = try CkoCrypt2.cryptDefault()
        if let key = dict["key"] as? String {
            decryptCrypt.setEncodedKey(key, encoding: "base64")
        }
        if let iv = dict["iv"] as? String {
            decryptCrypt.setEncodedIV(iv, encoding: "base64")
        }
        return decryptCrypt.decryptBytesENC(encryptedString)
    }

    static func decryptToString(encryptedString: String, withAesKeyDict dict: [AnyHashable: Any]) throws -> String {
        let decryptedData = try self.decrypt(encryptedString: encryptedString, withAesKeyDict: dict)

        guard let decryptedString = String(data: decryptedData, encoding: .utf8), decryptedString.isEmpty == false else {
            throw DPAGErrorCrypto.errEncryption("Fehler beim Entschlüsseln eines Strings.")
        }
        return decryptedString
    }

    static func decryptToString(encryptedString: String, withAesKey decAesKeyXML: String) throws -> String? {
        guard let decAesKeyDict = try XMLReader.dictionary(forXMLString: decAesKeyXML) else {
            return nil
        }
        return try self.decryptToString(encryptedString: encryptedString, withAesKeyDict: decAesKeyDict)
    }

    static func decryptGCM(encryptedString: String, withAesKeyDict dict: [AnyHashable: Any]) throws -> String {
        guard dict.count >= 4, encryptedString.isEmpty == false else {
            throw DPAGErrorCrypto.errEncryption("dict.count < 4 || encryptedString == nil")
        }
        let encryptCrypt = try CkoCrypt2.cryptDefault()
        encryptCrypt.cipherMode = "GCM"
        guard let key = dict["key"] as? String, let iv = dict["iv"] as? String, let aad = dict["aad"] as? String, let authTag = dict["authTag"] as? String else {
            throw DPAGErrorCrypto.errEncryption("dict content missing")
        }
        encryptCrypt.setEncodedKey(key, encoding: "base64")
        encryptCrypt.setEncodedIV(iv, encoding: "base64")
        encryptCrypt.setEncodedAad(aad, encoding: "base64")
        encryptCrypt.setEncodedAuthTag(authTag, encoding: "base64")
        guard let decryptedString = encryptCrypt.decryptStringENC(encryptedString), decryptedString.isEmpty == false else {
            throw DPAGErrorCrypto.errEncryption("Fehler beim Entschlüsseln eines Strings. " + encryptCrypt.lastErrorText)
        }
        return decryptedString
    }

    static func decryptFromBackup(encryptedData: Data, withAesKey aesKey: Data) throws -> Data {
        let encryptCrypt = try CkoCrypt2.cryptDefault()
        encryptCrypt.secretKey = aesKey
        let iv = encryptedData[0 ..< 16].base64EncodedString(options: .lineLength64Characters)
        encryptCrypt.setEncodedIV(iv, encoding: "base64")
        guard let data = encryptCrypt.decryptBytes(encryptedData[16...]) else {
            throw DPAGErrorCrypto.errEncryption(encryptCrypt.lastErrorText)
        }
        return data
    }

    static func decrypt(encryptedData: String, withAesKey aesKey: Data, andIv iv: String) throws -> Data {
        let encryptCrypt = try CkoCrypt2.cryptDefault()
        encryptCrypt.secretKey = aesKey
        encryptCrypt.setEncodedIV(iv, encoding: "base64")
        guard let data = encryptCrypt.decryptBytes(try CryptoHelperCoding.shared.decodeBase64(data: encryptedData)) else {
            throw DPAGErrorCrypto.errEncryption(encryptCrypt.lastErrorText)
        }
        return data
    }

    static func decryptCompanyEncryptedString(encryptedString: String, iv: String, aesKey: String) throws -> String {
        let decCrypt = try CkoCrypt2.cryptDefault()
        decCrypt.setEncodedKey(aesKey, encoding: "base64")
        decCrypt.setEncodedIV(iv, encoding: "base64")
        guard let retVal = decCrypt.decryptStringENC(encryptedString) else {
            throw DPAGErrorCrypto.errEncryption(decCrypt.lastErrorText)
        }
        return retVal
    }
}

public struct CryptoHelperEncrypter {
    private init() {}
    static func getNewAesKey() throws -> String {
        guard let ckoCrypt = CkoCrypt2.crypt(hashAlgorithm: nil, cryptAlgorithm: nil, encodingMode: "base64") else {
            throw DPAGErrorCrypto.errCko
        }
        let randomKey = ckoCrypt.genRandomBytesENC(NSNumber(value: 32))
        let iv = ckoCrypt.genRandomBytesENC(NSNumber(value: 16))
        var keyAttr: [String: String] = [:]
        keyAttr["key"] = randomKey
        keyAttr["iv"] = iv
        keyAttr["timestamp"] = CryptoHelper.newDateInDLFormat()
        let aesKeyDecrypted = XMLWriter.xmlString(from: keyAttr)
        return aesKeyDecrypted
    }

    static func getNewSalt() throws -> String {
        guard let ckoCrypt = CkoCrypt2.crypt(hashAlgorithm: nil, cryptAlgorithm: nil, encodingMode: "base64") else {
            throw DPAGErrorCrypto.errCko
        }
        guard let randomKey = ckoCrypt.genRandomBytesENC(NSNumber(value: 32)) else {
            throw DPAGErrorCrypto.errEncryption(ckoCrypt.lastErrorText)
        }
        return randomKey
    }

    public static func getNewRawAesKey() throws -> String {
        guard let ckoCrypt = CkoCrypt2.crypt(hashAlgorithm: nil, cryptAlgorithm: nil, encodingMode: "base64") else {
            throw DPAGErrorCrypto.errCko
        }
        guard let randomKey = ckoCrypt.genRandomBytesENC(NSNumber(value: 32)) else {
            throw DPAGErrorCrypto.errEncryption(ckoCrypt.lastErrorText)
        }
        return randomKey
    }

    static func getNewRawIV() throws -> String {
        guard let ckoCrypt = CkoCrypt2.crypt(hashAlgorithm: nil, cryptAlgorithm: nil, encodingMode: "base64") else {
            throw DPAGErrorCrypto.errCko
        }
        guard let randomKey = ckoCrypt.genRandomBytesENC(NSNumber(value: 16)) else {
            throw DPAGErrorCrypto.errEncryption(ckoCrypt.lastErrorText)
        }
        return randomKey
    }

    static func encrypt(string: String, withAesKeyDict dict: [AnyHashable: Any]) throws -> String {
        guard dict.isEmpty == false, string.isEmpty == false else {
            throw DPAGErrorCrypto.errEncryption("tan == nil || string == nil")
        }
        let encryptCrypt = try CkoCrypt2.cryptDefault()
        if let key = dict["key"] as? String {
            encryptCrypt.setEncodedKey(key, encoding: "base64")
        }
        if let iv = dict["iv"] as? String {
            encryptCrypt.setEncodedIV(iv, encoding: "base64")
        }
        guard let encryptedString = encryptCrypt.encryptStringENC(string), encryptedString.isEmpty == false else {
            throw DPAGErrorCrypto.errEncryption("Fehler beim Verschlüsseln eines Strings. " + encryptCrypt.lastErrorText)
        }
        return encryptedString
    }

    static func encryptGCM(string: String) throws -> DPAGEncryptionGCM {
        guard string.isEmpty == false else {
            throw DPAGErrorCrypto.errEncryption("decryptedString == nil")
        }
        let encryptCrypt = try CkoCrypt2.cryptDefault()
        encryptCrypt.cipherMode = "GCM"
        guard let ckoCrypt = CkoCrypt2.crypt(hashAlgorithm: nil, cryptAlgorithm: nil, encodingMode: "base64") else {
            throw DPAGErrorCrypto.errCko
        }
        guard let randomKey = ckoCrypt.genRandomBytesENC(NSNumber(value: 32)) else {
            throw DPAGErrorCrypto.errEncryption(ckoCrypt.lastErrorText)
        }
        guard let iv = ckoCrypt.genRandomBytesENC(NSNumber(value: 16)) else {
            throw DPAGErrorCrypto.errEncryption(ckoCrypt.lastErrorText)
        }
        guard let aad = ckoCrypt.genRandomBytesENC(NSNumber(value: 16)) else {
            throw DPAGErrorCrypto.errEncryption(ckoCrypt.lastErrorText)
        }
        encryptCrypt.setEncodedKey(randomKey, encoding: "base64")
        encryptCrypt.setEncodedIV(iv, encoding: "base64")
        encryptCrypt.setEncodedAad(aad, encoding: "base64")
        guard let encryptedString = encryptCrypt.encryptStringENC(string), encryptedString.isEmpty == false else {
            throw DPAGErrorCrypto.errEncryption("Fehler beim Verschlüsseln eines Strings. " + encryptCrypt.lastErrorText)
        }
        guard let authTag = encryptCrypt.getEncodedAuthTag("base64") else {
            throw DPAGErrorCrypto.errEncryption(encryptCrypt.lastErrorText)
        }
        return DPAGEncryptionGCM(key: randomKey, iv: iv, aad: aad, authTag: authTag, encryptedString: encryptedString)
    }

    // TODO: Fix it here ATT-SIZE
    static func encrypt(data: Data, withAesKeyDict dict: [AnyHashable: Any]) throws -> String {
        var returnString: String?
        try autoreleasepool {
            guard dict.isEmpty == false, data.isEmpty == false else {
                throw DPAGErrorCrypto.errEncryption("dict.isEmpty || data.isEmpty")
            }
            guard let key = dict["key"] as? String, let iv = dict["iv"] as? String else {
                throw DPAGErrorCrypto.errEncryption("dict content missing")
            }
            let encryptCrypt = try CkoCrypt2.cryptDefault()
            encryptCrypt.setEncodedKey(key, encoding: "base64")
            encryptCrypt.setEncodedIV(iv, encoding: "base64")
            guard let encryptedString = encryptCrypt.encryptBytesENC(data), encryptedString.isEmpty == false else {
                throw DPAGErrorCrypto.errEncryption("Fehler beim Entschlüsseln eines Strings. " + encryptCrypt.lastErrorText)
            }
            returnString = encryptedString
        }
        if let returnString = returnString {
            return returnString
        } else {
            throw DPAGErrorCrypto.errEncryption("Fehler beim Entschlüsseln eines Strings. ")
        }
    }

    static func encryptForBackup(data: Data, withAesKey aesKey: Data) throws -> Data {
        let encryptCrypt = try CkoCrypt2.cryptDefault()
        encryptCrypt.secretKey = aesKey
        guard let iv = encryptCrypt.genRandomBytesENC(NSNumber(value: 16)) else {
            throw DPAGErrorCrypto.errEncryption(encryptCrypt.lastErrorText)
        }
        encryptCrypt.setEncodedIV(iv, encoding: "base64")
        guard let data = encryptCrypt.encryptBytes(data) else {
            throw DPAGErrorCrypto.errEncryption(encryptCrypt.lastErrorText)
        }
        guard let dataIV = Data(base64Encoded: iv, options: .ignoreUnknownCharacters) else {
            throw DPAGErrorCrypto.errCko
        }
        var rc = Data()
        rc.append(dataIV)
        rc.append(data)
        return rc
    }

    static func encrypt(string: String, withAesKey decAesKeyXML: String) throws -> String? {
        guard let decAesKeyDict = try XMLReader.dictionary(forXMLString: decAesKeyXML) else { return nil }
        return try CryptoHelperEncrypter.encrypt(string: string, withAesKeyDict: decAesKeyDict)
    }

    static func encrypt(data: Data, withAesKey decAesKeyXML: String) throws -> String? {
        guard let decAesKeyDict = try XMLReader.dictionary(forXMLString: decAesKeyXML) else { return nil }
        return try self.encrypt(data: data, withAesKeyDict: decAesKeyDict)
    }

    static func encryptForJson(data: Data, withAesKey aesKey: Data) throws -> [AnyHashable: Any] {
        let encryptCrypt = try CkoCrypt2.cryptDefault()
        encryptCrypt.secretKey = aesKey
        let iv = encryptCrypt.genRandomBytesENC(NSNumber(value: 16))
        encryptCrypt.setEncodedIV(iv, encoding: "base64")
        guard let dataEncrypted = encryptCrypt.encryptBytes(data) else {
            throw DPAGErrorCrypto.errEncryption(encryptCrypt.lastErrorText)
        }
        var rc: [AnyHashable: Any] = [:]
        rc["key-iv"] = iv
        rc["data"] = try CryptoHelperCoding.shared.encodeBase64(data: dataEncrypted)
        return rc
    }

    static func encyptAdressData(decryptedData: String, withToken token: String) throws -> [AnyHashable: Any] {
        guard let tokenData = token.data(using: .utf8) else {
            throw DPAGErrorCrypto.errData
        }
        let salt = try self.getNewRawIV()
        guard let saltData = Data(base64Encoded: salt, options: .ignoreUnknownCharacters) else {
            throw DPAGErrorCrypto.errData
        }
        let aesKeyData = try CryptoHelper.pbkdfKey(passwordData: tokenData, salt: saltData, rounds: CryptoHelper.ROUNDS_ADMIN_CONSOLE, length: 32)
        let encryptCrypt = try CkoCrypt2.cryptDefault()
        encryptCrypt.secretKey = aesKeyData
        let iv = try self.getNewRawIV()
        encryptCrypt.setEncodedIV(iv, encoding: "base64")
        let decryptedData = decryptedData.data(using: .utf8)
        guard let data = encryptCrypt.encryptBytes(decryptedData) else {
            throw DPAGErrorCrypto.errEncryption(encryptCrypt.lastErrorText)
        }
        var rc: [AnyHashable: Any] = [:]
        rc["iv"] = iv
        rc["salt"] = salt
        rc["data"] = try CryptoHelperCoding.shared.encodeBase64(data: data)
        return rc
    }

    public static func encrypt(string: String, withPublicKey publicKey: String) throws -> String {
        let encryptRsa = try CkoRsa.cryptRsa()
        encryptRsa.importPublicKey(publicKey)
        guard let encryptedString = encryptRsa.encryptStringENC(string, bUsePrivateKey: false) else {
            throw DPAGErrorCrypto.errEncryption(encryptRsa.lastErrorText)
        }
        return encryptedString
    }

    static func hashAndEncrypt(string: String, withPublicKey publicKey: String) throws -> String {
        guard let data = CryptoHelperCoding.shared.sha256Hasher?.hashString(string) else {
            throw DPAGErrorCrypto.errEncoding(CryptoHelperCoding.shared.sha256Hasher?.lastErrorText ?? "no encoder")
        }
        let encryptRsa = try CkoRsa.cryptRsa()
        encryptRsa.importPublicKey(publicKey)
        guard let encryptedString = encryptRsa.encryptBytesENC(data, bUsePrivateKey: false) else {
            throw DPAGErrorCrypto.errEncryption(encryptRsa.lastErrorText)
        }
        return encryptedString
    }
}

public class CryptoHelperCoding {
    public static let shared = CryptoHelperCoding()

    private init() {}

    private func crypt(hashAlgorithm: String?, cryptAlgorithm: String?, encodingMode: String) -> CkoCrypt2? {
        if let crypt = CkoCrypt2() {
            crypt.unlockCryptComponent()
            if let hashAlgorithm = hashAlgorithm {
                crypt.hashAlgorithm = hashAlgorithm
            }
            if let cryptAlgorithm = cryptAlgorithm {
                crypt.cryptAlgorithm = cryptAlgorithm
            }
            crypt.encodingMode = encodingMode
            return crypt
        }
        return nil
    }

    fileprivate lazy var md5Hasher: CkoCrypt2? = {
        self.crypt(hashAlgorithm: "md5", cryptAlgorithm: nil, encodingMode: "hex")
    }()

    fileprivate lazy var sha256Hasher: CkoCrypt2? = {
        self.crypt(hashAlgorithm: "sha-256", cryptAlgorithm: nil, encodingMode: "hex")
    }()

    private lazy var sha1Hasher: CkoCrypt2? = {
        self.crypt(hashAlgorithm: "sha-1", cryptAlgorithm: nil, encodingMode: "hex")
    }()

    private lazy var sha384Hasher: CkoCrypt2? = {
        self.crypt(hashAlgorithm: "sha-384", cryptAlgorithm: nil, encodingMode: "hex")
    }()

    fileprivate lazy var base64Encoder: CkoCrypt2? = {
        self.crypt(hashAlgorithm: nil, cryptAlgorithm: "none", encodingMode: "base64")
    }()

    private lazy var hexEncoder: CkoCrypt2? = {
        self.crypt(hashAlgorithm: nil, cryptAlgorithm: "none", encodingMode: "hex")
    }()

    func decodeBase64(data: String) throws -> Data {
        guard let returnValue = self.base64Encoder?.decryptBytesENC(data) else {
            throw DPAGErrorCrypto.errEncoding(self.base64Encoder?.lastErrorText ?? "no encoder")
        }
        return returnValue
    }

    func encodeBase64(data: Data) throws -> String {
        guard let returnValue = self.base64Encoder?.encryptBytesENC(data) else {
            throw DPAGErrorCrypto.errEncoding(self.base64Encoder?.lastErrorText ?? "no encoder")
        }
        return returnValue
    }

    func decodeHex(data: String) throws -> Data {
        guard let returnValue = self.hexEncoder?.decryptBytesENC(data) else {
            throw DPAGErrorCrypto.errEncoding(self.hexEncoder?.lastErrorText ?? "no encoder")
        }
        return returnValue
    }

    func encodeHex(data: Data) throws -> String {
        guard let returnValue = self.hexEncoder?.encryptBytesENC(data) else {
            throw DPAGErrorCrypto.errEncoding(self.hexEncoder?.lastErrorText ?? "no encoder")
        }
        return returnValue
    }

    public func md5Hash(value: String) throws -> String {
        guard let returnValue = self.md5Hasher?.hashStringENC(value) else {
            throw DPAGErrorCrypto.errEncoding(self.md5Hasher?.lastErrorText ?? "no encoder")
        }
        return returnValue.lowercased()
    }

    public func md5Hash(value: Data) throws -> String {
        guard let returnValue = self.md5Hasher?.hashBytesENC(value) else {
            throw DPAGErrorCrypto.errEncoding(self.md5Hasher?.lastErrorText ?? "no encoder")
        }
        return returnValue.lowercased()
    }

    func shaHash(value: String) throws -> String {
        guard let returnValue = self.sha256Hasher?.hashStringENC(value) else {
            throw DPAGErrorCrypto.errEncoding(self.sha256Hasher?.lastErrorText ?? "no encoder")
        }
        return returnValue.lowercased()
    }

    func sha384Hash(data: Data) throws -> Data {
        guard let returnValue = self.sha384Hasher?.hashBytes(data) else {
            throw DPAGErrorCrypto.errEncoding(self.sha256Hasher?.lastErrorText ?? "no encoder")
        }
        return returnValue
    }
}

public class CryptoHelperSimple {
    fileprivate var decryptRsa: CkoRsa?
    fileprivate var encryptRsa: CkoRsa?
    
    public fileprivate(set) var publicKey: String?

    fileprivate init() throws {}

    public init(publicKey: String, privateKey: String) throws {
        if self.encryptRsa == nil {
            try self.initEncryptRSA()
        }
        if self.decryptRsa == nil {
            try self.initDecryptRSA(privateKey: privateKey)
        }
        guard let decryptRsa = self.decryptRsa, let encryptRsa = self.encryptRsa else {
            throw DPAGErrorCrypto.errCko
        }
        try DPAGFunctionsGlobal.synchronizedWithError(encryptRsa) {
            guard encryptRsa.importPublicKey(publicKey) else {
                throw DPAGErrorCrypto.errEncryption(encryptRsa.lastErrorText)
            }
            self.publicKey = publicKey.replacingOccurrences(of: "RSAPublicKey", with: "RSAKeyValue")
        }
        try DPAGFunctionsGlobal.synchronizedWithError(decryptRsa) {
            decryptRsa.importPrivateKey(privateKey)
        }
    }

    fileprivate func initDecryptRSA(privateKey: String) throws {
        try DPAGFunctionsGlobal.synchronizedWithError(self) {
            let decryptRsa = try CkoRsa.cryptRsa()
            decryptRsa.importPrivateKey(privateKey)
            self.decryptRsa = decryptRsa
        }
    }

    fileprivate func initEncryptRSA() throws {
        try DPAGFunctionsGlobal.synchronizedWithError(self) {
            let encryptRsa = try CkoRsa.cryptRsa()
            self.encryptRsa = encryptRsa
        }
    }

    fileprivate func privateKey() throws -> String {
        guard let decryptRsa = self.decryptRsa else {
            throw DPAGErrorCrypto.errCko
        }
        var privateKeyExport: String?
        DPAGFunctionsGlobal.synchronized(decryptRsa) {
            privateKeyExport = decryptRsa.exportPrivateKey()
        }
        if privateKeyExport?.isEmpty ?? true {
            privateKeyExport = try self.getDecryptedPrivateKey()
        }
        guard let privateKey = privateKeyExport, privateKey.isEmpty == false else {
            throw DPAGErrorCrypto.errEncryption("Fehler beim Exportieren des privaten Schlüssels. " + decryptRsa.lastErrorText)
        }
        guard privateKey.hasPrefix("<RSAKeyValue>") else {
            throw DPAGErrorCrypto.errEncryption("Der private Schlüssels hat nicht das richtige Prefix. " + decryptRsa.lastErrorText)
        }
        return privateKey
    }

    func decryptWithPrivateKey(encryptedString: String) throws -> String {
        guard let decryptRsa = self.decryptRsa else {
            throw DPAGErrorCrypto.errCko
        }
        return try DPAGFunctionsGlobal.synchronizedReturnWithError(decryptRsa) {
            guard let decString = decryptRsa.decryptStringENC(encryptedString, bUsePrivateKey: true) else {
                throw DPAGErrorCrypto.errEncryption(decryptRsa.lastErrorText)
            }
            return decString
        }
    }

    func getPublicKeyFromPrivateKey() throws -> String {
        guard let decryptRsa = self.decryptRsa else {
            throw DPAGErrorCrypto.errCko
        }
        return try DPAGFunctionsGlobal.synchronizedReturnWithError(decryptRsa) {
            decryptRsa.exportPublicKey().replacingOccurrences(of: "RSAPublicKey", with: "RSAKeyValue")
        }
    }

    func decryptAesKey(encryptedAeskey: String) throws -> String? {
        guard let decryptRsa = self.decryptRsa else {
            throw DPAGErrorCrypto.errCko
        }
        return try DPAGFunctionsGlobal.synchronizedReturnWithError(decryptRsa) {
            guard let returnValue = decryptRsa.decryptStringENC(encryptedAeskey, bUsePrivateKey: true), returnValue.isEmpty == false else {
                throw DPAGErrorCrypto.errEncryption(decryptRsa.lastErrorText)
            }
            return returnValue
        }
    }

    func getDecryptedPrivateKey() throws -> String? {
        guard let decryptRsa = self.decryptRsa else {
            throw DPAGErrorCrypto.errCko
        }
        var privateKey: String?
        DPAGFunctionsGlobal.synchronized(decryptRsa) {
            privateKey = decryptRsa.exportPrivateKey()
        }
        return privateKey
    }

    func signData(data: String) throws -> String {
        try self.signData(data: data, hashAlg: "sha-1")
    }

    func signData256(data: String) throws -> String {
        try self.signData(data: data, hashAlg: "sha-256")
    }

    func signDataRaw256(data: String) throws -> String {
        try self.signData(data: data, hashAlg: "sha-256", raw: true)
    }

    private func signData(data: String, hashAlg: String, raw: Bool = false) throws -> String {
        let signData = try CkoRsa.cryptRsa()
        signData.oaepPadding = false
        let privateKey = try self.privateKey()
        signData.importPrivateKey(privateKey)
        if raw {
            let rawData = Data(base64Encoded: data, options: .ignoreUnknownCharacters)
            guard let rc = signData.signBytesENC(rawData, hashAlg: hashAlg) else {
                throw DPAGErrorCrypto.errEncryption(signData.lastErrorText)
            }
            return rc
        } else {
            guard let rc = signData.signStringENC(data, hashAlg: hashAlg) else {
                throw DPAGErrorCrypto.errEncryption(signData.lastErrorText)
            }
            return rc
        }
    }
}

public class CryptoHelperExtended: CryptoHelperSimple {
    fileprivate static let KEYCHAIN_IDENTIFIER_PUBLIC_KEY = "public_keyDL"
    fileprivate static let KEYCHAIN_IDENTIFIER_PRIVATE_KEY = "private_keyDL"
    fileprivate static let KEYCHAIN_IDENTIFIER_PRIVATE_KEY_ENCODED = "private_key_enc_DL"
    fileprivate static let KEYCHAIN_IDENTIFIER_PRIVATE_KEY_ENC_MOVEABLE_DL = "private_key_enc_moveable_DL"

    fileprivate static let AES_KEY_FILE_KEY_AESKEY = "aeskey"
    fileprivate static let AES_KEY_FILE_NAME = "data.plist"
    fileprivate static let AES_KEY_FOLDER_NAME = "AesKeyData"
    static let AES_KEY_FOLDER_NAME_PBDKF = "AesKeyPBDKF"

    private var _kcWrapper: KeychainWrapper?
    fileprivate var kcWrapper: KeychainWrapper? {
        get {
            if _kcWrapper == nil {
                _kcWrapper = KeychainWrapper(identifier: CryptoHelper.KEYCHAIN_IDENTIFIER_PRIVATE_KEY, accessGroup: nil, isThisDeviceOnly: true)
            }
            return _kcWrapper
        }
        set {
            _kcWrapper = newValue
        }
    }

    fileprivate func setDecryptedPrivateKey(key: String, isPasswordDecryptedKey: Bool) throws {
        if self !== CryptoHelper.sharedInstance {
            return
        }
        var aesKey: String?
        if try self.aesKeyFileExists(forPasswordProtectedKey: isPasswordDecryptedKey) == false {
            aesKey = try self.createAesKeyFile(forPasswordProtectedKey: isPasswordDecryptedKey)
        } else {
            aesKey = try self.aesKeyFromFile(forPasswordProtectedKey: isPasswordDecryptedKey)
        }
        let encCrypt = try CkoCrypt2.cryptDefault()
        encCrypt.setEncodedKey(aesKey, encoding: "hex")
        encCrypt.setEncodedIV(try self.hashForIV(), encoding: "hex")
        guard let encryptedString = encCrypt.encryptStringENC(key), encryptedString.isEmpty == false else {
            throw DPAGErrorCrypto.errEncryption("Der private Schlüssel konnte nicht verschlüsselt werden. " + encCrypt.lastErrorText)
        }
        self.kcWrapper?.setPassword(encryptedString)
    }

    fileprivate func createAesKeyFile(forPasswordProtectedKey: Bool) throws -> String? {
        if self !== CryptoHelper.sharedInstance {
            return nil
        }
        let aesKey = try self.hashForPwd(pwd: self.uuid(), salt: self.uuid(), rounds: CryptoHelper.ROUNDS_DEFAULT_SALT)
        let aesDict = [CryptoHelperExtended.AES_KEY_FILE_KEY_AESKEY: aesKey]
        let tempArray = [aesDict]
        guard let path = try self.aesKeyFilePath(forPasswordProtectedKey: forPasswordProtectedKey) else {
            throw DPAGErrorCrypto.errGenerateKey("aesKeyFilePath is nil")
        }
        guard (tempArray as NSArray).write(to: path, atomically: true) else {
            throw DPAGErrorCrypto.errGenerateKey("aes key write to file failed")
        }
        return aesKey
    }

    fileprivate func aesKeyFromFile(forPasswordProtectedKey: Bool) throws -> String {
        guard let fileURL = try self.aesKeyFilePath(forPasswordProtectedKey: forPasswordProtectedKey) else {
            throw DPAGErrorCrypto.errGenerateKey("aesKeyFilePath is nil")
        }
        let tempArray = NSArray(contentsOf: fileURL) as? [Any] ?? []
        guard tempArray.isEmpty == false, let aesDict = tempArray.first as? [AnyHashable: Any], let aesKeyFromFile = aesDict[CryptoHelperExtended.AES_KEY_FILE_KEY_AESKEY] as? String else {
            throw DPAGErrorCrypto.errGenerateKey("aesKeyFromFile is nil")
        }
        return aesKeyFromFile
    }

    private func aesKeyFilePath(forPasswordProtectedKey: Bool) throws -> URL? {
        let aesKeyFilePath = (forPasswordProtectedKey ? try self.aesPbdkfKeyDirectoriesPath() : try self.aesKeyDirectoriesPath())?.appendingPathComponent(CryptoHelperExtended.AES_KEY_FILE_NAME)
        return aesKeyFilePath
    }

    fileprivate func aesKeyDirectoriesPath() throws -> URL? {
        try DPAGFileHelper.createFolderInDocBase(forPathComponent: CryptoHelperExtended.AES_KEY_FOLDER_NAME, isExcludedFromBackup: true)
    }

    fileprivate func aesPbdkfKeyDirectoriesPath() throws -> URL? {
        try DPAGFileHelper.createFolderInDocBase(forPathComponent: CryptoHelperExtended.AES_KEY_FOLDER_NAME_PBDKF, isExcludedFromBackup: true)
    }

    fileprivate func uuid() -> String {
        DPAGFunctionsGlobal.uuid()
    }

    fileprivate func hashForPwd(pwd: String, salt saltString: String, rounds: UInt32) throws -> String? {
        guard let passwordData = pwd.data(using: .utf8) else {
            throw DPAGErrorCrypto.errData
        }
        guard let salt = CryptoHelperCoding.shared.md5Hasher?.hashString(saltString) else {
            throw DPAGErrorCrypto.errEncryption(CryptoHelperCoding.shared.md5Hasher?.lastErrorText ?? "no ckoCryptHash")
        }
        let hex = CryptoHelper.pbkdfKeyHex(passwordData: passwordData, salt: salt, rounds: rounds, length: 32)
        return hex
    }

    fileprivate func hashForIV() throws -> String {
        let iv = try CryptoHelperCoding.shared.md5Hash(value: "fc395f4f59648152f7cffa297e5440ba")
        if iv.count > 16 {
            return String(iv[..<iv.index(iv.startIndex, offsetBy: 16)])
        }
        return iv
    }

    public func aesKeyFileExists(forPasswordProtectedKey: Bool) throws -> Bool {
        guard let fileURL = try self.aesKeyFilePath(forPasswordProtectedKey: forPasswordProtectedKey) else {
            throw DPAGErrorCrypto.errGenerateKey("aesKeyFilePath is nil")
        }
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
}

class CryptoHelperCreate: CryptoHelperExtended {
    override init() throws {
        try super.init()
        guard let rsa = CkoRsa() else { return }
        rsa.unlockRsaComponent()
        guard rsa.generateKey(NSNumber(value: 2_048)) else {
            throw DPAGErrorCrypto.errGenerateKey(rsa.lastErrorText)
        }
        self.publicKey = rsa.exportPublicKey().replacingOccurrences(of: "RSAPublicKey", with: "RSAKeyValue")
        guard let privateKey = rsa.exportPrivateKey() else {
            throw DPAGErrorCrypto.errEncryption(rsa.lastErrorText)
        }
        try self.setDecryptedPrivateKey(key: privateKey, isPasswordDecryptedKey: false)
        try self.initDecryptRSA(privateKey: privateKey)
    }
}

class CryptoHelperAccount: CryptoHelperSimple {
    func getDecryptedPKInKeyChainForPushPreview() throws -> String {
        let privateKey = try self.privateKey()
        return privateKey
    }
}

public class CryptoHelper: CryptoHelperExtended {
    public static let sharedInstance = try? CryptoHelper()

    static let ROUNDS_DEFAULT_SALT: UInt32 = 1_000
    static let ROUNDS_NEW_SALT: UInt32 = 80_000
    static let ROUNDS_ADMIN_CONSOLE: UInt32 = 8_000

    static let DEFAULT_SALT = "dghewurwkbk"
    var decryptedKeyCache: [AnyHashable: [AnyHashable: Any]] = [:]

    private var _kcWrapperForENC: KeychainWrapper?
    fileprivate var kcWrapperForENC: KeychainWrapper? {
        get {
            if _kcWrapperForENC == nil {
                _kcWrapperForENC = KeychainWrapper(identifier: CryptoHelperExtended.KEYCHAIN_IDENTIFIER_PRIVATE_KEY_ENCODED, accessGroup: nil, isThisDeviceOnly: true)
            }
            return _kcWrapperForENC
        }
        set {
            _kcWrapperForENC = newValue
        }
    }

    private var passwordProtectedPrivateKeyIntern: String?
    private var saltForPrivateKey: String?

    override init() throws {
        try super.init()
        if self.passwordProtectedPrivateKeyIntern?.isEmpty ?? true {
            self.loadDataFromKeychain()
        } else if self.kcWrapperForENC?.password() == nil {
            if let passwordProtectedPrivateKeyIntern = self.passwordProtectedPrivateKeyIntern {
                self.kcWrapperForENC?.setPassword(passwordProtectedPrivateKeyIntern)
            }
            if let saltForPrivateKey = self.saltForPrivateKey {
                self.kcWrapperForENC?.setUser(saltForPrivateKey)
            }
        }
        try self.initEncryptRSA()
    }

    func loadDataFromKeychain() {
        // Reset KeychainWrapper
        self.kcWrapperForENC = nil
        if let temp = self.kcWrapperForENC?.password() {
            self.passwordProtectedPrivateKeyIntern = temp
        }
        if let temp = self.kcWrapperForENC?.user() {
            self.saltForPrivateKey = temp
        }
    }

    func generateKeyPairAndSaveitToKeyChain() throws {
        try DPAGFunctionsGlobal.synchronizedWithError(self) {
            guard let pKey = self.decryptRsa?.exportPrivateKey(), pKey.isEmpty == false else {
                guard let pubKeyKcWrapper = KeychainWrapper(identifier: CryptoHelperExtended.KEYCHAIN_IDENTIFIER_PUBLIC_KEY, accessGroup: nil, isThisDeviceOnly: true) else {
                    throw DPAGErrorCrypto.errKeychain
                }
                self.publicKey = pubKeyKcWrapper.password()?.replacingOccurrences(of: "RSAPublicKey", with: "RSAKeyValue")
                return
            }
        }
        guard let rsa = CkoRsa() else {
            throw DPAGErrorCrypto.errCko
        }
        rsa.unlockRsaComponent()
        guard rsa.generateKey(NSNumber(value: 2_048)) else {
            throw DPAGErrorCrypto.errGenerateKey(rsa.lastErrorText)
        }
        self.publicKey = rsa.exportPublicKey().replacingOccurrences(of: "RSAPublicKey", with: "RSAKeyValue")
        guard let pubKeyKcWrapper = KeychainWrapper(identifier: CryptoHelperExtended.KEYCHAIN_IDENTIFIER_PUBLIC_KEY, accessGroup: nil, isThisDeviceOnly: true) else {
            throw DPAGErrorCrypto.errKeychain
        }
        pubKeyKcWrapper.resetKeychainItem()
        if let publicKey = self.publicKey {
            pubKeyKcWrapper.setPassword(publicKey)
        }
        guard let privateKey = rsa.exportPrivateKey() else {
            throw DPAGErrorCrypto.errEncryption(rsa.lastErrorText)
        }
        try self.setDecryptedPrivateKey(key: privateKey, isPasswordDecryptedKey: true)
        try self.initDecryptRSA(privateKey: privateKey)
    }

    func encryptWithPrivateKey(string: String) throws -> String {
        guard let decryptRsa = self.decryptRsa, let encryptRsa = self.encryptRsa else {
            throw DPAGErrorCrypto.errCko
        }
        return try DPAGFunctionsGlobal.synchronizedReturnWithError(decryptRsa) {
            guard let privateKey = decryptRsa.exportPrivateKey() else {
                throw DPAGErrorCrypto.errEncryption(decryptRsa.lastErrorText)
            }
            encryptRsa.importPrivateKey(privateKey)
            guard let encryptedString = encryptRsa.encryptStringENC(string, bUsePrivateKey: true) else {
                throw DPAGErrorCrypto.errEncryption(encryptRsa.lastErrorText)
            }
            return encryptedString
        }
    }

    func decryptAesKeyAsDict(encryptedAesKey: String) throws -> [AnyHashable: Any]? {
        /*
         * AES KEY Entschlüsseln
         */
        guard let decryptedAesKeyXML = try self.decryptAesKey(encryptedAeskey: encryptedAesKey) else { return nil }
        let dict = try XMLReader.dictionary(forXMLString: decryptedAesKeyXML)
        return dict
    }

    static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ssZ"
        return dateFormatter
    }()

    static func newDateInDLFormat() -> String {
        CryptoHelper.dateFormatter.string(from: Date())
    }

    func decrypt(encryptedString: String, withEncAesKey encAesKey: String) throws -> Data? {
        guard let decAesKeyXML = try self.decryptAesKey(encryptedAeskey: encAesKey) else { return nil }
        return try CryptoHelperDecrypter.decrypt(encryptedString: encryptedString, withAesKey: decAesKeyXML)
    }

    func decryptToString(encryptedString: String, withEncAesKey encAesKey: String) throws -> String? {
        guard let decAesKeyXML = try self.decryptAesKey(encryptedAeskey: encAesKey) else { return nil }
        return try CryptoHelperDecrypter.decryptToString(encryptedString: encryptedString, withAesKey: decAesKeyXML)
    }

    func decryptToString(encryptedString: String, withTan tan: String) throws -> String {
        guard tan.isEmpty == false, encryptedString.isEmpty == false else {
            throw DPAGErrorCrypto.errEncryption("tan == nil || encryptedString == nil")
        }
        let decryptCrypt = try CkoCrypt2.cryptDefault()
        try self.initCrypto(crypto: decryptCrypt, withTan: tan)
        guard let decryptedString = decryptCrypt.decryptStringENC(encryptedString), decryptedString.isEmpty == false else {
            throw DPAGErrorCrypto.errEncryption("Fehler beim Entschlüsseln eines Strings. " + decryptCrypt.lastErrorText)
        }
        return decryptedString
    }

    func encrypt(string: String, withTan tan: String) throws -> String {
        guard tan.isEmpty == false, string.isEmpty == false else {
            throw DPAGErrorCrypto.errEncryption("tan.isEmpty || string.isEmpty")
        }
        let encryptCrypt = try CkoCrypt2.cryptDefault()
        try self.initCrypto(crypto: encryptCrypt, withTan: tan)
        guard let encryptedString = encryptCrypt.encryptStringENC(string), encryptedString.isEmpty == false else {
            throw DPAGErrorCrypto.errEncryption(encryptCrypt.lastErrorText)
        }
        return encryptedString
    }

    public func deleteDecryptedPrivateKeyinKeyChain() {
        self.kcWrapper?.resetKeychainItem()
        self.kcWrapper = nil
    }

    func deleteEncryptedPrivateKeyinKeyChain() {
        self.kcWrapperForENC?.resetKeychainItem()
        self.passwordProtectedPrivateKeyIntern = nil
        self.saltForPrivateKey = nil
    }

    public func putDecryptedPKFromHeapInKeyChain() throws {
        let privateKey = try self.privateKey()
        try self.setDecryptedPrivateKey(key: privateKey, isPasswordDecryptedKey: false)
    }

    override func decryptAesKey(encryptedAeskey: String) throws -> String? {
        guard let decryptRsa = self.decryptRsa else {
            throw DPAGErrorCrypto.errCko
        }
        return try DPAGFunctionsGlobal.synchronizedReturnWithError(decryptRsa) {
            /*
             * AES KEY Entschlüsseln
             */
            do {
                guard let returnValue = decryptRsa.decryptStringENC(encryptedAeskey, bUsePrivateKey: true), returnValue.isEmpty == false else {
                    throw DPAGErrorCrypto.errEncryption(decryptRsa.lastErrorText)
                }
                return returnValue
            } catch {
                let pKey = decryptRsa.exportPrivateKey()
                let rsaKeyValuePrefix = "<RSAKeyValue>".lowercased()
                if (pKey?.lowercased().hasPrefix(rsaKeyValuePrefix) ?? false) == false {
                    if let pKeyPass = try self.getDecryptedPrivateKey() {
                        if pKeyPass.lowercased().hasPrefix(rsaKeyValuePrefix) {
                            try self.initDecryptRSA(privateKey: pKeyPass)
                        } else {
                            throw DPAGErrorCrypto.errKeychain
                        }
                    } else {
                        throw DPAGErrorCrypto.errKeychain
                    }
                }
            }
            return nil
        }
    }

    func encryptPrivateKeyWithAesKey(privateKey: String) throws -> String {
        var aesKey: String?
        if try self.aesKeyFileExists(forPasswordProtectedKey: false) == false {
            aesKey = try self.createAesKeyFile(forPasswordProtectedKey: false)
        } else {
            aesKey = try self.aesKeyFromFile(forPasswordProtectedKey: false)
        }
        let encCrypt = try CkoCrypt2.cryptDefault()
        encCrypt.setEncodedKey(aesKey, encoding: "hex")
        encCrypt.setEncodedIV(try self.hashForIV(), encoding: "hex")
        guard let encryptedString = encCrypt.encryptStringENC(privateKey), encryptedString.isEmpty == false else {
            throw DPAGErrorCrypto.errEncryption("Der private Schlüssel konnte nicht verschlüsselt werden. " + encCrypt.lastErrorText)
        }
        return encryptedString
    }

    public func putDecryptedPKFromHeapInKeyChainForTouchID() throws {
        let privateKey = try self.privateKey()
        let encryptedString = try self.encryptPrivateKeyWithAesKey(privateKey: privateKey)
        TouchIDKeyProvider.sharedInstance().setKeyForTouchID(encryptedString)
    }

    public func deleteDecryptedPrivateKeyForTouchID() {
        TouchIDKeyProvider.sharedInstance()?.reset()
    }

    public func hasPrivateKeyForTouchID() -> Bool {
        TouchIDKeyProvider.sharedInstance()?.hasKeyForTouchID() ?? false
    }

    public func decryptTouchIDPrivateKey() throws {
        guard let encPK = TouchIDKeyProvider.sharedInstance()?.keyForTouchID(), encPK.isEmpty == false else { return }
        guard let privateKey = try self.decryptKeyWithAesKeyFromFile(encryptedKey: encPK), privateKey.isEmpty == false else { return }
        try self.initDecryptRSA(privateKey: privateKey)
    }

    func isPrivateKeyEncrypted() -> Bool {
        if self.passwordProtectedPrivateKeyIntern?.isEmpty ?? true {
            return false
        }
        return true
    }

    public func isPrivateKeyDecrypted() -> Bool {
        do {
            guard let privateKey = try self.getDecryptedPrivateKey(), privateKey.isEmpty == false else {
                return false
            }
            return true
        } catch {
            return false
        }
    }

    public func isPrivateKeyInMemory() -> Bool {
        var returnValue = false
        DPAGFunctionsGlobal.synchronized(self) {
            returnValue = self.decryptRsa != nil
        }
        return returnValue
    }

    public func hasPrivateKey() -> Bool {
        var isDecryptRsa = false
        DPAGFunctionsGlobal.synchronized(self) {
            isDecryptRsa = self.decryptRsa != nil
        }
        return self.isPrivateKeyDecrypted() || self.isPrivateKeyEncrypted() || isDecryptRsa
    }

    func mergeHashWithAesKeyString(pwdHash: String) throws -> String? {
        let aesKeyString = try self.aesKeyFromFile(forPasswordProtectedKey: true)
        return try self.mergePasswordHashWithAesKeyString(pwdHash: pwdHash, aesKeyString: aesKeyString)
    }

    func mergePasswordHashWithAesKeyString(pwdHash: String, aesKeyString: String) throws -> String? {
        let pwd = try CryptoHelperCoding.shared.decodeHex(data: pwdHash)
        let aes = try CryptoHelperCoding.shared.decodeHex(data: aesKeyString)
        let aesBytes = [UInt8](aes)
        var newPwdBytes = [UInt8](pwd)
        for i in 0 ..< min(newPwdBytes.count, aesBytes.count) {
            newPwdBytes[i] ^= aesBytes[i]
        }
        let data = Data(bytes: newPwdBytes, count: newPwdBytes.count)
        return try CryptoHelperCoding.shared.encodeHex(data: data)
    }

    public func decryptPrivateKey(password: String, saveDecryptedPK saveDecryptedKey: Bool) throws {
        guard password.isEmpty == false else {
            throw DPAGErrorCrypto.errEncryption("pwd.isEmpty")
        }
        if self.passwordProtectedPrivateKeyIntern?.isEmpty ?? true {
            self.loadDataFromKeychain()
        }
        guard var pwdHash = try self.hashForPwd(pwd: password, salt: self.getSalt(), rounds: self.getRounds()) else {
            throw DPAGErrorCrypto.errEncryption("no hash created")
        }
        if try self.aesKeyFileExists(forPasswordProtectedKey: true) {
            pwdHash = try self.mergeHashWithAesKeyString(pwdHash: pwdHash) ?? pwdHash
        }
        let iv = try self.hashForIV()
        guard let passwordProtectedPrivateKeyIntern = self.passwordProtectedPrivateKeyIntern, passwordProtectedPrivateKeyIntern.isEmpty == false else {
            throw DPAGErrorCrypto.errEncryption("Der private Schlüssel konnte nicht aus dem Schlüsselbund geladen werden.")
        }
        if passwordProtectedPrivateKeyIntern.lowercased().hasPrefix("<RSAKeyValue>".lowercased()) {
            throw DPAGErrorCrypto.errEncryption("Der private Schlüssel liegt nicht im richtigen Format vor.")
        }
        let decCrypt = try CkoCrypt2.cryptDefault()
        decCrypt.setEncodedKey(pwdHash, encoding: "hex")
        decCrypt.setEncodedIV(iv, encoding: "hex")
        guard let decryptedString = decCrypt.decryptStringENC(passwordProtectedPrivateKeyIntern) else {
            throw DPAGErrorCrypto.errEncryption("err_password_wrong" + decCrypt.lastErrorText)
        }
        guard decryptedString.isEmpty == false else {
            throw DPAGErrorCrypto.errEncryption("err_password_wrong" + decCrypt.lastErrorText)
        }
        guard decryptedString.lowercased().hasPrefix("<RSAKeyValue>".lowercased()) else {
            throw DPAGErrorCrypto.errEncryption("Der private Schlüssel liegt nicht im richtigen Format vor." + decCrypt.lastErrorText)
        }
        if saveDecryptedKey {
            try self.setDecryptedPrivateKey(key: decryptedString, isPasswordDecryptedKey: true)
        }
        try self.initDecryptRSA(privateKey: decryptedString)
    }

    func companyRecoveryPassword() -> String {
        let temp = "0123012301230123"
        return self.createPassword(temp: temp)
    }

    func simsmeRecoveryPassword() -> String {
        let temp = "0123"
        let rc = String(format: "%@-%@-%@-%@-%@-%@", self.createPassword(temp: temp), self.createPassword(temp: temp), self.createPassword(temp: temp), self.createPassword(temp: temp), self.createPassword(temp: temp), self.createPassword(temp: temp))
        return rc
    }

    func createPassword(temp: String) -> String {
        let validChars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz0123456789"
        var backupPassword = temp
        var idx = backupPassword.startIndex
        for _ in temp {
            let replacementChar = validChars[validChars.index(validChars.startIndex, offsetBy: Int(arc4random_uniform(UInt32(validChars.count))))]
            let idxNext = backupPassword.index(idx, offsetBy: 1)
            backupPassword.replaceSubrange(idx ..< idxNext, with: String(replacementChar))
            idx = idxNext
        }
        return backupPassword
    }

    func createCouplingTan() -> String {
        let temp = "012012012"
        return self.createPassword(temp: temp)
    }

    static func pbkdfKey(passwordData: Data, salt: Data, rounds: UInt32, length: Int) throws -> Data {
        guard let derivedKeyData = self.derivedKeyData(passwordData: passwordData, saltData: salt, length: length, rounds: rounds) else {
            throw DPAGErrorCrypto.errData
        }
        return Data(derivedKeyData)
    }

    static func pbkdfKeyHex(passwordData: Data, salt: Data, rounds: UInt32, length: Int) -> String? {
        guard let derivedKeyData = self.derivedKeyData(passwordData: passwordData, saltData: salt, length: length, rounds: rounds) else { return nil }
        // Key in Hex encoden
        let hex = derivedKeyData.reduce(into: "") { hex, char in
            hex.append(String(format: "%02X", char & 0x00FF))
        }
        return hex
    }

    private static func derivedKeyData(passwordData: Data, saltData: Data, length: Int, rounds: UInt32) -> Data? {
        guard let pwd = String(data: passwordData, encoding: .utf8) else { return nil }
        var derivedKeyData = Data(repeating: UInt8(0), count: length)
        let derivationStatus = derivedKeyData.withUnsafeMutableBytes { derivedKeyBody -> Int32? in
            guard let derivedKeyBytes = derivedKeyBody.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return nil }
            return saltData.withUnsafeBytes { saltBody -> Int32? in
                guard let saltBytes = saltBody.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return nil }
                return CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    pwd, passwordData.count,
                    saltBytes, saltData.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    rounds,
                    derivedKeyBytes, length
                )
            }
        }
        guard let status = derivationStatus, status == 0 else { return nil }
        return derivedKeyData
    }

    func backupPrivateKey(withPassword password: String, backupMode mode: DPAGBackupMode) throws {
        guard let passwordData = password.data(using: .utf8) else {
            throw DPAGErrorCrypto.errData
        }
        let dataSalt = try CryptoHelperEncrypter.getNewSalt()
        guard let salt = Data(base64Encoded: dataSalt, options: .ignoreUnknownCharacters) else {
            throw DPAGErrorCrypto.errData
        }
        let rounds: UInt32 = 80_000
        let aesKeyData = try CryptoHelper.pbkdfKey(passwordData: passwordData, salt: salt, rounds: rounds, length: 32)
        let aesKey = aesKeyData.base64EncodedString(options: .lineLength64Characters)
        let privateKey = try self.privateKey()
        let encCrypt = try CkoCrypt2.cryptDefault()
        encCrypt.setEncodedKey(aesKey, encoding: "hex")
        encCrypt.setEncodedIV(try self.hashForIV(), encoding: "hex")
        guard let encryptedString = encCrypt.encryptStringENC(privateKey), encryptedString.isEmpty == false else {
            throw DPAGErrorCrypto.errEncryption("Der private Schlüssel konnte nicht verschlüsselt werden." + encCrypt.lastErrorText)
        }
        guard let companyPrivateKeyBackupPath = (mode == .fullBackup) ? try self.companyPrivateKeyBackupPath() : try self.simsmeRecoveryPrivateKeyBackupPath() else {
            throw DPAGErrorCrypto.errEncryption("companyPrivateKeyBackupPath == nil")
        }
        ([CryptoHelper.COMPANY_PRIVATE_KEY_DICT_PRIVAT_KEY: encryptedString, CryptoHelper.COMPANY_PRIVATE_KEY_DICT_SALT: dataSalt] as NSDictionary).write(to: companyPrivateKeyBackupPath, atomically: true)
    }

    fileprivate static let COMPANY_PRIVATE_KEY_FILE_NAME = "dataComp.plist"
    fileprivate static let COMPANY_PRIVATE_KEY_DICT_PRIVAT_KEY = "privateKey"
    fileprivate static let COMPANY_PRIVATE_KEY_DICT_SALT = "salt"
    fileprivate static let SIMSME_RECOVERY_PRIVATE_KEY_FILE_NAME = "dataCompS.plist"

    public func decryptBackupPrivateKey(password: String, backupMode mode: DPAGBackupMode) throws -> Bool {
        guard let companyPrivateKeyBackupPath = (mode == .fullBackup) ? try self.companyPrivateKeyBackupPath() : try self.simsmeRecoveryPrivateKeyBackupPath() else {
            throw DPAGErrorCrypto.errEncryption("companyPrivateKeyBackupPath == nil")
        }
        guard let rsaDict = NSDictionary(contentsOf: companyPrivateKeyBackupPath) as? [AnyHashable: Any] else { return false }
        guard let dataSalt = rsaDict[CryptoHelper.COMPANY_PRIVATE_KEY_DICT_SALT] as? String, let encryptedString = rsaDict[CryptoHelper.COMPANY_PRIVATE_KEY_DICT_PRIVAT_KEY] as? String else { return false }
        guard let passwordData = password.data(using: .utf8) else {
            throw DPAGErrorCrypto.errData
        }
        guard let salt = Data(base64Encoded: dataSalt, options: .ignoreUnknownCharacters) else {
            throw DPAGErrorCrypto.errData
        }
        let rounds: UInt32 = 80_000
        let aesKeyData = try CryptoHelper.pbkdfKey(passwordData: passwordData, salt: salt, rounds: rounds, length: 32)
        let aesKey = aesKeyData.base64EncodedString(options: .lineLength64Characters)
        do {
            let encCrypt = try CkoCrypt2.cryptDefault()
            encCrypt.setEncodedKey(aesKey, encoding: "hex")
            encCrypt.setEncodedIV(try self.hashForIV(), encoding: "hex")
            guard let decryptedString = encCrypt.decryptStringENC(encryptedString), decryptedString.isEmpty == false else { return false }
            try self.initDecryptRSA(privateKey: decryptedString)
            return true
        } catch {
            // NOOP
        }
        return false
    }

    func companyPrivateKeyBackupPath() throws -> URL? {
        let aesKeyFilePath = try self.aesPbdkfKeyDirectoriesPath()
        return aesKeyFilePath?.appendingPathComponent(CryptoHelper.COMPANY_PRIVATE_KEY_FILE_NAME)
    }

    func simsmeRecoveryPrivateKeyBackupPath() throws -> URL? {
        let aesKeyFilePath = try self.aesPbdkfKeyDirectoriesPath()
        return aesKeyFilePath?.appendingPathComponent(CryptoHelper.SIMSME_RECOVERY_PRIVATE_KEY_FILE_NAME)
    }

    func deleteBackupPrivateKey(mode: DPAGBackupMode) throws -> Bool {
        guard let path = mode == .fullBackup ? try self.companyPrivateKeyBackupPath() : try self.simsmeRecoveryPrivateKeyBackupPath() else { return true }
        do {
            try FileManager.default.removeItem(at: path)
            return true
        } catch {
            return false
        }
    }

    func aesKey(forPhone phone: String?, email: String?, seed: String, salt: String, diff aesDiff: String?) throws -> String? {
        let password = String(format: "%@%@%@", seed, phone ?? "", email ?? "")
        guard let passwordData = password.data(using: .utf8) else {
            throw DPAGErrorCrypto.errData
        }
        guard let saltData = Data(base64Encoded: salt, options: .ignoreUnknownCharacters) else {
            throw DPAGErrorCrypto.errData
        }
        let aesKeyData = try CryptoHelper.pbkdfKey(passwordData: passwordData, salt: saltData, rounds: CryptoHelper.ROUNDS_ADMIN_CONSOLE, length: 32)
        if let aesDiff = aesDiff, aesDiff.isEmpty == false {
            let aesDiffData = try CryptoHelperCoding.shared.decodeBase64(data: aesDiff)
            let aesBytes = [UInt8](aesDiffData /* .utf8 */ )
            var newPwdBytes = [UInt8](aesKeyData /* .utf8 */ )
            for i in 0 ..< min(newPwdBytes.count, aesBytes.count) {
                newPwdBytes[i] ^= aesBytes[i]
            }
            let aesKey = Data(bytes: newPwdBytes, count: newPwdBytes.count).base64EncodedString(options: .lineLength64Characters)
            return aesKey
        }
        let aesKey = aesKeyData.base64EncodedString(options: .lineLength64Characters)
        return aesKey
    }

    func createNewSalt() -> String {
        let salt = String(format: "%@-%@", self.uuid(), self.uuid())
        // In Version 1.00.004 existiert der Salt noch nicht
        if self.saltForPrivateKey?.isEmpty ?? true {
            self.kcWrapperForENC?.setUser(salt)
            self.saltForPrivateKey = salt
        }
        return salt
    }

    func getSalt() -> String {
        guard let saveSalt = self.saltForPrivateKey, saveSalt.isEmpty == false else {
            return CryptoHelper.DEFAULT_SALT
        }
        return saveSalt
    }

    func getRounds() -> UInt32 {
        if CryptoHelper.DEFAULT_SALT == self.getSalt() {
            return CryptoHelper.ROUNDS_DEFAULT_SALT
        }
        return CryptoHelper.ROUNDS_NEW_SALT
    }

    func encryptPrivateKey(password: String) throws {
        guard password.isEmpty == false else {
            throw DPAGErrorCrypto.errEncryption("pwd.isEmpty")
        }
        let salt = self.createNewSalt()
        let rounds = self.getRounds()
        guard var pwdHash = try self.hashForPwd(pwd: password, salt: salt, rounds: rounds) else {
            throw DPAGErrorCrypto.errEncryption("no pwdHash")
        }
        if try self.aesKeyFileExists(forPasswordProtectedKey: true) == false {
            DPAGLog("AES key file does not exist -> creating new key file")
            _ = try self.createAesKeyFile(forPasswordProtectedKey: true)
        }
        if try self.aesKeyFileExists(forPasswordProtectedKey: true) {
            pwdHash = try self.mergeHashWithAesKeyString(pwdHash: pwdHash) ?? pwdHash
        }
        let iv = try self.hashForIV()
        let privateKey = try self.privateKey()
        let encCrypt = try CkoCrypt2.cryptDefault()
        encCrypt.setEncodedKey(pwdHash, encoding: "hex")
        encCrypt.setEncodedIV(iv, encoding: "hex")
        guard let encryptedString = encCrypt.encryptStringENC(privateKey), encryptedString.isEmpty == false else {
            throw DPAGErrorCrypto.errEncryption("Der private Schlüssel konnte nicht verschlüsselt werden." + encCrypt.lastErrorText)
        }
        self.setPasswordProtectedPrivateKey(key: encryptedString)
        self.setSalt(salt: salt)
    }

    func checkPrivateKeyPassword(pwd: String) throws -> Bool {
        guard pwd.isEmpty == false else {
            throw DPAGErrorCrypto.errEncryption("pwd.isEmpty")
        }
        guard var pwdHash = try self.hashForPwd(pwd: pwd, salt: self.getSalt(), rounds: self.getRounds()) else {
            throw DPAGErrorCrypto.errEncryption("no pwdHash")
        }
        if try self.aesKeyFileExists(forPasswordProtectedKey: true) {
            pwdHash = try self.mergeHashWithAesKeyString(pwdHash: pwdHash) ?? pwdHash
        }
        let iv = try self.hashForIV()
        if self.passwordProtectedPrivateKeyIntern?.isEmpty ?? true {
            throw DPAGErrorCrypto.errEncryption("Der private Schlüssel konnte nicht aus dem Schlüsselbund geladen werden.")
        }
        if self.passwordProtectedPrivateKeyIntern?.lowercased().hasPrefix("<RSAKeyValue>".lowercased()) ?? false {
            throw DPAGErrorCrypto.errEncryption("Der private Schlüssel liegt nicht im richtigen Format vor.")
        }
        let decCrypt = try CkoCrypt2.cryptDefault()
        decCrypt.setEncodedKey(pwdHash, encoding: "hex")
        decCrypt.setEncodedIV(iv, encoding: "hex")
        guard let decryptedString = decCrypt.decryptStringENC(self.passwordProtectedPrivateKeyIntern), decryptedString.isEmpty == false else { return false }
        if decryptedString.lowercased().hasPrefix("<RSAKeyValue>".lowercased()) == false {
            return false
        }
        return true
    }

    public func resetCryptoHelper() {
        DPAGFunctionsGlobal.synchronized(self) {
            self.decryptRsa = nil
        }
        self.queueKeys.async(flags: .barrier) {
            self.decryptedKeyCache.removeAll()
        }
    }

    func initCrypto(crypto: CkoCrypt2, withTan tan: String) throws {
        let rawData = try CryptoHelperGenerator.decodeTicketTan(tan: tan)
        try rawData.withUnsafeBytes { body in
            guard let bytes = body.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                throw DPAGErrorCrypto.errData
            }
            let key = Data(bytes: bytes + 0, count: 256 / 8)
            let iv = Data(bytes: bytes + 256 / 8, count: 128 / 8)
            let keyEncoded = try CryptoHelperCoding.shared.encodeBase64(data: key)
            crypto.setEncodedKey(keyEncoded, encoding: "base64")
            let ivEncoded = try CryptoHelperCoding.shared.encodeBase64(data: iv)
            crypto.setEncodedIV(ivEncoded, encoding: "base64")
        }
    }

    func transformPassword(password: String) throws -> String? {
        guard password.count > 55 else {
            return password
        }
        return try CryptoHelperCoding.shared.shaHash(value: password)
    }

    func hashPassword(password: String) throws -> String {
        let password = try self.transformPassword(password: password)
        guard let rc = JFBCrypt.hashPassword(password, withSalt: JFBCrypt.generateSalt(withNumberOfRounds: 4)) else {
            throw DPAGErrorCrypto.errCrypt
        }
        return rc
    }

    public func checkPassword(password: String, withHash hashValue: String) throws -> Bool {
        let password = try self.transformPassword(password: password)
        let rc = JFBCrypt.hashPassword(password, withSalt: hashValue)
        return hashValue == rc
    }

    override func getDecryptedPrivateKey() throws -> String? {
        var privateKey: String?
        if let decryptRsa = self.decryptRsa {
            DPAGFunctionsGlobal.synchronized(decryptRsa) {
                privateKey = decryptRsa.exportPrivateKey()
            }
        }
        if (privateKey?.lowercased().hasPrefix("<RSAKeyValue>".lowercased()) ?? false) == false {
            if let encPK = self.kcWrapper?.password(), encPK.isEmpty == false {
                if let privateKey = try self.decryptKeyWithAesKeyFromFile(encryptedKey: encPK), privateKey.isEmpty == false {
                    try self.initDecryptRSA(privateKey: privateKey)

                    return privateKey
                }
            }
            return nil
        }
        return privateKey
    }

    private func decryptKeyWithAesKeyFromFile(encryptedKey: String) throws -> String? {
        if self !== CryptoHelper.sharedInstance {
            return nil
        }
        let aesKey = try self.aesKeyFromFile(forPasswordProtectedKey: false)
        let decCrypt = try CkoCrypt2.cryptDefault()
        decCrypt.setEncodedKey(aesKey, encoding: "hex")
        decCrypt.setEncodedIV(try self.hashForIV(), encoding: "hex")
        guard let decryptedString = decCrypt.decryptStringENC(encryptedKey), decryptedString.isEmpty == false else {
            throw DPAGErrorCrypto.errEncryption("err_password_wrong" + decCrypt.lastErrorText)
        }
        guard decryptedString.lowercased().hasPrefix("<RSAKeyValue>".lowercased()) else {
            throw DPAGErrorCrypto.errEncryption("err_password_wrong" + decCrypt.lastErrorText)
        }
        return decryptedString
    }

    private func encryptKeyWithAesKeyFromFile(decryptedKey _: String) -> String? {
        nil
    }

    private func deleteAllPrivateKeys() {
        self.kcWrapperForENC?.resetKeychainItem()
        self.kcWrapperForENC = nil
        self.kcWrapper?.resetKeychainItem()
        self.kcWrapper = nil
        let kcWrapperOldBackUp = KeychainWrapper(identifier: CryptoHelperExtended.KEYCHAIN_IDENTIFIER_PRIVATE_KEY_ENC_MOVEABLE_DL, accessGroup: nil, isThisDeviceOnly: false)
        kcWrapperOldBackUp?.resetKeychainItem()
    }

    private func setPasswordProtectedPrivateKey(key: String) {
        self.kcWrapperForENC?.setPassword(key)
        self.passwordProtectedPrivateKeyIntern = key
    }

    private func setSalt(salt: String) {
        self.kcWrapperForENC?.setUser(salt)
        self.saltForPrivateKey = salt
    }

    private let queueKeys: DispatchQueue = DispatchQueue(label: "de.dpag.simsme.CryptoHelper.queueKeys", qos: .default, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil)
}

extension CryptoHelper {
    func decryptAesKeyAsDict(with key: SIMSKey) throws -> [AnyHashable: Any] {
        guard let keyGuid = key.guid, let keyDeviceGuid = key.device_guid, let keyAesKey = key.aes_key else {
            throw DPAGErrorCrypto.errSIMSKey
        }
        let keyIdent = String(format: "%@#%@", keyGuid, keyDeviceGuid)
        // for whatever reason, at least in 3.6.1, either self or self.decrpytedKeyCache was pointing to a garbage pointer:
        // EXC_BAD_ACCESS
        // count > tionCompanionBundleConfiguration >
        // Attempted to dereference garbage pointer 0x10.
        // DISCUSSION:
        // We need to first check whether (a)  decryptedKeyCache is empty and (b) whether it contains the object
        // with the key "keyIdent". Only if bot checks are true, can we continue. And since this needs to be Objective-C bridged,
        // it is a little diferent than normally. Normally, a let retVal: [AnyHashable: Any]? = self.decryptedKeyCache[keyIdent]
        // and then check for retVal != nil would be enough. But when assigning, for whatever reason, it seems to require
        // non-optional type
        if self.decryptedKeyCache.isEmpty == false, self.decryptedKeyCache[keyIdent] != nil, let retVal = self.decryptedKeyCache[keyIdent] {
            return retVal
        }
        if let returnValue = try self.decryptAesKeyAsDict(encryptedAesKey: keyAesKey) {
            self.queueKeys.async(flags: .barrier) {
                self.decryptedKeyCache[keyIdent] = returnValue
            }
            return returnValue
        }
        throw DPAGErrorCrypto.errCrypt
    }

    func decrypt(encryptedString: String, with key: SIMSKey) throws -> Data {
        let dict = try self.decryptAesKeyAsDict(with: key)
        return try CryptoHelperDecrypter.decrypt(encryptedString: encryptedString, withAesKeyDict: dict)
    }

    func decryptToString(encryptedString: String, with key: SIMSKey) throws -> String {
        let dict = try self.decryptAesKeyAsDict(with: key)
        return try CryptoHelperDecrypter.decryptToString(encryptedString: encryptedString, withAesKeyDict: dict)
    }

    func decryptToStringNoFault(encryptedString: String, with key: SIMSKey) -> String? {
        do {
            return try self.decryptToString(encryptedString: encryptedString, with: key)
        } catch {
            DPAGLog(error, message: "Error decrypting")
            return nil
        }
    }

    func encrypt(string: String, with key: SIMSKey) throws -> String {
        let dict = try self.decryptAesKeyAsDict(with: key)
        return try CryptoHelperEncrypter.encrypt(string: string, withAesKeyDict: dict)
    }
}

public struct DPAGCryptoHelper {
    private init() {}
    static let lock = NSObject()

    private static var cryptoInstance: CryptoHelperAccount?

    public static func initAccount() {
        _ = self.newAccountCrypto()
    }

    static func newAccountCrypto() -> CryptoHelperAccount? {
        DPAGFunctionsGlobal.synchronized(lock) {
            if self.cryptoInstance == nil {
                do {
                    try DPAGApplicationFacade.persistance.loadWithError { localContext in
                        guard let account = SIMSAccount.mr_findFirst(in: localContext), let accountGuid = account.guid, let contact = SIMSContactIndexEntry.findFirst(byGuid: accountGuid, in: localContext) else {
                            return
                        }
                        guard let accountPrivateKey = account.privateKey, let publicKey = contact.publicKey else { return }
                        let accountCrypto = try CryptoHelperAccount(publicKey: publicKey, privateKey: accountPrivateKey)
                        self.cryptoInstance = accountCrypto
                    }
                } catch {
                    DPAGLog(error, message: "Error creating AccountCrypto")
                }
            }
        }
        return self.cryptoInstance
    }

    static func resetAccountCrypto() {
        DPAGFunctionsGlobal.synchronized(lock) {
            self.cryptoInstance = nil
        }
    }
}
