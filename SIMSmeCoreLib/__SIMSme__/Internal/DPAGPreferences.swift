//
//  DPAGPreferences.swift
//  SIMSme
//
//  Created by RBU on 20/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import AVFoundation

struct DPAGPreferencesServerSyncFlags: OptionSet {
    let rawValue: Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    static let none = DPAGPreferencesServerSyncFlags([])
    static let profileInfo = DPAGPreferencesServerSyncFlags(rawValue: 0x1)
}

public struct DPAGPasswordViewControllerVerifyState: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let PwdOk = DPAGPasswordViewControllerVerifyState(rawValue: 1)
    public static let PwdFailsMinLength = DPAGPasswordViewControllerVerifyState(rawValue: 2)
    public static let PwdFailsMinDigits = DPAGPasswordViewControllerVerifyState(rawValue: 4)
    public static let PwdFailsMinSpecialChars = DPAGPasswordViewControllerVerifyState(rawValue: 8)
    public static let PwdFailsMinLowercase = DPAGPasswordViewControllerVerifyState(rawValue: 16)
    public static let PwdFailsMinUppercase = DPAGPasswordViewControllerVerifyState(rawValue: 32)
    public static let PwdFailsMinClasses = DPAGPasswordViewControllerVerifyState(rawValue: 64)
    public static let PwdFailsNoPin = DPAGPasswordViewControllerVerifyState(rawValue: 128)
}

public struct DPAGAutomaticRegistrationPreferences {
    public let firstName: String
    public let lastName: String
    public let eMailAddress: String
    public let loginCode: String

    public init(firstName: String, lastName: String, eMailAddress: String, loginCode: String) {
        self.firstName = firstName
        self.lastName = lastName
        self.eMailAddress = eMailAddress
        self.loginCode = loginCode
    }
}

public class DPAGPreferences: NSObject {
    // MARK: IMDAT TIME-INTERVAL
    private let timeIntervalShowSyncContactsReminder = (component: Calendar.Component.day, value: 1)

    private class DictionarySynchronized {
        private let queueAccess: DispatchQueue = DispatchQueue(label: "de.dpag.simsme.DPAGPreferences.DictionarySynchronized.queueAccess", qos: .default, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil)

        private var dict: [String: Any]

        subscript(key: String) -> Any? {
            get {
                var retVal: Any?
                self.queueAccess.sync {
                    retVal = self.dict[key]
                }
                return retVal
            }
            set {
                self.queueAccess.async(flags: .barrier) {
                    if newValue == nil {
                        self.dict.removeValue(forKey: key)
                    } else {
                        self.dict[key] = newValue
                    }
                }
            }
        }

        init(dict: [String: Any]) {
            self.dict = dict
        }

        func reset() {
            self.queueAccess.async(flags: .barrier) {
                self.dict.removeAll()
            }
        }

        func serialize(from fileURL: URL) -> Bool {
            var success = false
            self.queueAccess.sync(flags: .barrier) {
                for _ in 0 ..< 20 {
                    var dict: [String: Any]?
                    DPAGLog("Trying to read the preferences")
                    do {
                        let data = try Data(contentsOf: fileURL)
                        dict = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
                    } catch {
                        dict = nil
                        if let nserror = error as NSError?, nserror.domain == "NSCocoaErrorDomain", nserror.code == 257 {
                            DPAGLog(error, message: "I can not yet read the file in question because I don't have access - returning immediately to save time")
                            break
                        }
                        DPAGLog(error, message: "error reading preferences file")
                    }
                    if let dict = dict {
                        self.dict = dict
                        success = true
                        break
                    } else {
                        Thread.sleep(forTimeInterval: 0.1)
                    }
                }
            }
            return success
        }

        func serialize(to fileURL: URL) {
            self.queueAccess.sync(flags: .barrier) {
                var errorBlock: Error?
                do {
                    let plistData = try PropertyListSerialization.data(fromPropertyList: self.dict, format: .xml, options: PropertyListSerialization.WriteOptions())
                    try plistData.write(to: fileURL, options: [.atomic, .noFileProtection])
                    try (fileURL as NSURL).setResourceValue(URLFileProtection.none, forKey: .fileProtectionKey)
                } catch {
                    errorBlock = error
                }
                if let error = errorBlock {
                    DPAGLog(error, message: "error writing preferences file")
                }
            }
        }
    }

    private var data = DictionarySynchronized(dict: [:])

    public subscript(key: PropBool) -> Bool? {
        get {
            self.data[key.rawValue] as? Bool
        }
        set {
            self.setData(key: key.rawValue, newValue: newValue, typeOf: Bool.self)
        }
    }

    public subscript(key: PropString) -> String? {
        get {
            self.data[key.rawValue] as? String
        }
        set {
            self.setData(key: key.rawValue, newValue: newValue, typeOf: String.self)
        }
    }

    public subscript(key: PropInt) -> Int? {
        get {
            self.data[key.rawValue] as? Int
        }
        set {
            self.setData(key: key.rawValue, newValue: newValue, typeOf: Int.self)
        }
    }

    public subscript(key: PropDate) -> Date? {
        get {
            self.data[key.rawValue] as? Date
        }
        set {
            self.setData(key: key.rawValue, newValue: newValue, typeOf: Date.self)
        }
    }

    public subscript(key: PropNumber) -> NSNumber? {
        get {
            self.data[key.rawValue] as? NSNumber
        }
        set {
            self.setData(key: key.rawValue, newValue: newValue, typeOf: NSNumber.self)
        }
    }

    public subscript(key: PropAny) -> Any? {
        get {
            self.data[key.rawValue]
        }
        set {
            self.data[key.rawValue] = newValue
            self.save()
        }
    }

