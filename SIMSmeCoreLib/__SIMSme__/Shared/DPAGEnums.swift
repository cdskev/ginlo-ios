//
// Created by mg on 22.01.14.
// Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import UIKit

public protocol CaseCountable: CaseIterable {
    static var caseCount: Int { get }
}

extension CaseCountable where Self: RawRepresentable, Self.RawValue == Int {
    public static var caseCount: Int {
        self.allCases.count
    }

    public static func forIndex(_ index: Int) -> Self {
        guard let rowOrSection = Self(rawValue: index) else {
            fatalError("Enum value not found")
        }
        return rowOrSection
    }
}

enum DPAGServerAuthentication: Int {
    case none, standard, background, recovery
}

public struct DPAGImageOptions: Codable {
    public let size: CGSize
    public let quality: CGFloat
    public let interpolationQuality: Int32 // Codable, else CGInterpolationQuality
}

public struct DPAGVideoOptions: Codable {
    public var size: CGSize
    public let bitrate: Float
    public let fps: Float
    public let profileLevel: String
}

public struct DPAGMessageDictionaryAdditionalData {
    public var fileName: String?
    public var fileSize: String?
    public var fileSizeNum: NSNumber?
    public var fileType: String?
    public var encodingVersion: String?
    public var encodingVersionNum: Int?
}

@objc
public enum DPAGAccountState: Int {
    case unknown = -1,
        waitForConfirm = 0,
        confirmed,
        recoverBackup
}

public enum DPAGAccountCompanyEmailStatus: Int {
    case none = 0,
        wait_CONFIRM = 10,
        confirm_FAILED = 20,
        confirmed = 30
}

public enum DPAGAccountCompanyPhoneNumberStatus: Int {
    case none = 0,
        wait_CONFIRM = 10,
        confirm_FAILED = 20,
        confirmed = 30
}

public enum DPAGAccountCompanyManagedState: Int {
    case unknown,
        requested,
        declined,
        accepted,
        acceptedEmailRequired,
        acceptedPhoneRequired,
        acceptedEmailFailed,
        acceptedPhoneFailed,
        acceptedPendingValidation,
        accountDeleted
}

public enum DPAGGroupType: Int {
    case `default`,
        managed,
        restricted,
        announcement
}

public enum DPAGWhiteLabelNextView: Int {
    case dpagIntroViewController_handleFinishIntroTapped,
        dpagSimsMeController_startViewController,
        dpagProfileViewController_startCompanyProfilInitEMailController,
        dpagProfileViewController_startCompanyProfilConfirmEMailController,
        dpagProfileViewController_startCompanyProfilInitPhoneNumberController,
        dpagProfileViewController_startCompanyProfilConfirmPhoneNumberController,
        dpagTestLicenseViewController,
        dpagLicenseInitViewController,
        dpagPasswordForgotViewController
}

public enum DPAGWhiteLabelContactSelectionNextView: Int {
    case
        dpagNavigationDrawerViewController_startContactController,
        dpagNewChatViewController,
        dpagSelectGroupChatMembersAddViewController,
        dpagSelectDistributionListMembersViewController,
        dpagSelectReceiverViewController,
        dpagSelectContactSendingViewController
}

public struct DPAGMediaSelectionOptions: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let imageVideo = DPAGMediaSelectionOptions(rawValue: 1 << 0)
    public static let audio = DPAGMediaSelectionOptions(rawValue: 1 << 1)
    public static let file = DPAGMediaSelectionOptions(rawValue: 1 << 2)
}

public enum DPAGAttachmentType: UInt {
    case image,
        video,
        voiceRec,
        file,
        unknown
}

public typealias DPAGMediaResourceType = DPAGAttachmentType

public enum DPAGSettingSentImageQuality: Int, CaseCountable, CaseIterable {
    case small = 5,
        medium = 10,
        large = 15,
        extraLarge = 20
}

public enum DPAGSettingSentVideoQuality: Int, CaseCountable, CaseIterable {
    case small = 5,
        medium = 10,
        large = 15,
        extraLarge = 20
}

public enum DPAGSettingAutoDownload: Int, CaseCountable, CaseIterable {
    case wifiAndMobile = 5,
        wifi = 10,
        never = 15
}

public enum DPAGSettingRate: Int {
    case neverAsked,
        askLater,
        neverAskAgain
}

public enum DPAGSettingPasswordRetry: Int, CaseCountable, CaseIterable {
    case three = 3,
        five = 5,
        ten = 10
}

public enum DPAGSettingLockDelay: Int, CaseCountable, CaseIterable {
    case zero = 0,
        one = 1,
        five = 5,
        ten = 10
}

public enum DPAGSettingServerConfiguration: String {
    case kShowBusinessPromotion = "showBusinessPromotion"
}

public enum DPAGBackupInterval: Int {
    case daily,
        weekly,
        monthly,
        disabled
}

struct DPAGStreamOption: OptionSet {
    let rawValue: Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    static let filtered = DPAGStreamOption(rawValue: 0x1)
    static let hasUnreadMessages = DPAGStreamOption(rawValue: 0x2)
    static let blocked = DPAGStreamOption(rawValue: 0x4)
    static let hasUnreadHighPriorityMessages = DPAGStreamOption(rawValue: 0x8)
    static let isReadOnly = DPAGStreamOption(rawValue: 0x10)
}

