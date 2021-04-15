//
//  DPAGRuntimeConfigWhiteLabel.swift
//  SIMSme
//
//  Created by RBU on 10/01/2017.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGRuntimeConfigWhiteLabel: DPAGRuntimeConfigUI {
    // Muss fuer jede Config XML Anpassung manuell gesetzt werden
    static let CONFIG_CHECKSUM_MAX_ME = "5a44b78b2db48ac79a458c4b0eb6ce70"
    static let CONFIG_CHECKSUM_BA = "7e8677e21bd3cc0afecd6fcec455d215"

    fileprivate static let kConfigMandantKey = "mandant"
    fileprivate static let kConfigSaltKey = "salt"
    fileprivate static let kConfigOptionsKey = "options"
    fileprivate static let kConfigIdentKey = "ident"
    fileprivate static let kConfigLabelKey = "label"
    fileprivate static let kConfigOptionsDataKey = "data"
    fileprivate static let kConfigOptionsDataNameKey = "name"
    fileprivate static let kConfigValueKey = "text"
    fileprivate static let kConfigOptionChannelKey = "allowChannels"
    fileprivate static let kConfigOptionServiceKey = "allowServices"
    fileprivate static let kConfigOptionUrlScheme = "urlScheme"
    fileprivate static let kConfigOptionExportChatKey = "isExportChatAllow"

    var configDict: [AnyHashable: Any]?
    var canShowChannels: Bool?
    var canShowServices: Bool?
    var canExportChats: Bool?

    override init() {
        super.init()
        if let configUrl = Bundle.main.url(forResource: "config", withExtension: "xml") {
            if let xmlData = try? Data(contentsOf: configUrl) {
                let configChecksum = self.configChecksum
                do {
                    let checksum = try CryptoHelperCoding.shared.md5Hash(value: xmlData)
                    if configChecksum == nil || checksum != configChecksum {
                        abort()
                    }
                    self.configDict = try DPAGXmlReader.dictionary(forXMLData: xmlData)
                    _ = self.isChatExportAllowed
                    _ = self.isChannelsAllowed
                    _ = self.isServicesAllowed
                } catch {
                    DPAGLog(error, message: "XML Config could not read")
                }
            }
        }
    }

    override var trackingAppToken: String? {
        nil
    }

    override func trackingEventId(eventId: String) -> String {
        String(format: "%@-%@", self.mandantIdent ?? "default", eventId)
    }

    override var urlScheme: String {
        if let urlScheme = self.urlSchemeInternal {
            switch AppConfig.buildConfigurationMode {
                case .ADHOC, .BETA, .DEBUG, .TEST:
                    return String(format: "%@%@", urlScheme, "debug")
                case .RELEASE:
                    return urlScheme
            }
        }
        return super.urlScheme
    }

    fileprivate var _urlSchemeInternal: String?

    fileprivate var urlSchemeInternal: String? {
        if self._urlSchemeInternal == nil {
            self._urlSchemeInternal = self.configValueForKey(DPAGRuntimeConfigWhiteLabel.kConfigOptionUrlScheme, isOptionsValue: true)
        }
        return self._urlSchemeInternal
    }

    override var isWhiteLabelBuild: Bool {
        true
    }

    fileprivate var _saltClient: String?

    override var saltClient: String {
        if self._saltClient == nil {
            self._saltClient = self.configValueForKey(DPAGRuntimeConfigWhiteLabel.kConfigSaltKey, isOptionsValue: false)
        }
        return self._saltClient ?? super.saltClient
    }

    override var isChatExportAllowed: Bool {
        if let canExportChats = self.canExportChats {
            return canExportChats
        } else {
            var boolValue: Bool?
            if let value = self.configValueForKey(DPAGRuntimeConfigWhiteLabel.kConfigOptionExportChatKey, isOptionsValue: true) {
                boolValue = value == "true"
            }
            self.canExportChats = boolValue
            return boolValue ?? true
        }
    }

    // Default is YES
    override var isChannelsAllowed: Bool {
        if let canShowChannels = self.canShowChannels {
            return canShowChannels
        } else {
            var boolValue: Bool?
            if let value = self.configValueForKey(DPAGRuntimeConfigWhiteLabel.kConfigOptionChannelKey, isOptionsValue: true) {
                boolValue = value != "false"
            }
            self.canShowChannels = boolValue
            return boolValue ?? true
        }
    }

    override var isServicesAllowed: Bool {
        false
    }

    fileprivate var _mandantIdent: String?

    override var mandantIdent: String? {
        if self._mandantIdent == nil {
            self._mandantIdent = self.configValueForKey(DPAGRuntimeConfigWhiteLabel.kConfigIdentKey, isOptionsValue: false)
        }
        return self._mandantIdent
    }

    fileprivate var _mandantLabel: String?

    override var mandantLabel: String? {
        if self._mandantLabel == nil {
            self._mandantLabel = self.configValueForKey(DPAGRuntimeConfigWhiteLabel.kConfigLabelKey, isOptionsValue: false)
        }
        return self._mandantLabel
    }

    override var isBaMandant: Bool {
        false
    }

    var configChecksum: String? {
        nil
    }

    func configValueForKey(_ key: String, isOptionsValue: Bool) -> String? {
        guard let configDict = self.configDict else { return nil }
        guard let mandantDict = configDict[DPAGRuntimeConfigWhiteLabel.kConfigMandantKey] as? [AnyHashable: Any] else { return nil }
        if isOptionsValue == false {
            guard let valuesDict = mandantDict[key] as? [String: Any] else { return nil }
            if let value = valuesDict[DPAGRuntimeConfigWhiteLabel.kConfigValueKey] as? String {
                return value
            }
        } else {
            guard let optionsDict = mandantDict[DPAGRuntimeConfigWhiteLabel.kConfigOptionsKey] as? [AnyHashable: Any] else { return nil }
            guard let data = optionsDict[DPAGRuntimeConfigWhiteLabel.kConfigOptionsDataKey] else { return nil }
            if let dataArray = data as? [[AnyHashable: Any]] {
                for valueDict in dataArray {
                    guard let name = valueDict[DPAGRuntimeConfigWhiteLabel.kConfigOptionsDataNameKey] as? String else { continue }
                    if name == key {
                        if let value = valueDict[DPAGRuntimeConfigWhiteLabel.kConfigValueKey] as? String {
                            return value
                        }
                    }
                }
            } else if let valueDict = data as? [String: Any] {
                guard let name = valueDict[DPAGRuntimeConfigWhiteLabel.kConfigOptionsDataNameKey] as? String else { return nil }
                if name == key {
                    if let value = valueDict[DPAGRuntimeConfigWhiteLabel.kConfigValueKey] as? String {
                        return value
                    }
                }
            }
        }
        return nil
    }

    override var showsDPAGApps: Bool {
        false
    }

    override var showsInviteFriends: Bool {
        false
    }

    override var canAskForRating: Bool {
        false
    }
}
