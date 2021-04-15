//
//  XMLReader.swift
//  SIMSmeCore
//
//  Created by Robert Burchert on 27.02.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation

class XMLReader: NSObject {
    private static let kXMLReaderTextNodeKey = "text"

    private var textInProgress: NSMutableString = NSMutableString()
    private var dataValues: [String: String] = [:]

    private var parserError: Error?

    var dataKey: String?

    static func dictionary(forXMLData data: Data) throws -> [String: Any]? {
        let reader = XMLReader()

        let rootDictionary = reader.object(with: data)

        if let error = reader.parserError {
            throw error
        }

        return rootDictionary
    }

    static func dictionary(forXMLString string: String) throws -> [String: Any]? {
        let xmlString = String(format: "<?xml version=\"1.0\" encoding=\"UTF-8\" ?><helptag>%@</helptag>", string)

        guard let data = xmlString.data(using: .utf8) else {
            return nil
        }

        return try self.dictionary(forXMLData: data)
    }

    override private init() {
        super.init()
    }

    private func object(with data: Data) -> [String: Any]? {
        // Clear out any old data

        // dictionaryStack = [[NSMutableArray alloc] init];
        self.textInProgress = NSMutableString()

        // Initialize the stack with a fresh dictionary
        // [dictionaryStack addObject:[NSMutableDictionary dictionary]];

        //
        self.dataValues = [:]

        // Parse the XML
        let parser = XMLParser(data: data)

        parser.delegate = self

        let success = parser.parse()

        if self.parserError == nil {
            self.parserError = parser.parserError
        }

        if success {
            return self.dataValues
        }

        return nil
    }
}

extension XMLReader: XMLParserDelegate {
    func parser(_: XMLParser, didStartElement elementName: String, namespaceURI _: String?, qualifiedName _: String?, attributes attributeDict: [String: String] = [:]) {
        if elementName == "data", attributeDict.isEmpty == false {
            if self.dataKey == nil {
                self.dataKey = attributeDict["name"]
            }
        }
    }

    func parser(_: XMLParser, didEndElement elementName: String, namespaceURI _: String?, qualifiedName _: String?) {
        if elementName == "data" {
            if self.textInProgress.length > 0, let dataKey = self.dataKey {
                dataValues[dataKey] = self.textInProgress as String

                self.textInProgress = NSMutableString()
            }

            self.dataKey = nil
        }
    }

    func parser(_: XMLParser, foundCharacters string: String) {
        if self.dataKey != nil {
            self.textInProgress.append(string)
        }
    }

    func parser(_: XMLParser, parseErrorOccurred parseError: Error) {
        self.parserError = parseError
    }
}
