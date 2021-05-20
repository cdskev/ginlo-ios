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

//    func encode<T>(_ value: T) throws -> [String: Any] where T: Encodable {
//        let url = try GNJSONSerialization.url(withJSONObject: value, options: [.fragmentsAllowed])
//        if let stream = InputStream(url: url) {
//            stream.open()
//            let jsonObject = try JSONSerialization.jsonObject(with: stream, options: .allowFragments)
//            guard let jsonDict = jsonObject as? [String: Any] else {
//                stream.close()
//                do {
//                    try FileManager.default.removeItem(at: url)
//                } catch {
//                }
//                throw DictionaryEncoderError.errDictType
//            }
//            stream.close()
//            do {
//                try FileManager.default.removeItem(at: url)
//            } catch {
//            }
//            return jsonDict
//        }
//        throw DictionaryEncoderError.errDictType
//    }

    func encode<T>(_ value: T) throws -> [String: Any] where T: Encodable {
        let data = try encoder.encode(value)

        let jsonObject = try JSONSerialization.jsonObject(with: data, options: .allowFragments)

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
