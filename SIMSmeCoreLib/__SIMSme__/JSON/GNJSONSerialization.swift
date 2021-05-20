//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

// File Based JSON Serialization

import Foundation

extension GNJSONSerialization {
    public struct ReadingOptions: OptionSet {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        
        public static let mutableContainers = ReadingOptions(rawValue: 1 << 0)
        public static let mutableLeaves = ReadingOptions(rawValue: 1 << 1)
        
        public static let fragmentsAllowed = ReadingOptions(rawValue: 1 << 2)
        @available(swift, deprecated: 100000, renamed: "JSONSerialization.ReadingOptions.fragmentsAllowed")
        public static let allowFragments = ReadingOptions(rawValue: 1 << 2)
    }

    public struct WritingOptions: OptionSet {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        
        public static let prettyPrinted = WritingOptions(rawValue: 1 << 0)
        public static let sortedKeys = WritingOptions(rawValue: 1 << 1)
        public static let fragmentsAllowed = WritingOptions(rawValue: 1 << 2)
        public static let withoutEscapingSlashes = WritingOptions(rawValue: 1 << 3)
    }
}

extension GNJSONSerialization {
    // Structures with container nesting deeper than this limit are not valid if passed in in-memory for validation, nor if they are read during deserialization.
    // This matches Darwin Foundation's validation behavior.
    fileprivate static let maximumRecursionDepth = 512
}

/* A class for converting JSON to Foundation/Swift objects and converting Foundation/Swift objects to JSON.
   
   An object that may be converted to JSON must have the following properties:
    - Top level object is a `Swift.Array` or `Swift.Dictionary`
    - All objects are `Swift.String`, `Foundation.NSNumber`, `Swift.Array`, `Swift.Dictionary`,
      or `Foundation.NSNull`
    - All dictionary keys are `Swift.String`s
    - `NSNumber`s are not NaN or infinity
*/

open class GNJSONSerialization: NSObject {
    
    /* Determines whether the given object can be converted to JSON.
       Other rules may apply. Calling this method or attempting a conversion are the definitive ways
       to tell if a given object can be converted to JSON data.
       - parameter obj: The object to test.
       - returns: `true` if `obj` can be converted to JSON, otherwise `false`.
     */
    open class func isValidJSONObject(_ obj: Any) -> Bool {
        var recursionDepth = 0
        
        // TODO: - revisit this once bridging story gets fully figured out
        func isValidJSONObjectInternal(_ obj: Any?) -> Bool {
            // Match Darwin Foundation in not considering a deep object valid.
            guard recursionDepth < GNJSONSerialization.maximumRecursionDepth else { return false }
            recursionDepth += 1
            defer { recursionDepth -= 1 }
            
            // Emulate the SE-0140 behavior bridging behavior for nils
            guard let obj = obj else {
                return true
            }
            
            if !(obj is NSNumber) {
              if obj is String || obj is NSNull || obj is Int || obj is Bool || obj is UInt ||
                  obj is Int8 || obj is Int16 || obj is Int32 || obj is Int64 ||
                  obj is UInt8 || obj is UInt16 || obj is UInt32 || obj is UInt64 {
                  return true
              }
            }

            // object is a Double and is not NaN or infinity
            if let number = obj as? Double  {
                return number.isFinite
            }
            // object is a Float and is not NaN or infinity
            if let number = obj as? Float  {
                return number.isFinite
            }

            if let number = obj as? Decimal {
                return number.isFinite
            }

            // object is Swift.Array
            if let array = obj as? [Any?] {
                for element in array {
                    guard isValidJSONObjectInternal(element) else {
                        return false
                    }
                }
                return true
            }

            // object is Swift.Dictionary
            if let dictionary = obj as? [String: Any?] {
                for (_, value) in dictionary {
                    guard isValidJSONObjectInternal(value) else {
                        return false
                    }
                }
                return true
            }

            // object is NSNumber and is not NaN or infinity
            // For better performance, this (most expensive) test should be last.
            if obj is NSNumber {
                return true
            }

            // invalid object
            return false
        }

        // top level object must be an Swift.Array or Swift.Dictionary
        guard obj is [Any?] || obj is [String: Any?] else {
            return false
        }

