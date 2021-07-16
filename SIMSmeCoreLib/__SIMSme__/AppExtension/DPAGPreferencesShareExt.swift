//
//  DPAGPreferencesShareExt.swift
//  SIMSmeCore
//
//  Created by Robert Burchert on 01.07.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import AVFoundation
import Foundation

public protocol DPAGPreferencesShareExtProtocol: AnyObject {
    var isBaMandant: Bool { get }
    var isWhiteLabelBuild: Bool { get }
    var mandantIdent: String? { get }
    var mandantLabel: String? { get }
    var saltClient: String? { get }

    var companyIndexName: String? { get }
    var isCompanyManagedState: Bool { get }

    var canSendMedia: Bool { get }
    var autoSaveMedia: Bool { get }
    var canExportMedia: Bool { get }
    var saveImagesToCameraRoll: Bool { get }
    var sendNickname: Bool { get }

    var maximumNumberOfMediaAttachments: Int { get }

    var imageOptionsForSending: DPAGImageOptions { get }
    var videoOptionsForSending: DPAGVideoOptions { get }
    var maxLengthForSentVideos: TimeInterval { get }
    var maxFileSize: UInt64 { get }

    var mandantenDict: [String: DPAGMandant] { get }

    var sharedContainerConfig: DPAGSharedContainerConfig { get }
    var shareExtensionDevicePasstoken: String? { get }
    var shareExtensionDeviceGuid: String? { get }

    var contactsPrivateCount: Int { get }
    var contactsCompanyCount: Int { get }
    var contactsDomainCount: Int { get }

    var contactsPrivateFullTextSearchEnabled: Bool { get }
    var contactsCompanyFullTextSearchEnabled: Bool { get }
    var contactsDomainFullTextSearchEnabled: Bool { get }

    var lastRecentlyUsedContactsPrivate: [String] { get }
    var lastRecentlyUsedContactsCompany: [String] { get }
    var lastRecentlyUsedContactsDomain: [String] { get }

    func useDefaultColors() -> Bool

    func companyColorMain() -> UIColor
    func companyColorMainContrast() -> UIColor
    func companyColorAction() -> UIColor
    func companyColorActionContrast() -> UIColor
    func companyColorSecLevelHigh() -> UIColor
    func companyColorSecLevelHighContrast() -> UIColor
    func companyColorSecLevelMed() -> UIColor
    func companyColorSecLevelMedContrast() -> UIColor
    func companyColorSecLevelLow() -> UIColor
    func companyColorSecLevelLowContrast() -> UIColor

    func configure(container: DPAGSharedContainerExtensionSending.Container)
}

