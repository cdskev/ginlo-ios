//
//  AppConfig.swift
//  SIMSmeCore
//
//  Created by Robert Burchert on 20.06.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation
import UserNotifications

public enum AppConfig {
    public enum BuildConfigurationMode {
        case DEBUG,
            TEST,
            ADHOC,
            BETA,
            RELEASE

        fileprivate static func fromConfigValue(value: String) -> BuildConfigurationMode {
            switch value {
                case "DEBUG":
                    return .DEBUG
                case "TEST":
                    return .TEST
                case "ADHOC":
                    return .ADHOC
                case "BETA":
                    return .BETA
                case "RELEASE":
                    return .RELEASE
                default:
                    return .RELEASE
            }
        }
    }

    private static func value<T>(for key: String) -> T {
        guard let value = Bundle.main.infoDictionary?[key] as? T else { fatalError("Invalid or missing Info.plist key: \(key)") }
        return value
    }

    private static func value<T>(for key: String, default: T) -> T {
        guard let value = Bundle.main.infoDictionary?[key] as? T else { return `default` }
        return value
    }

    public static let urlHttpService = "https://" + AppConfig.hostHttpService
    public static var hostHttpService: String = EndpointDAO.fetch() ?? AppConfig.value(for: "URL_HTTP_SERVICE")
    public static let keychainAccessGroupName: String = AppConfig.value(for: "KEYCHAIN_ACCESS_GROUP_NAME")
    public static let groupId: String = AppConfig.value(for: "APPLICATION_GROUP_ID")
    public static let iCloudContainerTest: String = AppConfig.value(for: "APPLICATION_ICLOUD_ID_BETA")
    public static let iCloudContainerRelease: String = AppConfig.value(for: "APPLICATION_ICLOUD_ID_RELEASE")
    public static let isShareExtension: Bool = AppConfig.value(for: "IS_SHARE_EXTENSION", default: false)
    public static let isNotificationExtension: Bool = AppConfig.value(for: "IS_NOTIFICATION_EXTENSION", default: false)
    public static let isVoipActive: Bool = AppConfig.value(for: "IS_VOIP_ACTIVE", default: false) && voipAVCServer != ""
    public static let isVoipVideoAllowed: Bool = AppConfig.value(for: "VOIP_VIDEO_ALLOWED", default: false)
    public static let isVoipGroupCallAllowed: Bool = AppConfig.value(for: "VOIP_GROUPCALL_ALLOWED", default: false)
    public static let voipMaxGroupMembers: Int = AppConfig.value(for: "VOIP_MAX_NUM_GROUP_MEMBERS", default: 100)
    public static let voipAVCServer: String = AppConfig.value(for: "VOIP_AVC_SERVER", default: "")
    public static let multiDeviceAllowed: Bool = AppConfig.value(for: "MULTI_DEVICE", default: false)
    public static let createAnnouncementGroupAllowed: Bool = AppConfig.value(for: "CREATE_ANNOUNCEMENT_GROUP_ALLOWED", default: false)
    public static let chilkatLicense: String = AppConfig.value(for: "CHILKAT_LICENSE", default: "NONE")

    #if targetEnvironment(simulator)
        public static let isSimulator = true
    #else
        public static let isSimulator = false
    #endif

    public static var applicationState: () -> UIApplication.State = { .inactive }
    public static var backgroundTaskExecution: (@escaping () -> Void) -> Void = { block in
        block()
    }

    public static let buildConfigurationMode = BuildConfigurationMode.fromConfigValue(value: AppConfig.value(for: "BUILD_CONFIGURATION_MODE"))
    public static var statusBarOrientation: () -> UIInterfaceOrientation = { .portrait }
    public static var openURL: (_: URL?) -> Void = { _ in }
    public static var setIdleTimerDisabled: (_: Bool) -> Void = { _ in }
    public static var appWindow: () -> UIWindow?? = { nil }
    public static var setApplicationIconBadgeNumber: (_: Int) -> Void = { _ in }
    public static var isRegisteredForRemoteNotifications: () -> Bool = { false }
    public static var registerForRemoteNotifications: () -> Void = {}
    public static var currentUserNotificationSettings: (@escaping (UNNotificationSettings?) -> Void) -> Void = { _ in }
    public static var preferredContentSizeCategory: () -> UIContentSizeCategory = { .unspecified }
    public static var currentApplication: () -> UIApplication? = { nil }
}