        return isValidJSONObjectInternal(obj)
    }
    
    /* Generate JSON data from a Foundation object. If the object will not produce valid JSON then an exception will be thrown. Setting the NSJSONWritingPrettyPrinted option will generate JSON with whitespace designed to make the output more readable. If that option is not set, the most compact possible JSON will be generated. If an error occurs, the error parameter will be set and the return value will be nil. The resulting data is a encoded in UTF-8.
     */
    internal class func _data(withJSONObject value: Any, options opt: WritingOptions, stream: Bool) throws -> String {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(DPAGFunctionsGlobal.uuid())
        var string = ""
        try "".write(to: url, atomically: true, encoding: .utf8)
        let fileHandle = try FileHandle(forWritingTo: url)
        var stringLength = 0
        var writer = GNJSONWriter(
            options: opt,
            writer: { [fileHandle] (str: String?) in
                if let str = str {
                    stringLength += str.count
                    string += str
                    if stringLength > 10_000_000 {
                        NSLog("Will Write \(stringLength) bytes to FileHandle \(fileHandle), ")
                        fileHandle.write(Data(string.utf8))
                        string = ""
                        stringLength = 0
                    }
                }
            }
        )
        
        if let container = value as? [Any] {
            try writer.serializeJSON(container)
        } else if let container = value as? [AnyHashable: Any] {
            try writer.serializeJSON(container)
        } else {
            guard opt.contains(.fragmentsAllowed) else {
                fatalError("Top-level object was not NSArray or NSDictionary") // This is a fatal error in objective-c too (it is an NSInvalidArgumentException)
            }
            try writer.serializeJSON(value)
        }
        if string != "" {
            fileHandle.write(Data(string.utf8))
            string = ""
            stringLength = 0
        }
        fileHandle.closeFile()
        string = try String(contentsOf: url, encoding: .utf8)
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
        }

