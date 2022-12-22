//
//  DPAGRuntimeConfig.swift
//  SIMSmeCore
//
//  Created by RBU on 27.06.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation

open class DPAGRuntimeConfig {
    public static let kPurchaseSelfDestructionDebug = "SIMSme.Debug.Selfdestruction"
    public static let kPurchaseSelfDestructionAdHoc = "SIMSme.Adhoc.Selfdestruction"
    public static let kPurchaseSelfDestructionRelease = "SIMSme.Release.Selfdestruction"

    public init() {}

    open var sharedContainerConfig: DPAGSharedContainerConfig {
        DPAGSharedContainerConfig(keychainAccessGroupName: AppConfig.keychainAccessGroupName, groupID: AppConfig.groupId, urlHttpService: AppConfig.urlHttpService)
    }

    open var fulltextSize: Int {
        Int.max
    }

    open func apnIdentifier(bundleIdentifier: String, deviceToken: String?) -> String {
        guard let deviceToken = deviceToken else {
            return ""
        }

        switch AppConfig.buildConfigurationMode {
            case .ADHOC, .DEBUG, .TEST:
                return String(format: "sandbox.%@:%@", bundleIdentifier, deviceToken)
            case .RELEASE, .BETA:
                return String(format: "%@:%@", bundleIdentifier, deviceToken)
        }
    }

    open func apnIdentifierForSignaling(bundleIdentifier: String) -> String {
        switch AppConfig.buildConfigurationMode {
            case .ADHOC, .DEBUG, .TEST:
                return String(format: "sandbox.%@", bundleIdentifier)
            case .RELEASE, .BETA:
                return bundleIdentifier
        }
    }

    open var urlScheme: String {
        "ginlo"
    }

    open var urlSchemeOld: String {
        "simsme"
    }
    
    open var maxFileSize: UInt64 {
        0x6400000
    }

    open var isWhiteLabelBuild: Bool {
        false
    }

    open var saltClient: String {
        "$2a$04$Dsvymn7LlP1bMlTCuNpd/O"
    }

    open var canAskForRating: Bool {
        true
    }

    open var maxDaysChannelMessagesValid: UInt {
        7
    }

    open var maxNumChannelMessagesPerChannel: UInt {
        30
    }

    open var isChatExportAllowed: Bool {
        true
    }

    open var isChannelsAllowed: Bool {
        true
    }

    open var isServicesAllowed: Bool {
        false
    }

    open var isCommentingEnabled: Bool {
        true
    }

    open var mandantIdent: String? {
        nil
    }

    open var mandantLabel: String? {
        nil
    }

    open var isBaMandant: Bool {
        false
    }
}