public enum DPAGBannerType: Int {
    case unknown,
        business
}
        
public enum DPAGNotificationChatType: UInt {
    case single = 0,
        group,
        channel,
        service
}

public enum DPAGNotificationRegistrationState: Int {
    // Default
    case notAsked = 0,
        // The user denied access
        failed,
        // The delegate was not called
        pending,
        // Push is enabled, but the settings are not yet reset to default
        setDefaults,
        // Everything is ok
        allowed
}

public enum DPAGPasswordType: Int {
    case complex,
        pin,
        gesture
}

public enum DPAGMessageSecurityError: Int {
    case pendingTempDeviceInfo = -2,
        notChecked = -1,
        none = 0,
        hashesInvalid,
        signatureInvalid
}

public enum DPAGConfidenceState: UInt {
    case none,
        low,
        middle,
        high
}

struct DPAGContactStateMask: OptionSet {
    let rawValue: Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    static let complete = DPAGContactStateMask(rawValue: 0x1)
    static let incomplete = DPAGContactStateMask(rawValue: 0x2)
    static let blocked = DPAGContactStateMask(rawValue: 0x4)
}

public enum DPAGMessageState: UInt {
    case undefined = 0,
        sending,
        sentSucceeded,
        sentFailed
}

public enum DPAGStreamType: Int {
    case unknown = -1,
        single,
        group,
        channel
}

public enum DPAGMessageType: Int {
    case unknown = -1,
        `private`,
        group,
        channel
}

public enum DPAGChannelType: Int {
    case channel = 0,
        service
}

public enum DPAGInternalError: UInt {
    case messageDictionaryInvalid = 463,
        messageHashesInvalid = 464,
        messageDataInvalid = 465
}

public enum DPAGChatStreamState: UInt {
    case read,
        write,
        readOnly
}

public enum DPAGSendObjectMediaSourceType: UInt {
    case none,
        simsme,
        camera,
        album,
        file
}

public enum DPAGMessageFeatureVersion: UInt {
    case noFeature = 0,
        voiceRec,
        publicProfile,
        file,
        pushBadgeOnly,
        pushWithParameter,
        sixSkipped,
        confirmGroupMessages,
        disabledSystemInfo,
        managedRestrictedGroupInvPush,
        multiDeviceSupport,
        tempDeviceSupport,
        oooStatusMessages,
        thirteenSkipped,
        textRSS
}

struct DPAGMessageOptions: OptionSet {
    let rawValue: Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    static let priorityHigh = DPAGMessageOptions(rawValue: 0x1)
}

public enum DPAGQRCodeVersion: Int {
    case v1,
        v2
}

public enum DPAGGuidPrefix: String {
    case none = "",
        account = "0:",
        group = "1:",
        device = "3:",
        key = "4:",
        attachment = "6:",
        streamGroup = "7:",
        streamChannel = "21:",
        streamService = "22:",
        messageChat = "100:",
        messageGroup = "101:",
        messagePrivateInternal = "102:",
        messageInternal = "103:",
        messageInternalPrioOne = "104:",
        messageChannel = "110:",
        messageService = "111:",
        messageConfirmTimedMessageSent = "114:",
        company = "201:",
        privateIndex = "5001:",
        temp = "3000:",
        companyUser = "10010:"
}

public enum DPAGBackupMode: Int {
    case fullBackup,
        miniBackup,
        miniBackupTempDevice
}

public extension String {
    func hasPrefix(_ pre: DPAGGuidPrefix) -> Bool {
        self.hasPrefix(pre.rawValue)
    }
}

public enum DPAGCompanyAdressbookWorkerSyncInfoState: String {
    case DownloadServerChecksums,
        LoadServerChecksums,
        LoadClientChecksums,
        LoadCompanyEntries,
        LoadContactsToUpdate,
        DownloadContactsToUpdate,
        SaveContactsToUpdate,
        CheckCompanyContactsToDelete,
        LoadContactsToCreate
}

public enum DPAGUpdateKnownContactsWorkerSyncInfoState: String {
    case LoadAndHashPhoneNumbersAndEmailAdresses,
        DownloadKnownAccountInfosPhoneNumber,
        SaveKnownAccountInfosPhoneNumber,
        DownloadMissingAccountInfosPhoneNumber,
        SaveMissingAccountInfosPhoneNumber,
        DownloadKnownAccountInfosEmailAddress,
        SaveKnownAccountInfosEmailAddress,
        DownloadMissingAccountInfosEmailAddress,
        SaveMissingKnownAccountInfosEmailAddress
}

public enum DPAGContactsSelectionType: Int {
    case privat,
        company,
        domain
}

public enum DPAGChatRingtones: String {
    case SIMSme = "Ukulele.aiff",
        Astral = "Astral.aiff",
        Balaphonia = "Balaphonia.aiff",
        Blessing = "Blissful_01.aiff",
        Blissful = "Blissful_02.aiff",
        Chilling = "Chilling.aiff",
        Droplets = "Droplets.aiff",
        Glassian = "Glassian.aiff",
        Glockenspiel = "Glockenspiel.aiff",
        Kalimba = "Kalimba.aiff",
        Marimba = "Marimba.aiff",
        Nylon = "Nylon.aiff",
        Piano = "Piano.aiff",
        Strings = "Strings.aiff"
}