class DPAGPreferencesShareExt: DPAGPreferencesShareExtProtocol {
    var mandantIdent: String? { self.prefs?.mandantIdent ?? "ba" }
    var mandantLabel: String? { self.prefs?.mandantLabel ?? "Business" }
    var saltClient: String? { self.prefs?.saltClient ?? "$2a$04$Y5FhTtjHoIRLU99TNEXLSe" }
    var isWhiteLabelBuild: Bool { self.prefs?.isWhiteLabelBuild ?? true }
    var isBaMandant: Bool { self.prefs?.isBaMandant ?? true }
    var companyIndexName: String? { self.prefs?.companyIndexName }
    var isCompanyManagedState: Bool { self.prefs?.isCompanyManagedState ?? false }
    var canSendMedia: Bool { self.prefs?.canSendMedia ?? false }
    var autoSaveMedia: Bool = false
    var canExportMedia: Bool = false
    var saveImagesToCameraRoll: Bool = false
    var sendNickname: Bool { self.prefs?.sendNickname ?? false }
    var sharedContainerConfig: DPAGSharedContainerConfig { self.prefs?.sharedContainerConfig ?? DPAGSharedContainerConfig(keychainAccessGroupName: "???", groupID: "???", urlHttpService: "???") }
    var maximumNumberOfMediaAttachments: Int = 10
    var imageOptionsForSending: DPAGImageOptions { self.prefs?.imageOptionsForSending ?? DPAGImageOptions(size: CGSize(width: 1_024, height: 1_024), quality: 0.75, interpolationQuality: CGInterpolationQuality.default.rawValue) }
    var videoOptionsForSending: DPAGVideoOptions { self.prefs?.videoOptionsForSending ?? DPAGVideoOptions(size: CGSize(width: 854, height: 480), bitrate: 800_000, fps: 30, profileLevel: AVVideoProfileLevelH264Baseline41) }
    var maxFileSize: UInt64 { self.prefs?.maxFileSize ?? 0x1E00000 }
    var maxLengthForSentVideos: TimeInterval { self.prefs?.maxLengthForSentVideos ?? 0 }
    var mandantenDict: [String: DPAGMandant] = [:]
    var shareExtensionDevicePasstoken: String?
    var shareExtensionDeviceGuid: String?
    var contactsPrivateCount: Int { self.prefs?.contactsPrivateCount ?? 0 }
    var contactsCompanyCount: Int { self.prefs?.contactsCompanyCount ?? 0 }
    var contactsDomainCount: Int { self.prefs?.contactsDomainCount ?? 0 }
    var contactsPrivateFullTextSearchEnabled: Bool { self.prefs?.contactsPrivateFullTextSearchEnabled ?? false }
    var contactsCompanyFullTextSearchEnabled: Bool { self.prefs?.contactsCompanyFullTextSearchEnabled ?? false }
    var contactsDomainFullTextSearchEnabled: Bool { self.prefs?.contactsDomainFullTextSearchEnabled ?? false }
    var lastRecentlyUsedContactsPrivate: [String] { self.prefs?.lastRecentlyUsedContactsPrivate ?? [] }
    var lastRecentlyUsedContactsCompany: [String] { self.prefs?.lastRecentlyUsedContactsCompany ?? [] }
    var lastRecentlyUsedContactsDomain: [String] { self.prefs?.lastRecentlyUsedContactsDomain ?? [] }
    private var prefs: DPAGSharedContainerExtensionSending.Preferences?

    func useDefaultColors() -> Bool { self.prefs?.colors.companyColorMain == nil }
    func companyColorMain() -> UIColor { UIColor(hex: self.prefs?.colors.companyColorMain ?? 0xFFFFFF) }
    func companyColorMainContrast() -> UIColor { UIColor(hex: self.prefs?.colors.companyColorMainContrast ?? 0x3E494E) }
    func companyColorAction() -> UIColor { UIColor(hex: self.prefs?.colors.companyColorAction ?? 0x2083B0) }
    func companyColorActionContrast() -> UIColor { UIColor(hex: self.prefs?.colors.companyColorSecLevelHigh ?? 0xFFFFFF) }
    func companyColorSecLevelHigh() -> UIColor { UIColor(hex: self.prefs?.colors.companyColorSecLevelHigh ?? 0x83B37A) }
    func companyColorSecLevelHighContrast() -> UIColor { UIColor(hex: self.prefs?.colors.companyColorSecLevelHighContrast ?? 0xFFFFFF) }
    func companyColorSecLevelMed() -> UIColor { UIColor(hex: self.prefs?.colors.companyColorSecLevelMed ?? 0xFFCC00) }
    func companyColorSecLevelMedContrast() -> UIColor { UIColor(hex: self.prefs?.colors.companyColorSecLevelMedContrast ?? 0x3E494E) }
    func companyColorSecLevelLow() -> UIColor { UIColor(hex: self.prefs?.colors.companyColorSecLevelLow ?? 0xE94B57) }
    func companyColorSecLevelLowContrast() -> UIColor { UIColor(hex: self.prefs?.colors.companyColorSecLevelLowContrast ?? 0xFFFFFF) }

    func configure(container: DPAGSharedContainerExtensionSending.Container) {
        self.prefs = container.preferences
        self.mandantenDict = container.preferences.mandanten.reduce(into: [:]) { mandantenDict, mandant in
            mandantenDict[mandant.ident] = DPAGMandant(mandant: mandant)
        }
        self.shareExtensionDeviceGuid = container.device.guid
        self.shareExtensionDevicePasstoken = container.device.passToken
    }

}