        return string
    }

    open class func string(withJSONObject value: Any, options opt: WritingOptions = []) throws -> String {
        try _data(withJSONObject: value, options: opt, stream: false)
    }
    
    /* Create a Foundation object from JSON data. Set the NSJSONReadingAllowFragments option if the parser should allow top-level objects that are not an NSArray or NSDictionary. Setting the NSJSONReadingMutableContainers option will make the parser generate mutable NSArrays and NSDictionaries. Setting the NSJSONReadingMutableLeaves option will make the parser generate mutable NSString objects. If an error occurs during the parse, then the error parameter will be set and the result will be nil.
       The data must be in one of the 5 supported encodings listed in the JSON specification: UTF-8, UTF-16LE, UTF-16BE, UTF-32LE, UTF-32BE. The data may or may not have a BOM. The most efficient encoding to use for parsing is UTF-8, so if you have a choice in encoding the data passed to this method, use UTF-8.
     */
    open class func jsonObject(with data: Data, options opt: ReadingOptions = []) throws -> Any {
        do {
            let jsonValue = try data.withUnsafeBytes { (ptr) -> GNJSONValue in
                let (encoding, advanceBy) = GNJSONSerialization.detectEncoding(ptr)
                
                if encoding == .utf8 {
                    // we got utf8... happy path
                    var parser = GNJSONParser(bytes: Array(ptr[advanceBy..<ptr.count]))
                    return try parser.parse()
                }
                
                guard let utf8String = String(bytes: ptr[advanceBy..<ptr.count], encoding: encoding) else {
                    throw JSONError.cannotConvertInputDataToUTF8
                }
                
                var parser = GNJSONParser(bytes: Array(utf8String.utf8))
                return try parser.parse()
            }
            
            if jsonValue.isValue, !opt.contains(.fragmentsAllowed) {
                throw JSONError.singleFragmentFoundButNotAllowed
            }
            
            return try jsonValue.toObjcRepresentation(options: opt)
        } catch let error as JSONError {
            switch error {
            case .cannotConvertInputDataToUTF8:
                throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.propertyListReadCorrupt.rawValue, userInfo: [
                    NSDebugDescriptionErrorKey: "Cannot convert input string to valid utf8 input."
                ])
            case .unexpectedEndOfFile:
                throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.propertyListReadCorrupt.rawValue, userInfo: [
                    NSDebugDescriptionErrorKey: "Unexpected end of file during JSON parse."
                ])
            case .unexpectedCharacter(_, let characterIndex):
                throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.propertyListReadCorrupt.rawValue, userInfo: [
                    NSDebugDescriptionErrorKey: "Invalid value around character \(characterIndex)."
                ])
            case .expectedLowSurrogateUTF8SequenceAfterHighSurrogate:
                throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.propertyListReadCorrupt.rawValue, userInfo: [
                    NSDebugDescriptionErrorKey: "Unexpected end of file during string parse (expected low-surrogate code point but did not find one)."
                ])
            case .couldNotCreateUnicodeScalarFromUInt32:
                throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.propertyListReadCorrupt.rawValue, userInfo: [
                    NSDebugDescriptionErrorKey: "Unable to convert hex escape sequence (no high character) to UTF8-encoded character."
                ])
            case .unexpectedEscapedCharacter(_, _, let index):
                // we lower the failure index by one to match the darwin implementations counting
                throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.propertyListReadCorrupt.rawValue, userInfo: [
                    NSDebugDescriptionErrorKey: "Invalid escape sequence around character \(index - 1)."
                ])
            case .singleFragmentFoundButNotAllowed:
                throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.propertyListReadCorrupt.rawValue, userInfo: [
                    NSDebugDescriptionErrorKey: "JSON text did not start with array or object and option to allow fragments not set."
                ])
            case .tooManyNestedArraysOrDictionaries(characterIndex: let characterIndex):
                throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.propertyListReadCorrupt.rawValue, userInfo: [
                    NSDebugDescriptionErrorKey: "Too many nested arrays or dictionaries around character \(characterIndex + 1)."
                ])
            case .invalidHexDigitSequence(let string, index: let index):
                throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.propertyListReadCorrupt.rawValue, userInfo: [
                    NSDebugDescriptionErrorKey: #"Invalid hex encoded sequence in "\#(string)" at \#(index)."#
                ])
            case .unescapedControlCharacterInString(ascii: let ascii, in: _, index: let index) where ascii == UInt8(ascii: "\\"):
                throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.propertyListReadCorrupt.rawValue, userInfo: [
                    NSDebugDescriptionErrorKey: #"Invalid escape sequence around character \#(index)."#
                ])
            case .unescapedControlCharacterInString(ascii: _, in: _, index: let index):
                throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.propertyListReadCorrupt.rawValue, userInfo: [
                    NSDebugDescriptionErrorKey: #"Unescaped control character around character \#(index)."#
                ])
            case .numberWithLeadingZero(index: let index):
                throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.propertyListReadCorrupt.rawValue, userInfo: [
                    NSDebugDescriptionErrorKey: #"Number with leading zero around character \#(index)."#
                ])
            case .numberIsNotRepresentableInSwift(parsed: let parsed):
                throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.propertyListReadCorrupt.rawValue, userInfo: [
                    NSDebugDescriptionErrorKey: #"Number \#(parsed) is not representable in Swift."#
                ])
            }
        } catch {
            preconditionFailure("Only `JSONError` expected")
        }
        
    }
    
    /* Create a JSON object from JSON data stream. The stream should be opened and configured. All other behavior of this method is the same as the JSONObjectWithData:options:error: method.
     */
    open class func jsonObject(with stream: InputStream, options opt: ReadingOptions = []) throws -> Any {
        var data = Data()
        guard stream.streamStatus == .open || stream.streamStatus == .reading else {
            fatalError("Stream is not available for reading")
        }
        repeat {
            let buffer = try [UInt8](unsafeUninitializedCapacity: 1_024) { buf, initializedCount in
                let bytesRead = stream.read(buf.baseAddress!, maxLength: buf.count)
                initializedCount = bytesRead
                guard bytesRead >= 0 else {
                    throw stream.streamError!
                }
            }
            data.append(buffer, count: buffer.count)
        } while stream.hasBytesAvailable
        return try jsonObject(with: data, options: opt)
    }
}

