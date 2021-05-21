//
//  DictionaryCoding.swift
//  SIMSmeCore
//
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

class DictionaryEncoder {
    public enum DictionaryEncoderError: Error {
        case errDictType
    }

    private let encoder = JSONEncoder()

    var dateEncodingStrategy: JSONEncoder.DateEncodingStrategy {
        get { encoder.dateEncodingStrategy }
        set { encoder.dateEncodingStrategy = newValue }
    }

    var dataEncodingStrategy: JSONEncoder.DataEncodingStrategy {
        get { encoder.dataEncodingStrategy }
        set { encoder.dataEncodingStrategy = newValue }
    }

    var nonConformingFloatEncodingStrategy: JSONEncoder.NonConformingFloatEncodingStrategy {
        get { encoder.nonConformingFloatEncodingStrategy }
        set { encoder.nonConformingFloatEncodingStrategy = newValue }
    }

    var keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy {
        get { encoder.keyEncodingStrategy }
        set { encoder.keyEncodingStrategy = newValue }
    }

    func dumpJSON(json: [AnyHashable: Any], blanks: String? = "") {
        for (key, value) in json {
            let vType = type(of: value)
            if let blanks = blanks {
                NSLog("\(blanks) json->key => \(key); valueType = \(vType)")
                if let value = value as? [AnyHashable: Any] {
                    dumpJSON(json: value, blanks: blanks + "   ")
                }
            }
        }
    }
    
    func unwrappedJSONObject(with data: Data, options: JSONSerialization.ReadingOptions = []) throws -> Any {
        let maybeString = try JSONSerialization.jsonObject(with: data, options: options)
        if let actualString = maybeString as? String {
            return try JSONSerialization.jsonObject(with: Data(actualString.utf8), options: options)
        }
        return maybeString
    }

    func encode<T>(_ value: T) throws -> [String: Any] where T: Encodable {
        var valueSize = 0
        switch value {
            case let spm as DPAGServerFunction.SendPrivateMessage:
                valueSize = spm.message.count
            case let sgm as DPAGServerFunction.SendGroupMessage:
                valueSize = sgm.message.count
            case let spim as DPAGServerFunction.SendPrivateInternalMessage:
                valueSize = spim.message.count
            case let stpm as DPAGServerFunction.SendTimedPrivateMessage:
                valueSize = stpm.message.count
            case let stgm as DPAGServerFunction.SendTimedGroupMessage:
                valueSize = stgm.message.count
            case let spims as DPAGServerFunction.SendPrivateInternalMessages:
                valueSize = spims.message.count
            default:
                valueSize = 0
        }
        NSLog("IMDAT:: valueSize in Encode = \(valueSize)")
        var jsonObject: Any?
        if DPAGHelper.canPerformRAMBasedJSON(ofSize: UInt(valueSize)) {
            // use RAM-based encoding
            let data = try encoder.encode(value)
            jsonObject = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
        } else {
            // use Disk-based encoding
            let data = try GNJSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed])
            jsonObject = try unwrappedJSONObject(with: data, options: .allowFragments)
        }
        guard let jsonDict = jsonObject as? [String: Any] else {
            throw DictionaryEncoderError.errDictType
        }
        return jsonDict
    }
}

class DictionaryDecoder {
    private let decoder = JSONDecoder()

    var dateDecodingStrategy: JSONDecoder.DateDecodingStrategy {
        get { decoder.dateDecodingStrategy }
        set { decoder.dateDecodingStrategy = newValue }
    }

    var dataDecodingStrategy: JSONDecoder.DataDecodingStrategy {
        get { decoder.dataDecodingStrategy }
        set { decoder.dataDecodingStrategy = newValue }
    }

    var nonConformingFloatDecodingStrategy: JSONDecoder.NonConformingFloatDecodingStrategy {
        get { decoder.nonConformingFloatDecodingStrategy }
        set { decoder.nonConformingFloatDecodingStrategy = newValue }
    }

    var keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy {
        get { decoder.keyDecodingStrategy }
        set { decoder.keyDecodingStrategy = newValue }
    }

    func decode<T>(_ type: T.Type, from dictionary: [AnyHashable: Any]) throws -> T where T: Decodable {
        let data = try JSONSerialization.data(withJSONObject: dictionary, options: [])
        return try decoder.decode(type, from: data)
    }
}

class DictionaryArrayDecoder {
    private let decoder = JSONDecoder()

    var dateDecodingStrategy: JSONDecoder.DateDecodingStrategy {
        get { decoder.dateDecodingStrategy }
        set { decoder.dateDecodingStrategy = newValue }
    }

    var dataDecodingStrategy: JSONDecoder.DataDecodingStrategy {
        get { decoder.dataDecodingStrategy }
        set { decoder.dataDecodingStrategy = newValue }
    }

    var nonConformingFloatDecodingStrategy: JSONDecoder.NonConformingFloatDecodingStrategy {
        get { decoder.nonConformingFloatDecodingStrategy }
        set { decoder.nonConformingFloatDecodingStrategy = newValue }
    }

    var keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy {
        get { decoder.keyDecodingStrategy }
        set { decoder.keyDecodingStrategy = newValue }
    }

    func decode<T>(_ type: T.Type, from dictionaryArray: [[AnyHashable: Any]]) throws -> T where T: Decodable {
        let data = try JSONSerialization.data(withJSONObject: dictionaryArray, options: [])
        return try decoder.decode(type, from: data)
    }
}