    public subscript(key: String) -> Any? {
        get {
            UserDefaults.standard.object(forKey: key)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
            CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication)
        }
    }

    private func enumSetting<T: RawRepresentable>(setting: PropInt, defaultValue: T) -> T where T.RawValue == Int {
        guard let settingRawValue = self[setting] else { return defaultValue }
        guard let setting = T(rawValue: settingRawValue) else { return defaultValue }
        return setting
    }

    private func setData<T: Equatable>(key: String, newValue: Any?, typeOf _: T.Type) {
        if (self.data[key] as? T) != (newValue as? T) {
            self.data[key] = newValue
            self.save()
        }
    }

    private static let fileURL = DPAGConstantsGlobal.documentsDirectoryURL?.appendingPathComponent("preferences", isDirectory: false).appendingPathExtension("plist")

    private func save() {
        guard let fileURL = DPAGPreferences.fileURL else { return }
        self.data.serialize(to: fileURL)
    }

    override init() {
        super.init()
    }

    public func setup() -> Bool {
        guard let fileURL = DPAGPreferences.fileURL else { return false }
        return self.data.serialize(from: fileURL)
    }

    public enum PropBool: String, CaseIterable {
        case kBackupSaveMedia = "backupSaveMedia",
            kNotificationRegistrationNeedsDefaults = "notification_registration_needs_defaults",
            kAutoGeneratedMessagesEnabled = "sims_auto_generated_messages_enabled",
            kDisablePassword = "sims_disablePassword",
            kAlreadyAskedForPush = "sims_already_asked_for_push",
            kAlreadyAskedForMic = "sims_already_asked_for_mic",
            kProximityMonitoring = "simsme_proximity_monitoring",
            kMarkMessagesAsRead = "sims_mark_messages_as_read",
            kSkipPlayingSelfDestructionAudio = "sims_skip_playing_self_destruction_audio",
            kSkipPlayingSendAudio = "sims_skip_playing_send_audio",
            kSkipPlayingReceiveAudio = "sims_skip_playing_receive_audio",
            kPublicOnlineState = "sims_public_online_state",
            kSimsmeRecovery = "sims_recovery",
            kBootstrappingCheckBackup = "bootstrappingCheckBackup",
            kBootstrappingOverride = "bootstrappingOverride",
            kBootstrappingSkipWarningOverride = "bootstrappingSkipWarning",
            kTrackingEnabled = "enableTracking",
            kDeleteData = "disableDeleteData",
            kCameraBackground = "camera-Backrgound",
            kInviteFriendsAfterInstall = "invite_friends_after_install",
            kInviteFriendsAfterChatPrivateCreation = "invite_friends_after_chat_private_creation",
            kBackgroundAccessTokenSyncDisabled = "background_access_token_sync_disabled",
            kDidSetDeviceName = "did_set_device_name",
            kDidShowProfileInfo = "did_show_profile_info",
            kSystemGeneratedPassword = "System_generated_password",
            kIsCrashReportEnabled,

            // SIMSme MDM Config Keys
            kMdmDisableNoPwLogin = "disableNoPwLogin",
            kMdmForceComplexPin = "forceComplexPin",
            kMdmDisableTouchId = "disableFaceAndTouchID",
            kMdmDisableBackup = "disableBackup",
            kMdmDisableSaveToCameraRoll = "disableSaveToCameraRoll",
            kMdmDisableSendMedia = "disableSendMedia",
            kMdmDisableOpenIn = "disableOpenIn",
            kMdmDisableExportChat = "disableExportChat",

            kMdmDisableSendVCard = "disableSendVCard",
            kMdmDisableCamera = "disableCamera",
            kMdmDisableMicrophone = "disableMicrophone",
            kMdmDisableLocation = "disableLocation",
            kMdmDisableCopyPaste = "disableCopyPaste",
            kMdmDisableSimsmeRecovery = "disableSimsmeRecovery",
            kMdmDisableAllRecovery = "disableRecoveryCode",

            kMdmDisablePushPreview = "disablePushPreview"
    }

    public enum PropString: String, CaseIterable {
        case kDeviceToken = "sims_prefs_device_token",
            kAPNIdentifier = "sims_prefs_apn_identifier",
            kBackupLastFile = "backupLastFile",
            kCacheVersionServerConfig = "sims_cache_version_server_config",
            kCacheVersionMandanten = "sims_cache_version_mandanten",
            kCacheVersionChannels = "sims_cache_version_channels",
            kCacheVersionServices = "sims_cache_version_services",
            kCacheVersionCompanyLayout = "sims_cache_version_companyLayout",
            kCacheVersionCompanyMDMConfig = "sims_cache_version_companyConfig",
            kCacheVersionGetBlocked = "sims_cache_version_blocked",
            kCacheVersionPrivateIndex = "sims_cache_version_privateIndex",
            kCacheVersionConfirmedIdentities = "sims_cache_version_confirmedIdentities",
            kCacheVersionCompanyIndex = "sims_cache_version_companyIndex",
            kNotificationRegistrationError = "notification_registration_error",
            kTrackingGuid = "sims_prefs_tracking_guid",
            kSimsmeRecoveryMail = "sims_recovery_mail",
            kSimsmeRecoveryPhone = "sims_recovery_phone",
            kSimsmeRecoveryAdmin = "sims_recovery_admin",
            kSimsmePublicKey = "sims_recovery_publickey",
            kBootstrappingConfirmationCode = "bootstrappingConfirmationCode",
            kBootstrappingOldAccountID = "bootstrappingOldAccountID",

            kChatRingtone = "chat_ringtone",
            kGroupChatRingtone = "group_chat_ringtone",
            kChannelChatRingtone = "channel_chat_ringtone",
            kServiceChatRingtone = "service_chat_ringtone",

            kNotificationChatEnabled = "chat_notification_enabled",
            kNotificationGroupChatEnabled = "group_chat_notification_enabled",
            kNotificationChannelChatEnabled = "channel_chat_notification_enabled",
            kNotificationServiceChatEnabled = "service_chat_notification_enabled",

            kNotificationInAppEnabled = "inapp_notification_enabled",
            kNotificationNicknameEnabled = "nickname_notification_enabled",
            kPreviewPushNotificationEnabled = "preview_notification_enabled",
            kShareExtensionEnabled = "share_extension_enabled",

            kSaveImagesLocation = "save_images_location",
            kBackgroundAccessToken = "background_access_token",
            kBackgroundUsername = "background_user_name",
            kShareExtensionDeviceGuid = "kPreferencesShareExtensionDeviceGuid",
            kShareExtensionDevicePasstoken = "kPreferencesShareExtensionDevicePasstoken",

            kValidationEmail = "kPreferencesValidationEmail",
            kValidationEmailDomain = "kPreferencesValidationEmailDomain",
            kValidationPhone = "kPreferencesValidationPhone",

            kLastSuccessFullSyncPrivateIndex = "kPreferencesLastSuccessFullSyncPrivateIndex",

            kLastRunningVersion = "MGHelperLastRunningVersion",

            // SIMSme MDM Config Keys
            kPasswordUsedPasswords = "simsPasswordUsedPasswords",
            kPasswordsAesKey = "simsPasswordsAesKey",

            kCompanyLogo = "sims_company_logo",
            kCompanyLogoChecksum = "sims_company_logo_checksum",
            kCompanyColorMain = "sims_company_colorMain",
            kCompanyColorMainContrast = "sims_company_colorMainContrast",
            kCompanyColorAction = "sims_company_colorAction",
            kCompanyColorActionContrast = "sims_company_colorActionContrast",
            kCompanyColorSecLevelHigh = "sims_company_colorSecLevelHigh",
            kCompanyColorSecLevelHighContrast = "sims_company_colorSecLevelHighContrast",
            kCompanyColorSecLevelMed = "sims_company_colorSecLevelMed",
            kCompanyColorSecLevelMedContrast = "sims_company_colorSecLevelMedContrast",
            kCompanyColorSecLevelLow = "sims_company_colorSecLevelLow",
            kCompanyColorSecLevelLowContrast = "sims_company_colorSecLevelLowContrast",

            kLicenseValidDate = "sims_license_valid_date",
            kTestLicenseDaysLeft = "sims_license_test_license_days_left"
    }

    public enum PropInt: String, CaseIterable {
        case kBackupInterval = "backupInterval",
            kLastConfigSynchronizationCounter = "sims_last_config_synchronization_counter",
            kHasPendingMessages = "sims_has_pending_messages",
            kNotificationRegistrationState = "notification_registration_state",
            kPasswordInputWrongCounter = "sims_password_input_wrong_count",
            kPasswordTriesDefault = "sims_password_tries_default",
            kPasswordTriesLeft = "sims_password_tries_left",
            kLockApplicationDelay = "sims_lock_application_delay",
            kRateState = "simsme_rate_state",
            kRateCounterValue = "simsme_rate_value",
            kMigrationVersion = "sims_migration_version",
            kStreamVisibilities = "sims_visibility_streams",
            kDidAskForCompanyEmail = "did_ask_for_comopany_email",
            kDidAskForCompanyPhoneNumber = "did_ask_for_company_phoneNumber",
            kDidAskForPushPreview = "did_ask_for_push_preview",
            kCompanyManagedState = "company_managed_state",
            kPasswordType = "password_type",
            kSentImageQuality = "send_image_quality",
            kSentVideoQuality = "send_video_quality",
            kChatPrivateCreationCount = "chat_private_creation_count",
            kChatGroupCreationCount = "chat_group_creation_count",
            kAutoDownloadSettingFoto = "autodownload_setting_foto",
            kAutoDownloadSettingAudio = "autodownload_setting_audio",
            kAutoDownloadSettingVideo = "autodownload_setting_video",
            kAutoDownloadSettingFile = "autodownload_setting_file",
            kServerSyncFlags = "server_sync_flags",

            kContactsPrivateCount = "contactsPrivateCount",
            kContactsCompanyCount = "contactsCompanyCount",
            kContactsDomainCount = "contactsDomainCount",

            kPasswordMinLength = "kPreferencesPasswordMinLength",
            kPasswordMinSpecialChar = "kPreferencesPasswordMinSpecialChar",
            kPasswordMinDigit = "kPreferencesPasswordMinDigit",
            kPasswordMinLowercase = "kPreferencesPasswordMinLowercase",
            kPasswordMinUppercase = "kPreferencesPasswordMinUppercase",
            kPasswordMinClasses = "kPreferencesPasswordMinClasses",
            kPasswordMaxDuration = "kPreferencesPasswordMaxDuration",

            // SIMSme MDM Config Keys
            kMdmSimsLockApplicationDelay = "simsLockApplicationDelay",
            kMdmSimsPasswordTries = "simsPasswordTries",
            kMdmPasswordMinLength = "passwordMinLength",
            kMdmPasswordMinSpecialChar = "passwordMinSpecialChar",
            kMdmPasswordMinDigit = "passwordMinDigit",
            kMdmPasswordMinLowercase = "passwordMinLowercase",
            kMdmPasswordMinUppercase = "passwordMinUppercase",
            kMdmPasswordMinClasses = "passwordMinClasses",
            kMdmPasswordMaxDuration = "passwordMaxDuration",
            kMdmPasswordReuseEntries = "passwordReuseEntries"
    }

    public enum PropDate: String, CaseIterable {
        case kBackupLastDate = "backupLastDate",
            kAddressInformationsCompanyDate = "addressInformationsCompanyWithAccountGuidDate",
            kLastContactSynchronization = "sims_last_contact_synchronization",
            kLastConfigSynchronization = "sims_last_config_synchronization",
            kDomainIndexSynchronisation = "sims_last_domain_index_synchronization",
            kLastOwnOooStatusCheck = "sims_last_own_ooo_status",
            kLastDeviceTokenSynchronization = "sims_last_device_token_synchronization",
            kLastBackgroundAccessTokenSynchronization = "sims_last_background_access_token_synchronization",
            kAccountRegisteredAtDateTime = "sims_AccountRegisteredAtDateTime",

            kPasswordCurrentDuration = "simsPasswordCurrentDuration",

            kLastDateReminderSyncContactsShown
    }

    public enum PropNumber: String, CaseIterable {
        case kBackupLastSize = "backupLastSize"
    }

    public enum PropAny: String, CaseIterable {
        case kLastGroupSynchronizationDates = "sims_last_group_synchronization_dates", // Dict
            kLastProfileSynchronizationDates = "sims_last_profile_synchronization_dates",
            kServerConfiguration = "server_configuration",

            kMandanten = "sims_mandanten", // Data

            kLastRecentlyUsedContactsPrivate = "lastRecentlyUsedContactsPrivate",
            kLastRecentlyUsedContactsCompany = "lastRecentlyUsedContactsCompany",
            kLastRecentlyUsedContactsDomain = "lastRecentlyUsedContactsDomain",

            kBootstrappingAvailableAccountID = "bootstrappingAvailableAccountID" // [String]

    }

    public static let kValueTimerCheckForNewMessagesInChatsList = 10
    public static let kValueMaxGroupMemberInChatRoom = 100
    public static let kValueTimerCheckForNewMessagesInChatStream = 30
    public static let kValueTimeoutLazyService = 300

    // For the Keychain-stored preferences use names as short as possible
    public static let kPreferenceTouchId = "tid"

    public static let kValueNotificationEnabled = "enabled"
    public static let kValueNotificationDisabled = "disabled"
    public static let kValueNotificationSoundDefault = "default"
    public static let kValueNotificationSoundNone = ""

    public static let kValueSaveImagesToCameraRoll = "to_camera_roll"
    public static let kValueSaveImagesInAppOnly = "in_app_only"

    public static let kInfoPage = "sims_info_page"

    public func setDefaults() {
        self.data.reset()

        self[.kSaveImagesLocation] = DPAGPreferences.kValueSaveImagesInAppOnly

        self[.kNotificationChatEnabled] = DPAGPreferences.kValueNotificationDisabled
        self[.kNotificationGroupChatEnabled] = DPAGPreferences.kValueNotificationDisabled
        self[.kNotificationChannelChatEnabled] = DPAGPreferences.kValueNotificationDisabled
        self[.kNotificationServiceChatEnabled] = DPAGPreferences.kValueNotificationDisabled

        self[.kChatRingtone] = DPAGPreferences.kValueNotificationSoundDefault
        self[.kGroupChatRingtone] = DPAGPreferences.kValueNotificationSoundDefault
        self[.kChannelChatRingtone] = DPAGPreferences.kValueNotificationSoundDefault
        self[.kServiceChatRingtone] = DPAGPreferences.kValueNotificationSoundDefault

        self[.kNotificationRegistrationState] = DPAGNotificationRegistrationState.notAsked.rawValue

        self[.kValidationEmail] = nil
        self[.kValidationEmailDomain] = nil
        self[.kValidationPhone] = nil

        self[.kNotificationRegistrationError] = ""
        self[.kNotificationRegistrationNeedsDefaults] = true

        self.trackingEnabled = true
        self.deleteData = false
        self.passwordOnStartEnabled = true
        self.cameraBackgroundEnabled = false

        self[.kRateState] = DPAGSettingRate.neverAsked.rawValue
        self[.kRateCounterValue] = 0
        self.setPasswordTriesDefault(.ten)
        self.applicationLockDelay = .zero
        self.resetPasswordTries()
        self[.kPasswordInputWrongCounter] = 0

        self.alreadyAskedForPush = false
        self.alreadyAskedForMic = false
        self.proximityMonitoringEnabled = false
        self.markMessagesAsReadEnabled = true

        self.chatPrivateCreationCount = 0
        self.chatGroupCreationCount = 0

        self.touchIDEnabled = false

        self.skipPlayingSelfDestructionAudio = false
        self.skipPlayingSendAudio = false
        self.skipPlayingReceiveAudio = false

        self[.kLastConfigSynchronizationCounter] = nil
        self[.kLastDeviceTokenSynchronization] = nil
        self[.kLastBackgroundAccessTokenSynchronization] = nil
        self[.kLastSuccessFullSyncPrivateIndex] = nil
        self[.kLastContactSynchronization] = nil
        self[.kLastConfigSynchronization] = nil
        self[.kAddressInformationsCompanyDate] = nil

        self.resetCacheVersions()

        self[.kBackgroundAccessToken] = nil

        self[.kBackupInterval] = nil
        self[.kBackupLastDate] = nil
        self[.kBackupLastSize] = nil
        self[.kBackupLastFile] = nil
        self[.kBackupSaveMedia] = nil

        self[.kCompanyManagedState] = nil
        self[.kDidAskForCompanyEmail] = nil
        self[.kDidAskForCompanyPhoneNumber] = nil
        self[.kDidAskForPushPreview] = nil
        self[.kDidShowProfileInfo] = nil

        self[.kSimsmeRecovery] = nil
        self[.kSimsmeRecoveryPhone] = nil
        self[.kSimsmeRecoveryMail] = nil
        self[.kSimsmeRecoveryAdmin] = nil
        self[.kSimsmePublicKey] = nil

        self[.kDidSetDeviceName] = nil
        self[.kShareExtensionEnabled] = nil
        self[.kShareExtensionDeviceGuid] = nil
        self[.kShareExtensionDevicePasstoken] = nil

        self[.kDomainIndexSynchronisation] = nil

        self[.kPasswordMinLength] = nil
        self[.kPasswordMinSpecialChar] = nil
        self[.kPasswordMinDigit] = nil
        self[.kPasswordMinLowercase] = nil
        self[.kPasswordMinUppercase] = nil
        self[.kPasswordMinClasses] = nil
        self[.kPasswordMaxDuration] = nil

        self[.kLastOwnOooStatusCheck] = nil

        DPAGApplicationFacade.sharedContainer.deleteData(config: self.sharedContainerConfig, filename: DPAGApplicationFacade.sharedContainer.fileName)
        DPAGApplicationFacade.sharedContainerSending.deleteData(config: self.sharedContainerConfig, filename: DPAGApplicationFacade.sharedContainerSending.fileName)
        self.clearBootStrapping()
        self.isCrashReportEnabled = true
    }

    public var sharedContainerConfig: DPAGSharedContainerConfig {
        DPAGApplicationFacade.runtimeConfig.sharedContainerConfig
    }

    private func resetCacheVersions() {
        self[.kCacheVersionServerConfig] = nil
        self[.kCacheVersionMandanten] = nil
        self[.kCacheVersionChannels] = nil
        self[.kCacheVersionServices] = nil
        self[.kCacheVersionCompanyLayout] = nil
        self[.kCacheVersionCompanyMDMConfig] = nil
        self[.kCacheVersionGetBlocked] = nil
        self[.kCacheVersionPrivateIndex] = nil
        self[.kCacheVersionConfirmedIdentities] = nil
        self[.kCacheVersionCompanyIndex] = nil
    }

    public func reset() {
        KeychainKeyValueStore.sharedInstance().clear()
    }

    public func isFirstRunAfterUpdate() -> Bool {
        let lastVersion = self[.kLastRunningVersion]
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        self[.kLastRunningVersion] = version
        return lastVersion != version
    }

    public func resetFirstRunAfterUpdate() {
        self[.kLastRunningVersion] = nil
    }

    public var skipPlayingSelfDestructionAudio: Bool {
        get {
            self[.kSkipPlayingSelfDestructionAudio] ?? false
        }
        set {
            self[.kSkipPlayingSelfDestructionAudio] = newValue
        }
    }

    public var skipPlayingSendAudio: Bool {
        get {
            self[.kSkipPlayingSendAudio] ?? false
        }
        set {
            self[.kSkipPlayingSendAudio] = newValue
        }
    }

    public var skipPlayingReceiveAudio: Bool {
        get {
            self[.kSkipPlayingReceiveAudio] ?? false
        }
        set {
            self[.kSkipPlayingReceiveAudio] = newValue
        }
    }

    public var shouldAskForRate: Bool {
        let rateState = enumSetting(setting: .kRateState, defaultValue: DPAGSettingRate.neverAsked)
        guard rateState != .neverAskAgain else { return false }
        let counterValue = self[.kRateCounterValue] ?? 0
        if counterValue >= 29, rateState == .neverAsked {
            return true
        } else if counterValue >= 99, rateState == .askLater {
            self[.kRateCounterValue] = 0
            return true
        }
        self[.kRateCounterValue] = counterValue + 1
        return false
    }

    public func updateRateState(_ state: DPAGSettingRate) {
        self[.kRateState] = state.rawValue
    }

    public func shouldShowSyncContactsReminder() -> Bool {
        guard let lastDateReminderShown = self[.kLastDateReminderSyncContactsShown] else { return true }
        let component = self.timeIntervalShowSyncContactsReminder.component
        let value = self.timeIntervalShowSyncContactsReminder.value
        let difference = Date.dateDifference(startDate: lastDateReminderShown, component: component)
        return difference >= value
    }
    
    public func shouldSyncContancs() -> Bool {
        self.shouldShowSyncContactsReminder()
    }

    public func updateLastDateReminderShown() {
        self[.kLastDateReminderSyncContactsShown] = Date()
    }

    public func needsContactSynchronization() -> Bool {
        if let last = self[.kLastContactSynchronization], last.isToday() {
            return false
        }
        return true
    }

    public func needsConfigSynchronization() -> Bool {
        if let last = self[.kLastConfigSynchronization], last.isToday() {
            return false
        }
        return true
    }

    public func forceNeedsConfigSynchronization() {
        self[.kLastConfigSynchronization] = nil
    }

    public func checkForOwnOooStatus() -> Bool {
        if let last = self[.kLastOwnOooStatusCheck], last.isToday() {
            return false
        }
        return true
    }

    public func updateCheckForOwnOooStatus() {
        self[.kLastOwnOooStatusCheck] = Date()
    }

    public func cacheVersionTaskCompleted(_ versionKey: DPAGPreferences.PropString?, cacheVersionServer: String?) {
        if let versionKey = versionKey, let cacheVersionServer = cacheVersionServer {
            self[versionKey] = cacheVersionServer
        }
        let taskCount = (self[.kLastConfigSynchronizationCounter] ?? 0) - 1
        if taskCount <= 0 {
            self[.kLastConfigSynchronizationCounter] = nil
            self.updateLastConfigSynchronization()
        } else {
            self[.kLastConfigSynchronizationCounter] = taskCount
        }
    }

    public var contactsPrivateCount: Int {
        get {
            self[.kContactsPrivateCount] ?? 0
        }
        set {
            self[.kContactsPrivateCount] = newValue
        }
    }

    public var contactsPrivateFullTextSearchEnabled: Bool {
        false
    }

    public var contactsCompanyCount: Int {
        get {
            self[.kContactsCompanyCount] ?? 0
        }
        set {
            self[.kContactsCompanyCount] = newValue
        }
    }

    public var contactsCompanyFullTextSearchEnabled: Bool {
        self.contactsCompanyCount > DPAGApplicationFacade.runtimeConfig.fulltextSize
    }

    public var contactsDomainCount: Int {
        get {
            self[.kContactsDomainCount] ?? 0
        }
        set {
            self[.kContactsDomainCount] = newValue
        }
    }

    public var contactsDomainFullTextSearchEnabled: Bool {
        self.contactsDomainCount > DPAGApplicationFacade.runtimeConfig.fulltextSize
    }

    public func updateLastContactSynchronization() {
        self[.kLastContactSynchronization] = Date()
    }

    public func updateLastConfigSynchronization() {
        self[.kLastConfigSynchronization] = Date()
    }

    public func needsDomainIndexSynchronisation() -> Bool {
        if let last = self[.kDomainIndexSynchronisation], last.isToday() {
            return false
        }
        return true
    }

    public func updateLastDomainIndexSynchronisation() {
        self[.kDomainIndexSynchronisation] = Date()
    }

    public func forceNeedsDomainIndexSynchronisation() {
        self[.kDomainIndexSynchronisation] = nil
    }

    public func setHasPendingMessages(pending: Bool) {
        self[.kHasPendingMessages] = pending ? 1 : nil
    }

    public func hasPendingMessages() -> Bool {
        guard let isPending = self[.kHasPendingMessages] else { return false }
        return isPending == 1
    }

    public var didSetDeviceName: Bool {
        get {
            self[.kDidSetDeviceName] ?? false
        }
        set {
            self[.kDidSetDeviceName] = newValue
        }
    }

    public var deviceTrackingGuid: String {
        if let trackingGuid = self[.kTrackingGuid], trackingGuid.count > 30 {
            return trackingGuid
        } else {
            let uuid = String(format: "9:{%@}", DPAGFunctionsGlobal.uuid())
            let trackingGuid = String(format: "%@1%@", String(uuid[..<uuid.index(uuid.startIndex, offsetBy: 9)]), String(uuid[uuid.index(uuid.startIndex, offsetBy: 10)...]))
            self[.kTrackingGuid] = trackingGuid
            return trackingGuid
        }
    }

    public var deviceToken: String? {
        get {
            self[DPAGPreferences.PropString.kDeviceToken]
        }
        set {
            if let token = newValue {
                self[.kLastDeviceTokenSynchronization] = Date()
                self[.kDeviceToken] = token
            }
        }
    }

    public var backgroundAccessToken: String? {
        get {
            self[.kBackgroundAccessToken]
        }
        set {
            if let token = newValue {
                self[.kLastBackgroundAccessTokenSynchronization] = Date()
                self[.kBackgroundAccessToken] = token
            } else {
                self[.kLastBackgroundAccessTokenSynchronization] = nil
                self[.kBackgroundAccessToken] = nil
            }
        }
    }

    public var needsBackgroundAccessTokenSynchronization: Bool {
        if self.backgroundAccessToken != nil, let last = self[.kLastBackgroundAccessTokenSynchronization], last.isToday() {
            return false
        }
        return self.backgroundAccessTokenSyncEnabled
    }

    public var backgroundAccessTokenSyncEnabled: Bool {
        get {
            (self[.kBackgroundAccessTokenSyncDisabled] ?? false) == false
        }
        set {
            self[.kBackgroundAccessTokenSyncDisabled] = (newValue == false)
            if newValue == false {
                if self.previewPushNotification {
                    self.previewPushNotification = false
                }
                self[.kLastBackgroundAccessTokenSynchronization] = nil
            }
        }
    }

    public var backgroundAccessUsername: String? {
        get {
            self[.kBackgroundUsername]
        }
        set {
            if let token = newValue {
                self[.kBackgroundUsername] = token
            }
        }
    }

    public func backupSaveMedia() -> Bool {
        self[.kBackupSaveMedia] ?? true
    }

    public func setBackupSaveMedia(_ saveMedia: Bool) {
        self[.kBackupSaveMedia] = saveMedia
    }

    public var backupInterval: DPAGBackupInterval? {
        get {
            enumSetting(setting: .kBackupInterval, defaultValue: .disabled)
        }

        set {
            self[.kBackupInterval] = newValue?.rawValue
        }
    }

    public var backupLastDate: Date? {
        get {
            self[.kBackupLastDate]
        }
        set {
            self[.kBackupLastDate] = newValue
        }
    }

    public var backupLastFileSize: NSNumber? {
        get {
            self[.kBackupLastSize]
        }
        set {
            self[.kBackupLastSize] = newValue
        }
    }

    public var backupLastFile: String? {
        get {
            self[.kBackupLastFile]
        }
        set {
            self[.kBackupLastFile] = newValue
        }
    }

    public var addressInformationsCompanyDate: Date? {
        get {
            self[.kAddressInformationsCompanyDate]
        }
        set {
            self[.kAddressInformationsCompanyDate] = newValue
        }
    }

    public func forceUpdateCompanyIndex() {
        self[.kAddressInformationsCompanyDate] = nil
        self[.kCacheVersionCompanyIndex] = nil
        self.forceNeedsConfigSynchronization()
    }

    public var apnIdentifier: String? {
        get {
            self[.kAPNIdentifier]
        }
        set {
            self[.kAPNIdentifier] = newValue
        }
    }

    public func needsDeviceTokenSynchronization() -> Bool {
        if let last = self[.kLastDeviceTokenSynchronization], last.isToday() {
            return false
        }
        return true
    }

    public func setNeedsDeviceTokenSynchronization() {
        self[.kLastDeviceTokenSynchronization] = Date.withDaysFromNow(-7)
    }

    public var saveImagesToCameraRoll: Bool {
        get {
            self[.kSaveImagesLocation] == DPAGPreferences.kValueSaveImagesToCameraRoll
        }
        set {
            self[.kSaveImagesLocation] = newValue ? DPAGPreferences.kValueSaveImagesToCameraRoll : DPAGPreferences.kValueSaveImagesInAppOnly
        }
    }

    public var notificationRegistrationState: DPAGNotificationRegistrationState {
        get {
            enumSetting(setting: .kNotificationRegistrationState, defaultValue: .notAsked)
        }
        set {
            self[.kNotificationRegistrationState] = newValue.rawValue
        }
    }

    public var notificationRegistrationError: String? {
        get {
            self[.kNotificationRegistrationError]
        }
        set {
            self[.kNotificationRegistrationError] = newValue
        }
    }

    public var notificationRegistrationNeedsDefaults: Bool {
        get {
            self[.kNotificationRegistrationNeedsDefaults] ?? false
        }
        set {
            self[.kNotificationRegistrationNeedsDefaults] = newValue
        }
    }

    public var passwordType: DPAGPasswordType {
        get {
            enumSetting(setting: .kPasswordType, defaultValue: .complex)
        }
        set {
            self[.kPasswordType] = newValue.rawValue
        }
    }

    public var passwordInputWrongCounter: Int {
        get {
            self[.kPasswordInputWrongCounter] ?? 0
        }
        set {
            self[.kPasswordInputWrongCounter] = newValue
        }
    }

    public func setPasswordTriesDefault(_ value: DPAGSettingPasswordRetry) {
        self[.kPasswordTriesDefault] = value.rawValue
        self.resetPasswordTries()
    }

    public func getPasswordRetries() -> DPAGSettingPasswordRetry {
        DPAGSettingPasswordRetry(rawValue: max(DPAGSettingPasswordRetry.three.rawValue, self[.kPasswordTriesDefault] ?? 0)) ?? .three
    }

    public func resetPasswordTries() {
        self[.kPasswordTriesLeft] = self.getPasswordRetries().rawValue
    }

    public var passwordRetriesLeft: Int {
        get {
            self[.kPasswordTriesLeft] ?? 0
        }
        set {
            self[.kPasswordTriesLeft] = newValue
        }
    }

    public var trackingEnabled: Bool {
        get {
            // Das SIMSme Tracking gibts in allen Mandanten
            return self[.kTrackingEnabled] ?? false
        }
        set {
            self[.kTrackingEnabled] = newValue
        }
    }

    public var deleteData: Bool {
        get {
            self[.kDeleteData] ?? false
        }
        set {
            self[.kDeleteData] = newValue
        }
    }

    public var serverConfiguration: [AnyHashable: Any]? {
        get {
            self[.kServerConfiguration] as? [AnyHashable: Any]
        }
        set {
            self[.kServerConfiguration] = newValue
        }
    }

    private func getServerConfigIntWithKey(_ key: String, defaultValue: Int) -> Int {
        if let dictionary = self.serverConfiguration, let dictVal = dictionary[key] as? String, let intVal = Int(dictVal) {
            return intVal
        }
        return defaultValue
    }

    public var listRefreshRate: Int {
        self.getServerConfigIntWithKey("listRefreshRate", defaultValue: DPAGPreferences.kValueTimerCheckForNewMessagesInChatsList)
    }

    public var maxGroupMembers: Int {
        self.getServerConfigIntWithKey("maximumRoomMember", defaultValue: DPAGPreferences.kValueMaxGroupMemberInChatRoom)
    }

    public var streamRefreshRate: Int {
        self.getServerConfigIntWithKey("streamRefreshRate", defaultValue: DPAGPreferences.kValueTimerCheckForNewMessagesInChatStream)
    }

    public var lazyGetTimeout: Int {
        self.getServerConfigIntWithKey("lazyGetTimeout", defaultValue: DPAGPreferences.kValueTimeoutLazyService)
    }

    public var lazyMsgServiceEnabled: Bool {
        self.getServerConfigIntWithKey("useLazyMsgService", defaultValue: 1) == 1
    }

    public var persistMessageDays: Int {
        self.getServerConfigIntWithKey("persistMessageDays", defaultValue: 90)
    }

    public var maxClients: Int {
        self.getServerConfigIntWithKey("maxClients", defaultValue: 10)
    }

    public var autoGeneratedMessages: Bool {
        get {
            self[.kAutoGeneratedMessagesEnabled] ?? false
        }
        set {
            self[.kAutoGeneratedMessagesEnabled] = newValue
        }
    }

    public var lockApplicationImmediately: Bool {
        var lock = self.passwordOnStartEnabled && self.applicationLockDelay.rawValue <= 0
        let accountDAO: AccountDAOProtocol = AccountDAO()
        if let accountState = accountDAO.getAccountState() {
            lock = (lock && accountState == .confirmed)
        } else {
            lock = false
        }
        return lock
    }

    public var applicationLockDelay: DPAGSettingLockDelay {
        get {
            enumSetting(setting: .kLockApplicationDelay, defaultValue: .zero)
        }
        set {
            self[.kLockApplicationDelay] = newValue.rawValue
        }
    }

    public var passwordOnStartEnabled: Bool {
        get {
            (self[.kDisablePassword] ?? false) == false
        }
        set {
            if newValue {
                self[.kDisablePassword] = false
                CryptoHelper.sharedInstance?.deleteDecryptedPrivateKeyinKeyChain()
            } else {
                try? CryptoHelper.sharedInstance?.putDecryptedPKFromHeapInKeyChain()
                self[.kDisablePassword] = true
            }
        }
    }

    public var hasSystemGeneratedPassword: Bool {
        get {
            self[.kSystemGeneratedPassword] ?? false
        }
        set {
            self[.kSystemGeneratedPassword] = newValue
        }
    }

    public var cameraBackgroundEnabled: Bool {
        get {
            self[.kCameraBackground] ?? false
        }
        set {
            self[.kCameraBackground] = newValue
        }
    }

    public var alreadyAskedForPush: Bool {
        get {
            self[.kAlreadyAskedForPush] ?? false
        }
        set {
            self[.kAlreadyAskedForPush] = newValue
        }
    }

    public var alreadyAskedForMic: Bool {
        get {
            self[.kAlreadyAskedForMic] ?? false
        }
        set {
            self[.kAlreadyAskedForMic] = newValue
        }
    }

    public var proximityMonitoringEnabled: Bool {
        get {
            self[.kProximityMonitoring] ?? false
        }
        set {
            self[.kProximityMonitoring] = newValue
        }
    }

    public var markMessagesAsReadEnabled: Bool {
        get {
            self[.kMarkMessagesAsRead] ?? true
        }
        set {
            self[.kMarkMessagesAsRead] = newValue
        }
    }

    public var shouldInviteFriendsAfterInstall: Bool {
        get {
            self[.kInviteFriendsAfterInstall] ?? false
        }
        set {
            self[.kInviteFriendsAfterInstall] = newValue
        }
    }

    public var shouldInviteFriendsAfterChatPrivateCreation: Bool {
        get {
            self[.kInviteFriendsAfterChatPrivateCreation] ?? false
        }
        set {
            self[.kInviteFriendsAfterChatPrivateCreation] = newValue
        }
    }

    public var chatPrivateCreationCount: Int {
        get {
            self[.kChatPrivateCreationCount] ?? 0
        }
        set {
            self[.kChatPrivateCreationCount] = newValue
        }
    }

    var createdPrivateChats: [String: Bool] = [:]

    public func setChatPrivateCreationAccount(_ accountGuid: String) {
        self.createdPrivateChats[accountGuid] = false
    }

    public func setChatPrivateCreationAccountSendMessage(_ accountGuid: String) {
        if let alreadyCount = self.createdPrivateChats[accountGuid] {
            if alreadyCount == false {
                self.createdPrivateChats[accountGuid] = true
                self.chatPrivateCreationCount += 1
            }
        }
    }

    public var chatGroupCreationCount: Int {
        get {
            self[.kChatGroupCreationCount] ?? 0
        }
        set {
            self[.kChatGroupCreationCount] = newValue
        }
    }

    public var touchIDEnabled: Bool {
        get {
            KeychainKeyValueStore.sharedInstance().storedBoolValue(forKey: DPAGPreferences.kPreferenceTouchId)
        }
        set {
            KeychainKeyValueStore.sharedInstance().storeBoolValue(newValue, forKey: DPAGPreferences.kPreferenceTouchId)

            if newValue {
                try? CryptoHelper.sharedInstance?.putDecryptedPKFromHeapInKeyChainForTouchID()
            } else {
                CryptoHelper.sharedInstance?.deleteDecryptedPrivateKeyForTouchID()
            }
        }
    }

    public var hasSimsmeRecoveryEnabledSMS: Bool {
        if let data = self[.kSimsmeRecoveryPhone] {
            return !data.isEmpty
        }
        return false
    }

    public var hasSimsmeRecoveryEnabledMail: Bool {
        if let data = self[.kSimsmeRecoveryMail] {
            return !data.isEmpty
        }
        return false
    }

    public func getSimsmeRecoveryData(email: Bool) -> [String: String]? {
        var data: String?
        if email {
            data = self[.kSimsmeRecoveryMail]
        } else {
            data = self[.kSimsmeRecoveryPhone]
        }
        guard let dataStr = data?.data(using: .utf8) else { return nil }
        var rc: [String: String]?
        do {
            rc = try JSONSerialization.jsonObject(with: dataStr, options: JSONSerialization.ReadingOptions.allowFragments) as? [String: String]
        } catch let error as NSError {
            DPAGLog("getSimsmeRecoveryData-error: %@", error.localizedDescription)
        }
        return rc
    }

    public var simsmeRecoveryEnabled: Bool {
        get {
            self[.kSimsmeRecovery] ?? false
        }
        set {
            self[.kSimsmeRecovery] = newValue
            if newValue {
                try? self.createSimsmeRecoveryBlobs()
            } else {
                _ = try? CryptoHelper.sharedInstance?.deleteBackupPrivateKey(mode: .miniBackup)
                self[.kSimsmeRecoveryPhone] = nil
                self[.kSimsmeRecoveryMail] = nil
            }
        }
    }

    public var simsmePublicKey: String? {
        get {
            self[.kSimsmePublicKey]
        }
        set {
            self[.kSimsmePublicKey] = newValue
            if self.simsmeRecoveryEnabled {
                try? self.createSimsmeRecoveryBlobs()
            }
        }
    }

    public func createSimsmeRecoveryBlobs() throws {
        guard self.simsmeRecoveryEnabled else { return }
        guard let simsmePublicKey = self.simsmePublicKey, let ownGuid = DPAGApplicationFacade.cache.account?.guid, let ownContact = DPAGApplicationFacade.cache.contact(for: ownGuid), let ownPublicKey = ownContact.publicKey, let accountCrypto = DPAGCryptoHelper.newAccountCrypto() else { return }
        guard ownContact.phoneNumber != nil || ownContact.eMailAddress != nil else { return }
        guard let deviceCrypto = CryptoHelper.sharedInstance else { return }
        let backupPassword = deviceCrypto.simsmeRecoveryPassword()
        var transId = ownPublicKey + (try deviceCrypto.getPublicKeyFromPrivateKey())
        transId = transId.sha256()
        let backupPasswordEncrypted = try CryptoHelperEncrypter.encrypt(string: backupPassword, withPublicKey: simsmePublicKey)
        try deviceCrypto.backupPrivateKey(withPassword: backupPassword, backupMode: .miniBackup)
        if let phoneNumber = ownContact.phoneNumber {
            let phoneNumberEncrypted = try CryptoHelperEncrypter.encrypt(string: phoneNumber, withPublicKey: simsmePublicKey)
            let sig = transId + backupPasswordEncrypted
            let signature = try accountCrypto.signData256(data: sig)
            let jsonPhoneDict: [AnyHashable: Any] = [
                "transId": transId,
                "recoveryToken": backupPasswordEncrypted,
                "recoveryChannel": phoneNumberEncrypted,
                "sig": signature
            ]
            if let json = jsonPhoneDict.JSONString {
                self[.kSimsmeRecoveryPhone] = json
            }
        }
        if let email = ownContact.eMailAddress {
            let eMailEncrypted = try CryptoHelperEncrypter.encrypt(string: email, withPublicKey: simsmePublicKey)
            let sig = transId + backupPasswordEncrypted
            let signature = try accountCrypto.signData256(data: sig)
            let jsonPhoneDict: [AnyHashable: Any] = [
                "transId": transId,
                "recoveryToken": backupPasswordEncrypted,
                "recoveryChannel": eMailEncrypted,
                "sig": signature
            ]
            if let json = jsonPhoneDict.JSONString {
                self[.kSimsmeRecoveryMail] = json
            }
        }
    }

    public func createCompanyRecoveryBlobs() throws {
        guard let companyPublicKey = DPAGApplicationFacade.cache.account?.companyPublicKey else { return }
        guard let backupPassword = CryptoHelper.sharedInstance?.companyRecoveryPassword() else { return }
        let backupPasswordEncrypted = try CryptoHelperEncrypter.encrypt(string: backupPassword, withPublicKey: companyPublicKey)
        try CryptoHelper.sharedInstance?.backupPrivateKey(withPassword: backupPassword, backupMode: .fullBackup)
        self[.kSimsmeRecoveryAdmin] = backupPasswordEncrypted
    }

    public func ensureRecoveryBlobs() throws {
        if DPAGApplicationFacade.preferences.isRecoveryDisabled {
            return
        }
        if self.simsmeRecoveryEnabled {
            if self[.kSimsmeRecoveryMail] == nil, self[.kSimsmeRecoveryPhone] == nil {
                try self.updateRecoveryBlobs()
            }
            if let ownGuid = DPAGApplicationFacade.cache.account?.guid, let ownContact = DPAGApplicationFacade.cache.contact(for: ownGuid) {
                if ownContact.phoneNumber == nil, self[.kSimsmeRecoveryPhone] != nil {
                    self[.kSimsmeRecoveryPhone] = nil
                }
                if ownContact.eMailAddress == nil, self[.kSimsmeRecoveryMail] != nil {
                    self[.kSimsmeRecoveryMail] = nil
                }
            }
        }
        guard DPAGApplicationFacade.cache.account?.companyPublicKey != nil else { return }
        if self[.kSimsmeRecoveryAdmin] != nil {
            return
        }
        try self.updateRecoveryBlobs()
    }

    public func updateRecoveryBlobs() throws {
        try self.createSimsmeRecoveryBlobs()
        try self.createCompanyRecoveryBlobs()
    }

    public func getCompanyRecoveryKey() -> String? {
        if let rc = self[.kSimsmeRecoveryAdmin] {
            return rc
        }
        return nil
    }

    public var lastSuccessFullSyncPrivateIndex: String? {
        get {
            self[.kLastSuccessFullSyncPrivateIndex]
        }
        set {
            self[.kLastSuccessFullSyncPrivateIndex] = newValue
        }
    }

    public var shareExtensionDevicePasstoken: String? {
        get {
            self[.kShareExtensionDevicePasstoken]
        }
        set {
            self[.kShareExtensionDevicePasstoken] = newValue
        }
    }

    public var shareExtensionDeviceGuid: String? {
        get {
            self[.kShareExtensionDeviceGuid]
        }
        set {
            self[.kShareExtensionDeviceGuid] = newValue
        }
    }

    public var isShareExtensionEnabled: Bool {
        get {
            if let temp = self[.kShareExtensionEnabled] {
                return (temp != DPAGPreferences.kValueNotificationDisabled) && self.shareExtensionDeviceGuid != nil && self.shareExtensionDevicePasstoken != nil
            }
            return false
        }
        set {
            self[.kShareExtensionEnabled] = newValue ? DPAGPreferences.kValueNotificationEnabled : DPAGPreferences.kValueNotificationDisabled
            if newValue {
                let queryDelete: [String: AnyObject] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrAccount as String: DPAGSharedContainerExtensionSending.itemKey as AnyObject,
                    kSecAttrAccessGroup as String: self.sharedContainerConfig.keychainAccessGroupName as AnyObject
                ]
                let resultCodeDelete = SecItemDelete(queryDelete as CFDictionary)
                if resultCodeDelete != noErr {
                    DPAGLog("Error deleting from Keychain: \(resultCodeDelete)")
                }
                DPAGApplicationFacade.sharedContainerSending.deleteData(config: self.sharedContainerConfig, filename: DPAGApplicationFacade.sharedContainerSending.fileName)
                guard let itemValue = try? DPAGCryptoHelper.newAccountCrypto()?.getDecryptedPKInKeyChainForPushPreview() else { return }
                guard let valueData = itemValue.data(using: .utf8) else {
                    DPAGLog("Error saving text to Keychain")
                    return
                }
                let queryAdd: [String: AnyObject] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrAccount as String: DPAGSharedContainerExtensionSending.itemKey as AnyObject,
                    kSecValueData as String: valueData as AnyObject,
                    kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
                    kSecAttrAccessGroup as String: self.sharedContainerConfig.keychainAccessGroupName as AnyObject
                ]
                let resultCode = SecItemAdd(queryAdd as CFDictionary, nil)
                if resultCode != noErr {
                    DPAGLog("Error saving to Keychain: \(resultCode)")
                }
            } else {
                let queryDelete: [String: AnyObject] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrAccount as String: DPAGSharedContainerExtensionSending.itemKey as AnyObject,
                    kSecAttrAccessGroup as String: self.sharedContainerConfig.keychainAccessGroupName as AnyObject
                ]
                let resultCodeDelete = SecItemDelete(queryDelete as CFDictionary)
                if resultCodeDelete != noErr {
                    DPAGLog("Error deleting from Keychain: \(resultCodeDelete)")
                }
                DPAGApplicationFacade.sharedContainerSending.deleteData(config: self.sharedContainerConfig, filename: DPAGApplicationFacade.sharedContainerSending.fileName)
            }
        }
    }

    public var previewPushNotification: Bool {
        get {
            if let temp = self[.kPreviewPushNotificationEnabled] {
                return temp != DPAGPreferences.kValueNotificationDisabled
            }
            return false
        }
        set {
            self[.kPreviewPushNotificationEnabled] = newValue ? DPAGPreferences.kValueNotificationEnabled : DPAGPreferences.kValueNotificationDisabled
            if newValue {
                let queryDelete: [String: AnyObject] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrAccount as String: DPAGSharedContainerExtension.itemKey as AnyObject,
                    kSecAttrAccessGroup as String: self.sharedContainerConfig.keychainAccessGroupName as AnyObject
                ]
                let resultCodeDelete = SecItemDelete(queryDelete as CFDictionary)
                if resultCodeDelete != noErr {
                    DPAGLog("Error deleting from Keychain: \(resultCodeDelete)")
                }
                DPAGApplicationFacade.sharedContainer.deleteData(config: self.sharedContainerConfig, filename: DPAGApplicationFacade.sharedContainer.fileName)
                guard let itemValue = try? DPAGCryptoHelper.newAccountCrypto()?.getDecryptedPKInKeyChainForPushPreview() else { return }
                guard let valueData = itemValue.data(using: .utf8) else {
                    DPAGLog("Error saving text to Keychain")
                    return
                }
                let queryAdd: [String: AnyObject] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrAccount as String: DPAGSharedContainerExtension.itemKey as AnyObject,
                    kSecValueData as String: valueData as AnyObject,
                    kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
                    kSecAttrAccessGroup as String: self.sharedContainerConfig.keychainAccessGroupName as AnyObject
                ]
                let resultCode = SecItemAdd(queryAdd as CFDictionary, nil)
                if resultCode != noErr {
                    DPAGLog("Error saving to Keychain: \(resultCode)")
                }
            }
        }
    }

    private var mandantenDictInternal: [String: DPAGMandant]?

    public var mandantenDict: [String: DPAGMandant] {
        if let mandantenDict = self.mandantenDictInternal {
            return mandantenDict
        }
        var retVal: [String: DPAGMandant] = [:]
        if let mandantenData = self[.kMandanten] as? Data {
            tryC {
                if let mandanten = NSKeyedUnarchiver.unarchiveObject(with: mandantenData) as? [DPAGMandant] {
                    for mandant in mandanten {
                        retVal[mandant.ident] = mandant
                    }
                }
            }
            .catch { _ in
            }
            .finally {}
            if retVal.count > 0 {
                self.mandantenDictInternal = retVal
                return retVal
            }
        }
        let mandant = DPAGMandant.default
        return [mandant.ident: mandant]
    }

    public var mandanten: [DPAGMandant] {
        get {
            if let mandantenData = self[.kMandanten] as? Data {
                var retVal: [DPAGMandant]?
                tryC {
                    if let mandanten = NSKeyedUnarchiver.unarchiveObject(with: mandantenData) as? [DPAGMandant] {
                        retVal = mandanten
                    }
                }
                .catch { _ in
                }
                .finally {}
                if (retVal?.count ?? 0) > 0 {
                    if let mandanten = retVal {
                        return mandanten
                    }
                }
            }
            return [DPAGMandant.default]
        }
        set {
            self[.kMandanten] = NSKeyedArchiver.archivedData(withRootObject: newValue)
        }
    }

    public var accountRegisteredAt: Date {
        get {
            self[.kAccountRegisteredAtDateTime] ?? Date.distantFuture
        }
        set {
            self[.kAccountRegisteredAtDateTime] = newValue
        }
    }

    public let defaultSentImageQuality: DPAGSettingSentImageQuality = .medium

    public var sentImageQuality: DPAGSettingSentImageQuality {
        get {
            self.enumSetting(setting: .kSentImageQuality, defaultValue: self.defaultSentImageQuality)
        }
        set {
            self[.kSentImageQuality] = newValue.rawValue
        }
    }

    public func resetSentImageQuality() {
        self[.kSentImageQuality] = nil
    }

    public let defaultAutoDownloadSettingFoto: DPAGSettingAutoDownload = .wifiAndMobile

    public var autoDownloadSettingFoto: DPAGSettingAutoDownload {
        get {
            self.enumSetting(setting: .kAutoDownloadSettingFoto, defaultValue: self.defaultAutoDownloadSettingFoto)
        }
        set {
            self[.kAutoDownloadSettingFoto] = newValue.rawValue
        }
    }

    public func resetAutoDownloadSettingFoto() {
        self[.kAutoDownloadSettingFoto] = nil
    }

    public let defaultAutoDownloadSettingAudio: DPAGSettingAutoDownload = .wifi

    public var autoDownloadSettingAudio: DPAGSettingAutoDownload {
        get {
            self.enumSetting(setting: .kAutoDownloadSettingAudio, defaultValue: self.defaultAutoDownloadSettingAudio)
        }
        set {
            self[.kAutoDownloadSettingAudio] = newValue.rawValue
        }
    }

    public func resetAutoDownloadSettingAudio() {
        self[.kAutoDownloadSettingAudio] = nil
    }

    public let defaultAutoDownloadSettingVideo: DPAGSettingAutoDownload = .wifi

    public var autoDownloadSettingVideo: DPAGSettingAutoDownload {
        get {
            self.enumSetting(setting: .kAutoDownloadSettingVideo, defaultValue: self.defaultAutoDownloadSettingVideo)
        }
        set {
            self[.kAutoDownloadSettingVideo] = newValue.rawValue
        }
    }

    public func resetAutoDownloadSettingVideo() {
        self[.kAutoDownloadSettingVideo] = nil
    }

    public let defaultAutoDownloadSettingFile: DPAGSettingAutoDownload = .wifi

    public var autoDownloadSettingFile: DPAGSettingAutoDownload {
        get {
            self.enumSetting(setting: .kAutoDownloadSettingFile, defaultValue: self.defaultAutoDownloadSettingFile)
        }
        set {
            self[.kAutoDownloadSettingFile] = newValue.rawValue
        }
    }

    public func resetAutoDownloadSettingFile() {
        self[.kAutoDownloadSettingFile] = nil
    }

    public var imageOptionsForSending: DPAGImageOptions {
        switch self.sentImageQuality {
            case .small:
                return DPAGImageOptions(size: self.sizeForSentImages, quality: self.qualityForSentImages, interpolationQuality: self.interpolationQualityForSentImages.rawValue)
            case .medium:
                return DPAGImageOptions(size: self.sizeForSentImages, quality: self.qualityForSentImages, interpolationQuality: self.interpolationQualityForSentImages.rawValue)
            case .large:
                return DPAGImageOptions(size: self.sizeForSentImages, quality: self.qualityForSentImages, interpolationQuality: self.interpolationQualityForSentImages.rawValue)
            case .extraLarge:
                return DPAGImageOptions(size: self.sizeForSentImages, quality: self.qualityForSentImages, interpolationQuality: self.interpolationQualityForSentImages.rawValue)
        }
    }

    public var sizeForSentImages: CGSize {
        switch self.sentImageQuality {
            case .small:
                return CGSize(width: 1_024, height: 1_024)
            case .medium:
                return CGSize(width: 1_920, height: 1_920)
            case .large:
                return CGSize(width: 2_048, height: 2_048)
            case .extraLarge:
                return CGSize(width: 4_096, height: 4_096)
        }
    }

    public var qualityForSentImages: CGFloat {
        switch self.sentImageQuality {
            case .small:
                return 0.7
            case .medium:
                return 0.75
            case .large:
                return 0.8
            case .extraLarge:
                return 0.9
            }
    }

    public var interpolationQualityForSentImages: CGInterpolationQuality {
        switch self.sentImageQuality {
            case .small:
                return .low
            case .medium:
                return .medium
            case .large:
                return .high
            case .extraLarge:
                return .high
        }
    }

    public let defaultSentVideoQuality: DPAGSettingSentVideoQuality = .medium

    public var sentVideoQuality: DPAGSettingSentVideoQuality {
        get {
            self.enumSetting(setting: .kSentVideoQuality, defaultValue: self.defaultSentVideoQuality)
        }
        set {
            self[.kSentVideoQuality] = newValue.rawValue
        }
    }

    public func resetSentVideoQuality() {
        self[.kSentVideoQuality] = nil
    }

    public var videoOptionsForSending: DPAGVideoOptions {
        switch self.sentVideoQuality {
            case .small:
                return DPAGVideoOptions(size: CGSize(width: 640, height: 360), bitrate: 600_000, fps: 20, profileLevel: AVVideoProfileLevelH264Baseline30)
            case .medium:
                return DPAGVideoOptions(size: CGSize(width: 854, height: 480), bitrate: 800_000, fps: 30, profileLevel: AVVideoProfileLevelH264Baseline41)
            case .large:
                return DPAGVideoOptions(size: CGSize(width: 1_280, height: 720), bitrate: 1_200_000, fps: 30, profileLevel: AVVideoProfileLevelH264Baseline41)
            case .extraLarge:
                return DPAGVideoOptions(size: CGSize(width: 1_280, height: 720), bitrate: 1_600_000, fps: 30, profileLevel: AVVideoProfileLevelH264Baseline41)
        }
    }

    public var maxLengthForSentVideos: TimeInterval {
        self.maxLengthForSentVideos(videoQuality: self.sentVideoQuality)
    }

    public func maxLengthForSentVideos(videoQuality: DPAGSettingSentVideoQuality) -> TimeInterval {
        switch videoQuality {
            case .small:
                return 240
            case .medium:
                return 180
            case .large:
                return 120
            case .extraLarge:
                return 90
        }
    }

    public var videoQualityForSentVideos: UIImagePickerController.QualityType {
        switch self.sentVideoQuality {
            case .small:
                return .typeIFrame960x540
            case .medium:
                return .typeIFrame960x540
            case .large:
                return .typeIFrame1280x720
            case .extraLarge:
                return .typeIFrame1280x720
        }
    }

    public var maximumNumberOfMediaAttachments: Int {
        10
    }

    public enum DPAGMigrationVersion: Int {
        case versionNoVersion = 0,
            version3Dot3 = 3_003_000

        public static let versionCurrent = DPAGMigrationVersion.version3Dot3
    }

    public var migrationVersion: DPAGMigrationVersion {
        get {
            enumSetting(setting: .kMigrationVersion, defaultValue: .version3Dot3)
        }
        set {
            self[.kMigrationVersion] = newValue.rawValue
        }
    }

    public let streamVisibilityNew = false

    public let streamVisibilitySingle = true

    public let streamVisibilityGroup = true

    public let streamVisibilityChannel = true

    public func clearBootStrapping() {
        self[.kBootstrappingCheckBackup] = nil
        self[.kBootstrappingOverride] = nil
        self[.kBootstrappingConfirmationCode] = nil
        self[.kBootstrappingSkipWarningOverride] = nil

        self[.kBootstrappingOldAccountID] = nil
        self[.kBootstrappingAvailableAccountID] = nil
    }

    public func setBootstrappingCheckbackup(_ check: Bool) {
        self[.kBootstrappingCheckBackup] = check
    }

    public var bootstrappingOverrideAccount: Bool {
        get {
            self[.kBootstrappingOverride] ?? false
        }
        set {
            self[.kBootstrappingOverride] = newValue
        }
    }

    public var bootstrappingConfirmationCode: String? {
        get {
            self[.kBootstrappingConfirmationCode]
        }
        set {
            self[.kBootstrappingConfirmationCode] = newValue
        }
    }

    public var bootstrappingSkipWarningOverrideAccount: Bool {
        get {
            self[.kBootstrappingSkipWarningOverride] ?? false
        }
        set {
            self[.kBootstrappingSkipWarningOverride] = newValue
        }
    }

    public var bootstrappingAvailableAccountID: [String]? {
        get {
            self[.kBootstrappingAvailableAccountID] as? [String]
        }
        set {
            self[.kBootstrappingAvailableAccountID] = newValue
        }
    }

    public var bootstrappingOldAccountID: String? {
        get {
            self[.kBootstrappingOldAccountID]
        }
        set {
            self[.kBootstrappingOldAccountID] = newValue
        }
    }

    private static let LRU_SIZE = 100

    public var lastRecentlyUsedContactsPrivate: [String] {
        self[.kLastRecentlyUsedContactsPrivate] as? [String] ?? []
    }

    private func add(string: String, toLRU lruFixed: [String]) -> [String] {
        var lru = lruFixed

        if let idx = lru.firstIndex(of: string) {
            lru.remove(at: idx)
        }
        lru.insert(string, at: 0)

        if lru.count > DPAGPreferences.LRU_SIZE {
            lru.removeLast()
        }

        return lru
    }

    public func addLastRecentlyUsed(contacts: [DPAGContact], withNotification: Bool = true) {
        var addedPrivate = false
        var addedCompany = false
        var addedDomain = false

        for contact in contacts {
            switch contact.entryTypeServer {
            case .privat:
                self[.kLastRecentlyUsedContactsPrivate] = self.add(string: contact.guid, toLRU: self.lastRecentlyUsedContactsPrivate)
                addedPrivate = true
            case .company:
                self[.kLastRecentlyUsedContactsCompany] = self.add(string: contact.guid, toLRU: self.lastRecentlyUsedContactsCompany)
                addedCompany = true
                if let account = DPAGApplicationFacade.cache.account, let contactAccount = DPAGApplicationFacade.cache.contact(for: account.guid), contactAccount.eMailDomain != nil, contactAccount.eMailDomain == contact.eMailDomain {
                    self[.kLastRecentlyUsedContactsDomain] = self.add(string: contact.guid, toLRU: self.lastRecentlyUsedContactsDomain)
                    addedDomain = true
                }
            case .email:
                self[.kLastRecentlyUsedContactsDomain] = self.add(string: contact.guid, toLRU: self.lastRecentlyUsedContactsDomain)
                addedDomain = true
            case .meMyselfAndI:
                break
            }
        }
        if withNotification {
            if addedPrivate {
                NotificationCenter.default.post(name: DPAGStrings.Notification.Contact.LRU_ADDED_PRIVATE, object: nil)
            }
            if addedCompany {
                NotificationCenter.default.post(name: DPAGStrings.Notification.Contact.LRU_ADDED_COMPANY, object: nil)
            }
            if addedDomain {
                NotificationCenter.default.post(name: DPAGStrings.Notification.Contact.LRU_ADDED_DOMAIN, object: nil)
            }
        }
    }

    public var lastRecentlyUsedContactsCompany: [String] {
        self[.kLastRecentlyUsedContactsCompany] as? [String] ?? []
    }

    public var lastRecentlyUsedContactsDomain: [String] {
        self[.kLastRecentlyUsedContactsDomain] as? [String] ?? []
    }

    public func wasChannelSubscribed(_ channelGuid: String) -> Bool {
        let key = "channelSubscribed_" + channelGuid

        return (UserDefaults.standard.object(forKey: key) as? Bool) ?? false
    }

    public func rememberChannelSubscribed(_ channelGuid: String) {
        let key = "channelSubscribed_" + channelGuid

        UserDefaults.standard.set(true, forKey: key)
    }

    public func isChatNotificationSoundEnabled(chatType: DPAGNotificationChatType) -> Bool {
        if !self.isChatNotificationEnabled(chatType: chatType) {
            return false
        }

        let key: DPAGPreferences.PropString

        switch chatType {
            case .single:
                key = .kChatRingtone
            case .group:
                key = .kGroupChatRingtone
            case .channel:
                key = .kChannelChatRingtone
            case .service:
                key = .kServiceChatRingtone
        }

        return self[key] != DPAGPreferences.kValueNotificationSoundNone
    }

    public func isChatNotificationEnabled(chatType: DPAGNotificationChatType) -> Bool {
        let key: DPAGPreferences.PropString

        switch chatType {
            case .single:
                key = .kNotificationChatEnabled
            case .group:
                key = .kNotificationGroupChatEnabled
            case .channel:
                key = .kNotificationChannelChatEnabled
            case .service:
                key = .kNotificationServiceChatEnabled
        }

        return self[key] != DPAGPreferences.kValueNotificationDisabled
    }

    public func isChatNotificationEnabled(feedType: DPAGChannelType, feedGuid: String) -> Bool {
        let key: String

        switch feedType {
            case .channel:
                key = String(format: "%@-%@", feedGuid, PropString.kNotificationChannelChatEnabled.rawValue)
            case .service:
                key = String(format: "%@-%@", feedGuid, PropString.kNotificationServiceChatEnabled.rawValue)
        }

        return (UserDefaults.standard.object(forKey: key) as? String) != DPAGPreferences.kValueNotificationDisabled
    }

    public var isInAppNotificationEnabled: Bool {
        get {
            self[.kNotificationInAppEnabled] != DPAGPreferences.kValueNotificationDisabled
        }
        set {
            self[.kNotificationInAppEnabled] = newValue ? DPAGPreferences.kValueNotificationEnabled : DPAGPreferences.kValueNotificationDisabled
        }
    }

    public func setProfileInfoServerNeedsUpdate() {
        var serverInfoSyncFlags = DPAGPreferencesServerSyncFlags(rawValue: self[.kServerSyncFlags] ?? DPAGPreferencesServerSyncFlags.none.rawValue)

        serverInfoSyncFlags.formUnion(.profileInfo)

        self[.kServerSyncFlags] = serverInfoSyncFlags.rawValue
    }

    public func resetProfileInfoServerNeedsUpdate() {
        var serverInfoSyncFlags = DPAGPreferencesServerSyncFlags(rawValue: self[.kServerSyncFlags] ?? DPAGPreferencesServerSyncFlags.none.rawValue)

        serverInfoSyncFlags.remove(.profileInfo)

        self[.kServerSyncFlags] = serverInfoSyncFlags.rawValue
    }

    public func doesProfileInfoServerNeedUpdate() -> Bool {
        let serverInfoSyncFlags = DPAGPreferencesServerSyncFlags(rawValue: self[.kServerSyncFlags] ?? DPAGPreferencesServerSyncFlags.none.rawValue)

        return serverInfoSyncFlags.contains(.profileInfo)
    }

    public func resetGroupSynchronizations() {
        self[.kLastGroupSynchronizationDates] = nil
    }

    public func needsGroupSynchronization(forGroupGuid groupGuid: String) -> Bool {
        if let groupSyncDates = self[.kLastGroupSynchronizationDates] as? [String: Any], let groupSyncDate = groupSyncDates[groupGuid] as? Date {
            if groupSyncDate.isToday() {
                return false
            }
        }
        return true
    }

    public func setNeedsGroupSynchronization(forGroupGuid groupGuid: String) {
        if let groupSyncDates = self[.kLastGroupSynchronizationDates] as? [String: Any] {
            if groupSyncDates[groupGuid] != nil {
                var groupSyncDatesNew = groupSyncDates

                groupSyncDatesNew.removeValue(forKey: groupGuid)

                self[.kLastGroupSynchronizationDates] = groupSyncDatesNew
            }
        }
    }

    public func setGroupSynchronizationDone(forGroupGuid groupGuid: String) {
        if let groupSyncDates = self[.kLastGroupSynchronizationDates] as? [String: Any] {
            var groupSyncDatesNew = groupSyncDates

            groupSyncDatesNew[groupGuid] = Date()

            self[.kLastGroupSynchronizationDates] = groupSyncDatesNew
        } else {
            let groupSyncDatesNew = [groupGuid: Date()]

            self[.kLastGroupSynchronizationDates] = groupSyncDatesNew
        }
    }

    public func needsProfileSynchronization(forProfileGuid profileGuid: String) -> Bool {
        if let profileSyncDates = self[.kLastProfileSynchronizationDates] as? [String: Any], let profileSyncDate = profileSyncDates[profileGuid] as? Date, profileSyncDate.isToday() {
            return false
        }
        return true
    }

    public func setNeedsProfileSynchronization(forProfileGuid profileGuid: String) {
        if let profileSyncDates = self[.kLastProfileSynchronizationDates] as? [String: Any] {
            if profileSyncDates[profileGuid] != nil {
                var profileSyncDatesNew = profileSyncDates

                profileSyncDatesNew.removeValue(forKey: profileGuid)

                self[.kLastProfileSynchronizationDates] = profileSyncDatesNew
            }
        }
    }

    public func setProfileSynchronizationDone(forProfileGuid profileGuid: String) {
        if let profileSyncDates = self[.kLastProfileSynchronizationDates] as? [String: Any] {
            var profileSyncDatesNew = profileSyncDates

            profileSyncDatesNew[profileGuid] = Date()

            self[.kLastProfileSynchronizationDates] = profileSyncDatesNew
        } else {
            let profileSyncDatesNew = [profileGuid: Date()]

            self[.kLastProfileSynchronizationDates] = profileSyncDatesNew
        }
    }

    public var didAskForCompanyEmail: Bool {
        get {
            (self[.kDidAskForCompanyEmail] ?? 0) == 1
        }
        set {
            self[.kDidAskForCompanyEmail] = newValue ? 1 : 0
        }
    }

    public var didAskForCompanyPhoneNumber: Bool {
        get {
            (self[.kDidAskForCompanyPhoneNumber] ?? 0) == 1
        }
        set {
            self[.kDidAskForCompanyPhoneNumber] = newValue ? 1 : 0
        }
    }

    // Company managed State -> cachen wegen performance
    public var isCompanyManagedState: Bool {
        get {
            (self[.kCompanyManagedState] ?? 0) == 1
        }
        set {
            // Cache neu laden
            if newValue != self.isCompanyManagedState {
                self.resetCacheVersions()
                self.forceUpdateCompanyIndex()
                self.forceNeedsConfigSynchronization()
            }
            self[.kCompanyManagedState] = newValue ? 1 : 0
        }
    }

    public var didAskForPushPreview: Bool {
        get {
            (self[.kDidAskForPushPreview] ?? 0) == 1
        }
        set {
            self[.kDidAskForPushPreview] = newValue ? 1 : 0
        }
    }

    public var didShowProfileInfo: Bool {
        get {
            self[.kDidShowProfileInfo] ?? false
        }
        set {
            self[.kDidShowProfileInfo] = newValue
        }
    }

    public var validationEmailAddress: String? {
        get {
            self[.kValidationEmail]
        }
        set {
            self[.kValidationEmail] = newValue
        }
    }

    public var validationEmailDomain: String? {
        get {
            self[.kValidationEmailDomain]
        }
        set {
            self[.kValidationEmailDomain] = newValue
        }
    }

    public var validationPhoneNumber: String? {
        get {
            self[.kValidationPhone]
        }
        set {
            self[.kValidationPhone] = newValue
        }
    }

    public var preferencesPasswordMinLength: Int? {
        get {
            self[.kPasswordMinLength]
        }
        set {
            self[.kPasswordMinLength] = newValue
        }
    }

    public var preferencesPasswordMinSpecialChar: Int? {
        get {
            self[.kPasswordMinSpecialChar]
        }
        set {
            self[.kPasswordMinSpecialChar] = newValue
        }
    }

    public var preferencesPasswordMinDigit: Int? {
        get {
            self[.kPasswordMinDigit]
        }
        set {
            self[.kPasswordMinDigit] = newValue
        }
    }

    public var preferencesPasswordMinLowercase: Int? {
        get {
            self[.kPasswordMinLowercase]
        }
        set {
            self[.kPasswordMinLowercase] = newValue
        }
    }

    public var preferencesPasswordMinUppercase: Int? {
        get {
            self[.kPasswordMinUppercase]
        }
        set {
            self[.kPasswordMinUppercase] = newValue
        }
    }

    public var preferencesPasswordMinClasses: Int? {
        get {
            self[.kPasswordMinClasses]
        }
        set {
            self[.kPasswordMinClasses] = newValue
        }
    }

    public var preferencesPasswordMaxDuration: Int? {
        get {
            self[.kPasswordMaxDuration]
        }
        set {
            self[.kPasswordMaxDuration] = newValue
        }
    }

    public var publicOnlineStateEnabled: Bool {
        get {
            self[.kPublicOnlineState] ?? false
        }
        set {
            self[.kPublicOnlineState] = newValue
        }
    }

    public var automaticMdmRegistrationValues: DPAGAutomaticRegistrationPreferences? {
        nil
    }

    public func resetDates() {
        self[.kLastContactSynchronization] = nil
        self[.kLastConfigSynchronization] = nil
        self[.kLastOwnOooStatusCheck] = nil
        self[.kDomainIndexSynchronisation] = nil
        self[.kLastBackgroundAccessTokenSynchronization] = nil
        self[.kLastDeviceTokenSynchronization] = nil
        self.addressInformationsCompanyDate = nil
    }

    public var isCrashReportEnabled: Bool {
        get {
            self[.kIsCrashReportEnabled] ?? true
        }
        set {
            self[.kIsCrashReportEnabled] = newValue
        }
    }

}