// MARK: - Encoding Detection

private extension GNJSONSerialization {
    /// Detect the encoding format of the NSData contents
    static func detectEncoding(_ bytes: UnsafeRawBufferPointer) -> (String.Encoding, Int) {
        // According to RFC8259, the text encoding in JSON must be UTF8 in nonclosed systems
        // https://tools.ietf.org/html/rfc8259#section-8.1
        // However, since Darwin Foundation supports utf16 and utf32, so should Swift Foundation.
        
        // First let's check if we can determine the encoding based on a leading Byte Ordering Mark
        // (BOM).
        if bytes.count >= 4 {
            if bytes.starts(with: Self.utf8BOM) {
                return (.utf8, 3)
            }
            if bytes.starts(with: Self.utf32BigEndianBOM) {
                return (.utf32BigEndian, 4)
            }
            if bytes.starts(with: Self.utf32LittleEndianBOM) {
                return (.utf32LittleEndian, 4)
            }
            if bytes.starts(with: [0xFF, 0xFE]) {
                return (.utf16LittleEndian, 2)
            }
            if bytes.starts(with: [0xFE, 0xFF]) {
                return (.utf16BigEndian, 2)
            }
        }
        
        // If there is no BOM present, we might be able to determine the encoding based on
        // occurences of null bytes.
        if bytes.count >= 4 {
            switch (bytes[0], bytes[1], bytes[2], bytes[3]) {
            case (0, 0, 0, _):
                return (.utf32BigEndian, 0)
            case (_, 0, 0, 0):
                return (.utf32LittleEndian, 0)
            case (0, _, 0, _):
                return (.utf16BigEndian, 0)
            case (_, 0, _, 0):
                return (.utf16LittleEndian, 0)
            default:
                break
            }
        }
        else if bytes.count >= 2 {
            switch (bytes[0], bytes[1]) {
            case (0, _):
                return (.utf16BigEndian, 0)
            case (_, 0):
                return (.utf16LittleEndian, 0)
            default:
                break
            }
        }
        return (.utf8, 0)
    }
    
    static func parseBOM(_ bytes: UnsafeRawBufferPointer) -> (encoding: String.Encoding, skipLength: Int)? {
         nil
    }
    
    // These static properties don't look very nice, but we need them to
    // workaround: https://bugs.swift.org/browse/SR-14102
    private static let utf8BOM: [UInt8] = [0xEF, 0xBB, 0xBF]
    private static let utf32BigEndianBOM: [UInt8] = [0x00, 0x00, 0xFE, 0xFF]
    private static let utf32LittleEndianBOM: [UInt8] = [0xFF, 0xFE, 0x00, 0x00]
    private static let utf16BigEndianBOM: [UInt8] = [0xFF, 0xFE]
    private static let utf16LittleEndianBOM: [UInt8] = [0xFE, 0xFF]
}

// MARK: - GNJSONSerializer
private struct GNJSONWriter {

    var indent = 0
    let pretty: Bool
    let sortedKeys: Bool
    let withoutEscapingSlashes: Bool
    let writer: (String?) -> Void

    init(options: GNJSONSerialization.WritingOptions, writer: @escaping (String?) -> Void) {
        pretty = options.contains(.prettyPrinted)
        sortedKeys = options.contains(.sortedKeys)
        withoutEscapingSlashes = options.contains(.withoutEscapingSlashes)
        self.writer = writer
    }
    
