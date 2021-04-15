//
//  XMLWriter.swift
//  SIMSmeCore
//
//  Created by Robert Burchert on 27.02.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation

public class XMLWriter: NSObject {
    private var nodes: [Int] = []
    private var xml: String = ""
    private var treeNodes: [String] = []
    private var isRoot = false

    private func serialize(root: Any) {
        if let rootArr = root as? [Any] {
            var mula = rootArr.count

            mula -= 1

            self.nodes.append(mula)

            for objects in rootArr {
                if self.nodes.last == 0 || self.nodes.last == nil || self.nodes.isEmpty {
                    self.nodes.removeLast()
                    self.serialize(root: objects)
                } else {
                    self.serialize(root: objects)

                    if self.isRoot == false {
                        if let last = self.treeNodes.last {
                            self.xml = self.xml.appendingFormat("</%@><%@>", last, last)
                        }
                    } else {
                        self.isRoot = false
                    }

                    var value = self.nodes.last ?? 0

                    self.nodes.removeLast()

                    value -= 1

                    self.nodes.append(value)
                }
            }
        } else if let rootDict = root as? [String: Any] {
            for (key, value) in rootDict {
                if self.isRoot == false {
                    // NSLog(@"We came in");
                    self.treeNodes.append(key)
                    self.xml = self.xml.appendingFormat("<%@>", key)
                    self.serialize(root: value)
                    self.xml = self.xml.appendingFormat("</%@>", key)

                    self.treeNodes.removeLast()
                } else {
                    self.isRoot = false

                    self.serialize(root: value)
                }
            }
        } else if root is String || root is NSNumber || root is URL {
            // if ([root hasPrefix:"PREFIX_STRING_FOR_ELEMENT"])
            // is element
            // else
            self.xml = self.xml.appending("\(root)")
        }
    }

    private func serializeDict(dict: [String: String]) {
        let keys = dict.keys

        self.xml = ""

        let sortedKeys = keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        for key in sortedKeys {
            guard let value = dict[key] else {
                continue
            }

            // austauschen
            let valueReplaced = value.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "\"", with: "&quot;").replacingOccurrences(of: "'", with: "&#39;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "<", with: "&lt;")

            self.xml = self.xml.appendingFormat("<data name=\"%@\">%@</data>", key, valueReplaced)
        }
    }

    private init(dictionary: [String: String]) {
        super.init()

        self.serializeDict(dict: dictionary)
    }

    private func getXML() -> String {
        // xml = [xml stringByReplacingOccurrencesOfString:@"</(null)><(null)>" withString:@"\n"];
        // xml = [xml stringByAppendingFormat:@"\n</%@>",passDict];
        return self.xml
    }

    public static func xmlString(from dictionary: [String: String]) -> String {
        if dictionary.isEmpty {
            return ""
        }

        let fromDictionary = XMLWriter(dictionary: dictionary)

        return fromDictionary.getXML()
    }
}