    mutating func serializeJSON(_ object: Any?) throws {
        guard let obj = object else {
            try serializeNull()
            return
        }
        // For better performance, the most expensive conditions to evaluate should be last.
        switch obj {
            case let str as String:
                try serializeString(str)
            case let boolValue as Bool:
                writer(boolValue.description)
            case let num as Int:
                writer(num.description)
            case let num as Int8:
                writer(num.description)
            case let num as Int16:
                writer(num.description)
            case let num as Int32:
                writer(num.description)
            case let num as Int64:
                writer(num.description)
            case let num as UInt:
                writer(num.description)
            case let num as UInt8:
                writer(num.description)
            case let num as UInt16:
                writer(num.description)
            case let num as UInt32:
                writer(num.description)
            case let num as UInt64:
                writer(num.description)
            case let array as [Any?]:
                try serializeArray(array)
            case let dict as [AnyHashable: Any?]:
                try serializeDictionary(dict)
            case let num as Float:
                try serializeFloat(num)
            case let num as Double:
                try serializeFloat(num)
            case let num as Decimal:
                writer(num.description)
            case let num as NSDecimalNumber:
                writer(num.description)
            case is NSNull:
                try serializeNull()
            default:
                throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.propertyListReadCorrupt.rawValue, userInfo: [NSDebugDescriptionErrorKey: "Invalid object cannot be serialized"])
        }
    }

    func serializeString(_ str: String) throws {
        writer("\"")
        for scalar in str.unicodeScalars {
            switch scalar {
                case "\"":
                    writer("\\\"") // U+0022 quotation mark
                case "\\":
                    writer("\\\\") // U+005C reverse solidus
                case "/":
                    if !withoutEscapingSlashes { writer("\\") }
                    writer("/") // U+002F solidus
                case "\u{8}":
                    writer("\\b") // U+0008 backspace
                case "\u{c}":
                    writer("\\f") // U+000C form feed
                case "\n":
                    writer("\\n") // U+000A line feed
                case "\r":
                    writer("\\r") // U+000D carriage return
                case "\t":
                    writer("\\t") // U+0009 tab
                case "\u{0}"..."\u{f}":
                    writer("\\u000\(String(scalar.value, radix: 16))") // U+0000 to U+000F
                case "\u{10}"..."\u{1f}":
                    writer("\\u00\(String(scalar.value, radix: 16))") // U+0010 to U+001F
                default:
                    writer(String(scalar))
            }
        }
        writer("\"")
    }

    private func serializeFloat<T: FloatingPoint & LosslessStringConvertible>(_ num: T) throws {
        guard num.isFinite else {
             throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.propertyListReadCorrupt.rawValue, userInfo: [NSDebugDescriptionErrorKey: "Invalid number value (\(num)) in JSON write"])
        }
        var str = num.description
        if str.hasSuffix(".0") {
            str.removeLast(2)
        }
        writer(str)
    }

    mutating func serializeArray(_ array: [Any?]) throws {
        NSLog("GNJSONSerialization:: Array")
        writer("[")
        if pretty {
            writer("\n")
            incIndent()
        }
        
        var first = true
        for elem in array {
            if first {
                first = false
            } else if pretty {
                writer(",\n")
            } else {
                writer(",")
            }
            if pretty {
                writeIndent()
            }
            try serializeJSON(elem)
        }
        if pretty {
            writer("\n")
            decAndWriteIndent()
        }
        writer("]")
    }

    mutating func serializeDictionary(_ dict: [AnyHashable: Any?]) throws {
        NSLog("GNJSONSerialization:: Dictionary")
        writer("{")
        if pretty {
            writer("\n")
            incIndent()
            if dict.count > 0 {
                writeIndent()
            }
        }

        var first = true

        func serializeDictionaryElement(key: AnyHashable, value: Any?) throws {
            if first {
                first = false
            } else if pretty {
                writer(",\n")
                writeIndent()
            } else {
                writer(",")
            }

            if let key = key as? String {
                try serializeString(key)
            } else {
                throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.propertyListReadCorrupt.rawValue, userInfo: [NSDebugDescriptionErrorKey: "NSDictionary key must be NSString"])
            }
            pretty ? writer(" : ") : writer(":")
            try serializeJSON(value)
        }

        if sortedKeys {
            let elems = try dict.sorted(by: { a, b in
                guard let a = a.key as? String,
                    let b = b.key as? String else {
                        throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.propertyListReadCorrupt.rawValue, userInfo: [NSDebugDescriptionErrorKey: "NSDictionary key must be NSString"])
                }
                let options: NSString.CompareOptions = [.numeric, .caseInsensitive, .forcedOrdering]
                let range: Range<String.Index>  = a.startIndex..<a.endIndex
                let locale = NSLocale.system

                return a.compare(b, options: options, range: range, locale: locale) == .orderedAscending
            })
            for elem in elems {
                try serializeDictionaryElement(key: elem.key, value: elem.value)
            }
        } else {
            for (key, value) in dict {
                try serializeDictionaryElement(key: key, value: value)
            }
        }

        if pretty {
            writer("\n")
            decAndWriteIndent()
        }
        writer("}")
    }

    func serializeNull() throws {
        writer("null")
    }
    
    let indentAmount = 2

    mutating func incIndent() {
        indent += indentAmount
    }

    mutating func incAndWriteIndent() {
        indent += indentAmount
        writeIndent()
    }
    
    mutating func decAndWriteIndent() {
        indent -= indentAmount
        writeIndent()
    }
    
    func writeIndent() {
        for _ in 0..<indent {
            writer(" ")
        }
    }

}

enum GNJSONValue: Equatable {
    case string(String)
    case number(String)
    case bool(Bool)
    case null

    case array([GNJSONValue])
    case object([String: GNJSONValue])
}

extension GNJSONValue {
    var isValue: Bool {
        switch self {
        case .array, .object:
            return false
        case .null, .number, .string, .bool:
            return true
        }
    }
    
    var isContainer: Bool {
        switch self {
        case .array, .object:
            return true
        case .null, .number, .string, .bool:
            return false
        }
    }
}

extension GNJSONValue {
    var debugDataTypeDescription: String {
        switch self {
        case .array:
            return "an array"
        case .bool:
            return "bool"
        case .number:
            return "a number"
        case .string:
            return "a string"
        case .object:
            return "a dictionary"
        case .null:
            return "null"
        }
    }
}

private extension GNJSONValue {
    func toObjcRepresentation(options: GNJSONSerialization.ReadingOptions) throws -> Any {
        switch self {
        case .array(let values):
            let array = try values.map { try $0.toObjcRepresentation(options: options) }
            if !options.contains(.mutableContainers) {
                return array
            }
            return NSMutableArray(array: array, copyItems: false)
        case .object(let object):
            let dictionary = try object.mapValues { try $0.toObjcRepresentation(options: options) }
            if !options.contains(.mutableContainers) {
                return dictionary
            }
            return NSMutableDictionary(dictionary: dictionary, copyItems: false)
        case .bool(let bool):
            return NSNumber(value: bool)
        case .number(let string):
            guard let number = NSNumber.fromJSONNumber(string) else {
                throw JSONError.numberIsNotRepresentableInSwift(parsed: string)
            }
            return number
        case .null:
            return NSNull()
        case .string(let string):
            if options.contains(.mutableLeaves) {
                return NSMutableString(string: string)
            }
            return string
        }
    }
}

extension NSNumber {
    static func fromJSONNumber(_ string: String) -> NSNumber? {
        let decIndex = string.firstIndex(of: ".")
        let expIndex = string.firstIndex(of: "e")
        let isInteger = decIndex == nil && expIndex == nil
        let isNegative = string.utf8[string.utf8.startIndex] == UInt8(ascii: "-")
        let digitCount = string[string.startIndex..<(expIndex ?? string.endIndex)].count
        
        // Try Int64() or UInt64() first
        if isInteger {
            if isNegative {
                if digitCount <= 19, let intValue = Int64(string) {
                    return NSNumber(value: intValue)
                }
            } else {
                if digitCount <= 20, let uintValue = UInt64(string) {
                    return NSNumber(value: uintValue)
                }
            }
        }

        var exp = 0
        
        if let expIndex = expIndex {
            let expStartIndex = string.index(after: expIndex)
            if let parsed = Int(string[expStartIndex...]) {
                exp = parsed
            }
        }
        
        // Decimal holds more digits of precision but a smaller exponent than Double
        // so try that if the exponent fits and there are more digits than Double can hold
        if digitCount > 17, exp >= -128, exp <= 127, let decimal = Decimal(string: string), decimal.isFinite {
            return NSDecimalNumber(decimal: decimal)
        }
        
        // Fall back to Double() for everything else
        if let doubleValue = Double(string), doubleValue.isFinite {
            return NSNumber(value: doubleValue)
        }
        
        return nil
    }
}
