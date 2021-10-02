//
//  DPAGMDMPreferences.swift
//  SIMSme
//
//  Created by Florian Plewka on 11.04.16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation

public class DPAGMDMPreferences: DPAGPreferences {
    // The Managed app configuration dictionary pushed down from an MDM server are stored in this key.
    private static let kMdmConfigurationKey = "com.apple.configuration.managed"

    private static let kMdmCompanyConfigurationKey = "de.dpag.simsme.business.configuration.managed_raw"

    private var _canSendMedia: NSNumber?
    private var _isChatExportAllowed: NSNumber?
    private var _canUseSimplePin: NSNumber?
    private var _disableTouchId: Bool?
    private var _canExportMedia: NSNumber?
    private var _autoSaveMedia: NSNumber?
    private var _canDisablePasswordLogin: NSNumber?
    private var _passwordTries: NSNumber?
    private var _lockApplicationDelay: NSNumber?
    private var _passwordMinLength: NSNumber?
    private var _passwordMinSpecialChar: NSNumber?
    private var _passwordMinDigit: NSNumber?
    private var _passwordMinLowercase: NSNumber?
    private var _passwordMinUppercase: NSNumber?
    private var _passwordMinClasses: NSNumber?
    private var _passwordMaxDuration: NSNumber?
    private var _passwordReuseEntries: NSNumber?
    private var _lockApplicationImmediately: Bool
    private var isReadMDMValuesCalling: Bool = false

    private var _disableSendVCard: Bool?
    private var _disableCamera: Bool?
    private var _disableMicrophone: Bool?
    private var _disableLocation: Bool?
    private var _disableCopyPaste: Bool?
    private var _disableSimsmeRecovery: Bool?
    private var _disableAllRecovery: Bool?
    private var _disablePushPreview: Bool?
    private var _disableBackup: Bool?

    override init() {
        _lockApplicationImmediately = false

        super.init()
    }

    override public func setDefaults() {
        super.setDefaults()

        UserDefaults.standard.removeObject(forKey: DPAGMDMPreferences.kMdmCompanyConfigurationKey)

        self[.kCompanyLogo] = nil
        self[.kCompanyLogoChecksum] = nil

        self[.kCompanyColorMain] = nil
        self[.kCompanyColorAction] = nil
        self[.kCompanyColorMainContrast] = nil
        self[.kCompanyColorActionContrast] = nil

        self[.kCompanyColorSecLevelLow] = nil
        self[.kCompanyColorSecLevelMed] = nil
        self[.kCompanyColorSecLevelHigh] = nil
        self[.kCompanyColorSecLevelLowContrast] = nil
        self[.kCompanyColorSecLevelMedContrast] = nil
        self[.kCompanyColorSecLevelHighContrast] = nil

        self[.kLicenseValidDate] = nil
        self[.kTestLicenseDaysLeft] = nil

        self.companyColor = DPAGCompanyLayout()
    }

    override public var lockApplicationImmediately: Bool {
        _lockApplicationImmediately ? true : super.lockApplicationImmediately
    }

    public func resetLockApplicationImmediately() {
        _lockApplicationImmediately = false
    }

    public func canSetApplicationLockDelay() -> Bool {
        !(_lockApplicationDelay != nil)
    }

    override public var applicationLockDelay: DPAGSettingLockDelay {
        get {
            if let lockApplicationDelayTmp = _lockApplicationDelay {
                return DPAGSettingLockDelay(rawValue: lockApplicationDelayTmp.intValue) ?? .zero
            } else {
                return super.applicationLockDelay
            }
        }
        set {
            super.applicationLockDelay = newValue
        }
    }

    public var canSendMedia: Bool {
        _canSendMedia?.boolValue ?? true
    }

    public var canAskForRating: Bool {
        DPAGApplicationFacade.runtimeConfig.canAskForRating
    }

    public var maxDaysChannelMessagesValid: UInt {
        DPAGApplicationFacade.runtimeConfig.maxDaysChannelMessagesValid
    }
 
    public var maxNumChannelMessagesPerChannel: UInt {
        DPAGApplicationFacade.runtimeConfig.maxNumChannelMessagesPerChannel
    }

    public var isChatExportAllowed: Bool {
        _isChatExportAllowed?.boolValue ?? DPAGApplicationFacade.runtimeConfig.isChatExportAllowed
    }

    @objc public var isChannelsAllowed: Bool {
        DPAGApplicationFacade.runtimeConfig.isChannelsAllowed
    }

    public var isCommentingEnabled: Bool {
        DPAGApplicationFacade.runtimeConfig.isCommentingEnabled
    }

    public var isWhiteLabelBuild: Bool {
        DPAGApplicationFacade.runtimeConfig.isWhiteLabelBuild
    }

    public var urlScheme: String? {
        DPAGApplicationFacade.runtimeConfig.urlScheme
    }

    public var urlSchemeOld: String? {
        DPAGApplicationFacade.runtimeConfig.urlSchemeOld
    }

    @objc public var saltClient: String? {
        DPAGApplicationFacade.runtimeConfig.saltClient
    }

    public var mandantIdent: String? {
        DPAGApplicationFacade.runtimeConfig.mandantIdent
    }

    public var mandantLabel: String? {
        DPAGApplicationFacade.runtimeConfig.mandantLabel
    }

    @objc public var isBaMandant: Bool {
        DPAGApplicationFacade.runtimeConfig.isBaMandant
    }

    public var isCompanyAdressBookEnabled: Bool {
        self.isBaMandant
    }

    public var supportMultiDevice: Bool {
        self.isBaMandant || AppConfig.multiDeviceAllowed
    }

    public func apnIdentifierWithBundleIdentifier(_ bundleIdentifier: String, deviceToken: String) -> String {
        DPAGApplicationFacade.runtimeConfig.apnIdentifier(bundleIdentifier: bundleIdentifier, deviceToken: deviceToken)
    }

    public var maxFileSize: UInt64 {
        DPAGApplicationFacade.runtimeConfig.maxFileSize
    }

    public var canUseSimplePin: Bool {
        if let canUseSimplePinTmp: NSNumber = _canUseSimplePin, canUseSimplePinTmp.boolValue == false {
            return false
        }

        if (self.passwordMinLength ?? 0) > 4 || (self.passwordMinDigit ?? 0) > 4 || (self.passwordMinLowercase ?? 0) > 0 || (self.passwordMinUppercase ?? 0) > 0 || (self.passwordMinSpecialChar ?? 0) > 0 {
            return false
        }
        return true
    }

    public var canSetTouchId: Bool {
        if let canSetTouchIdTmp: Bool = _disableTouchId, canSetTouchIdTmp == true {
            return false
        }

        return true
    }

    public var sendVCardDisabled: Bool {
        _disableSendVCard ?? false
    }

    public var sendCameraDisabled: Bool {
        _disableCamera ?? false
    }

    public var sendMicrophoneDisabled: Bool {
        _disableMicrophone ?? false
    }

    public var sendLocationDisabled: Bool {
        _disableLocation ?? false
    }

    public var isCopyPasteDisabled: Bool {
        _disableCopyPaste ?? false
    }

    public var canSetSimsmeRecovery: Bool {
        !(self._disableSimsmeRecovery != nil || self._disableAllRecovery != nil)
    }

    public var isSimsmeRecoveryDisabled: Bool {
        _disableSimsmeRecovery ?? false
    }

    public var isRecoveryDisabled: Bool {
        _disableAllRecovery ?? false
    }

    public var isPushPreviewDisabled: Bool {
        _disablePushPreview ?? false
    }

    @objc public var isBackupDisabled: Bool {
        _disableBackup ?? false
    }

    public var canExportMedia: Bool {
        _canExportMedia?.boolValue ?? true
    }

    public var autoSaveMedia: Bool {
        _autoSaveMedia?.boolValue ?? true
    }

    public var canSetAutoSaveMedia: Bool {
        !(self._autoSaveMedia != nil)
    }

    @objc public var sendNickname: Bool {
        // Auslesen aus den Preferneces

        if let pref = self[DPAGPreferences.PropString.kNotificationNicknameEnabled], pref != DPAGPreferences.kValueNotificationDisabled {
            return true
        }
        return false
    }

    public var canDisablePasswordLogin: Bool {
        _canDisablePasswordLogin?.boolValue ?? true
    }

    public var canSetPasswordRetries: Bool {
        !(self._passwordTries != nil)
    }

    override public func getPasswordRetries() -> DPAGSettingPasswordRetry {
        if let passwordTriesTmp = _passwordTries {
            return DPAGSettingPasswordRetry(rawValue: passwordTriesTmp.intValue) ?? .three
        } else {
            return super.getPasswordRetries()
        }
    }

    public var passwordMinLength: Int? {
        _passwordMinLength?.intValue
    }

    public var passwordMinDigit: Int? {
        _passwordMinDigit?.intValue
    }

    public var passwordMinSpecialChar: Int? {
        _passwordMinSpecialChar?.intValue
    }

    public var passwordMinLowercase: Int? {
        _passwordMinLowercase?.intValue
    }

    public var passwordMinUppercase: Int? {
        _passwordMinUppercase?.intValue
    }

    public var passwordMinClasses: Int? {
        _passwordMinClasses?.intValue
    }

    public var passwordMaxDuration: Int? {
        _passwordMaxDuration?.intValue
    }

    public var passwordSetAt: Date? {
        get {
            self[.kPasswordCurrentDuration]
        }
        set {
            self[.kPasswordCurrentDuration] = newValue
        }
    }

    public func getUsedHashedPasswords() -> [String]? {
        guard let encryptedUsedPwdsData = self[.kPasswordUsedPasswords] else {
            return nil
        }

        guard let decryptedAesKey = self.getPreferencesAesKey() else {
            return nil
        }

        var decryptedUsedPwdsData: Data?

        do {
            decryptedUsedPwdsData = try CryptoHelperDecrypter.decrypt(encryptedString: encryptedUsedPwdsData, withAesKey: decryptedAesKey)
        } catch {
            DPAGLog(error)
        }

        guard let decryptedUsedPwdsDataArchived = decryptedUsedPwdsData else {
            return nil
        }

        guard let decryptedUsedPwds = NSKeyedUnarchiver.unarchiveObject(with: decryptedUsedPwdsDataArchived) as? [String] else {
            return nil
        }

        if let reusePwdsCount = _passwordReuseEntries?.intValue {
            // Pruefen ob die Anzahl noch ueberein stimmt, kann sich ja durch MDM Anpassung geaendert haben
            if reusePwdsCount < decryptedUsedPwds.count {
                let newUsedPwds: ArraySlice<String> = decryptedUsedPwds.suffix(reusePwdsCount)
                let newUsedPwdsArray: [String] = Array(newUsedPwds)

                if !self.setUsedHashedPasswords(newUsedPwdsArray) {
                    return nil
                }

                return newUsedPwdsArray
            }
        }

        return decryptedUsedPwds
    }

    public func setUsedHashedPasswords(_ usedHashedPasswords: [String], accountPublicKey: String? = nil) -> Bool {
        guard let decryptedAesKey: String = self.getPreferencesAesKey(accountPublicKey) else {
            return false
        }

        let decryptedUsedPwdsData = NSKeyedArchiver.archivedData(withRootObject: usedHashedPasswords)

        var encryptedUsedPwdsData: String?

        do {
            encryptedUsedPwdsData = try CryptoHelperEncrypter.encrypt(data: decryptedUsedPwdsData, withAesKey: decryptedAesKey)
        } catch {
            DPAGLog(error)
        }

        if encryptedUsedPwdsData == nil {
            return false
        }

        self[.kPasswordUsedPasswords] = encryptedUsedPwdsData

        return true
    }

    public func savePasswordToUsedPasswords(_ password: String, accountPublicKey: String? = nil) -> Bool {
        if !self.isBaMandant {
            return true
        }

        var usedHashedPasswords: [String] = self.getUsedHashedPasswords() ?? [String]()

        guard let chelper = CryptoHelper.sharedInstance else {
            return false
        }

        guard let hashedPwd = try? chelper.hashPassword(password: password) else {
            return false
        }

        usedHashedPasswords.insert(hashedPwd, at: 0)

        if let reusePwdsCount = _passwordReuseEntries?.intValue {
            // Pruefen ob die Anzahl noch ueberein stimmt
            if reusePwdsCount < usedHashedPasswords.count {
                let newUsedPwds: ArraySlice<String> = usedHashedPasswords.suffix(reusePwdsCount)
                let newUsedPwdsArray: [String] = Array(newUsedPwds)

                if self.setUsedHashedPasswords(newUsedPwdsArray, accountPublicKey: accountPublicKey) {
                    return true
                }
            } else {
                if self.setUsedHashedPasswords(usedHashedPasswords, accountPublicKey: accountPublicKey) {
                    return true
                }
            }
        }

        return false
    }

    public func deleteUsedHashedPasswords() {
        self[.kPasswordUsedPasswords] = nil
    }

    public func getUsedPasswordEntriesCount() -> Int? {
        _passwordReuseEntries?.intValue
    }

    private func getPreferencesAesKey(_ accountPublicKey: String? = nil) -> String? {
        var decryptedAesKey: String?

        guard let chelper = CryptoHelper.sharedInstance else {
            return nil
        }

        do {
            if let encryptedAesKey = self[.kPasswordsAesKey] {
                decryptedAesKey = try chelper.decryptWithPrivateKey(encryptedString: encryptedAesKey)
            } else {
                let decryptedAesKeyNew = try CryptoHelperEncrypter.getNewAesKey()

                let publicKey: String

                if let accountPublicKey = accountPublicKey {
                    publicKey = accountPublicKey
                } else {
                    publicKey = try chelper.getPublicKeyFromPrivateKey()
                }

                let encryptedAesKey: String = try CryptoHelperEncrypter.encrypt(string: decryptedAesKeyNew, withPublicKey: publicKey)

                self[.kPasswordsAesKey] = encryptedAesKey

                decryptedAesKey = decryptedAesKeyNew
            }
        } catch {
            DPAGLog(error)
        }

        return decryptedAesKey
    }

    public func deletePreferencesAesKey() {
        self[.kPasswordsAesKey] = nil
    }

    public func setCompanyConfig(_ encryptedConfig: String, iv: String, companyAesKey: String?) throws -> Bool {
        guard let aesKey = companyAesKey else {
            return false
        }

        let dataStr = try CryptoHelperDecrypter.decryptCompanyEncryptedString(encryptedString: encryptedConfig, iv: iv, aesKey: aesKey)

        guard let data = dataStr.data(using: .utf8) else {
            return false
        }

        guard let mdmCompanyValuesDict = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [AnyHashable: Any], let mdmCompanyValues = mdmCompanyValuesDict["AppConfig"] as? [AnyHashable: Any] else {
            return false
        }

        UserDefaults.standard.set(data, forKey: DPAGMDMPreferences.kMdmCompanyConfigurationKey)
        UserDefaults.standard.synchronize()

        if let userRestrictedIndex = mdmCompanyValues["userRestrictedIndex"] as? String {
            let accountDAO: AccountDAOProtocol = AccountDAO()

            accountDAO.updateCompanyUserRestrictedIndex(userRestrictedIndex: userRestrictedIndex)

            NotificationCenter.default.post(name: DPAGStrings.Notification.Menu.MENU_NEW_REINIT, object: nil)
        }
        return true
    }

    @objc
    public func getRawMdmConfig() -> [String: Any]? {
        if let data = UserDefaults.standard.object(forKey: DPAGMDMPreferences.kMdmCompanyConfigurationKey) as? Data {
            do {
                if let rc = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] {
                    return rc
                }
            } catch {
                DPAGLog(error)
            }
        }
        return nil
    }

    public func readMDMValues() {
        if isReadMDMValuesCalling {
            return
        }

        isReadMDMValuesCalling = true

        let userDefaults = UserDefaults.standard

        if let mdmCompanyValuesRaw = userDefaults.data(forKey: DPAGMDMPreferences.kMdmCompanyConfigurationKey) {
            do {
                if let mdmCompanyValues = try JSONSerialization.jsonObject(with: mdmCompanyValuesRaw, options: JSONSerialization.ReadingOptions.allowFragments) as? [AnyHashable: Any] {
                    if let mdmCompanyValues = mdmCompanyValues["AppConfig"] as? [AnyHashable: Any] {
                        // Resetting Saved values

                        self.companyIndexName = mdmCompanyValues["companyIndexName"] as? String

                        _canSendMedia = nil
                        _isChatExportAllowed = nil
                        _canUseSimplePin = nil
                        _disableTouchId = nil
                        _canExportMedia = nil
                        _autoSaveMedia = nil
                        _canDisablePasswordLogin = nil
                        _passwordTries = nil
                        _lockApplicationDelay = nil
                        _passwordMinLength = nil
                        _passwordMinSpecialChar = nil
                        _passwordMinDigit = nil
                        _passwordMinLowercase = nil
                        _passwordMinUppercase = nil
                        _passwordMinClasses = nil
                        _passwordMaxDuration = nil
                        _passwordReuseEntries = nil
                        _disableSendVCard = nil
                        _disableCamera = nil
                        _disableMicrophone = nil
                        _disableLocation = nil
                        _disableCopyPaste = nil
                        _disableSimsmeRecovery = nil
                        _disableAllRecovery = nil
                        _disablePushPreview = nil

                        var mdmCompanyValuesPrepared: [String: Any] = [:]
                        let numValues: [PropInt] = [.kMdmSimsLockApplicationDelay, .kMdmSimsPasswordTries, .kMdmPasswordMinLength, .kMdmPasswordMinDigit, .kMdmPasswordMinLowercase, .kMdmPasswordMinSpecialChar, .kMdmPasswordMinUppercase, .kMdmPasswordMinClasses, .kMdmPasswordMaxDuration, .kMdmPasswordReuseEntries]

                        for key in numValues {
                            if let _strVal = mdmCompanyValues[key.rawValue] as? String {
                                if let _intVal = Int(_strVal) {
                                    mdmCompanyValuesPrepared[key.rawValue] = NSNumber(value: _intVal)
                                }
                            }
                        }

                        let boolValues: [PropBool] = [.kMdmDisableSendMedia, .kMdmDisableOpenIn, .kMdmDisableExportChat, .kMdmDisableSaveToCameraRoll, .kMdmForceComplexPin, .kMdmDisableNoPwLogin, .kMdmDisableSendVCard, .kMdmDisableCamera, .kMdmDisableMicrophone, .kMdmDisableLocation, .kMdmDisableCopyPaste, .kMdmDisableSimsmeRecovery, .kMdmDisableAllRecovery, .kMdmDisablePushPreview,
                                                      .kMdmDisableTouchId, .kMdmDisableBackup]

                        for key in boolValues {
                            if let _strVal = mdmCompanyValues[key.rawValue] as? String {
                                if _strVal == "true" {
                                    mdmCompanyValuesPrepared[key.rawValue] = true
                                } else if _strVal == "false" {
                                    mdmCompanyValuesPrepared[key.rawValue] = false
                                }
                            }
                        }

                        DPAGLog("Applying MDM Company Settings: %@", mdmCompanyValuesPrepared)

                        self.applyMDMSettings(mdmCompanyValuesPrepared)
                    }
                }
            } catch {
                DPAGLog(error)
            }
        }

        if let mdmValues = userDefaults.dictionary(forKey: DPAGMDMPreferences.kMdmConfigurationKey) {
            DPAGLog("Applying MDM Settings: %@", mdmValues)

            self.applyMDMSettings(mdmValues)
        }

        isReadMDMValuesCalling = false
    }

    private func applyMDMSettings(_ mdmValues: [String: Any]) {
        var lockApp = false

        if let disableSendMediaUD = mdmValues[PropBool.kMdmDisableSendMedia.rawValue] as? Bool {
            _canSendMedia = NSNumber(value: !disableSendMediaUD)
        }

        if let disableOpenInUD = mdmValues[PropBool.kMdmDisableOpenIn.rawValue] as? Bool {
            _canExportMedia = NSNumber(value: !disableOpenInUD)
        }

        if let disableExportChatUD = mdmValues[PropBool.kMdmDisableExportChat.rawValue] as? Bool {
            _isChatExportAllowed = NSNumber(value: !disableExportChatUD)
        }

        if let disableSaveToCamerRollUD = mdmValues[PropBool.kMdmDisableSaveToCameraRoll.rawValue] as? Bool {
            _autoSaveMedia = NSNumber(value: !disableSaveToCamerRollUD)
        }

        if let forceComplexPinUD = mdmValues[PropBool.kMdmForceComplexPin.rawValue] as? Bool {
            if forceComplexPinUD, self.passwordType != .complex {
                lockApp = true
            }
            _canUseSimplePin = NSNumber(value: !forceComplexPinUD)
        }

        if let disableTouchId = mdmValues[PropBool.kMdmDisableTouchId.rawValue] as? Bool {
            _disableTouchId = disableTouchId
        }

        if let disableNoPwLoginUD = mdmValues[PropBool.kMdmDisableNoPwLogin.rawValue] as? Bool {
            let isPwdDisabled = (self.passwordOnStartEnabled == false)

            if let canDisablePasswordLoginTmp = _canDisablePasswordLogin {
                if canDisablePasswordLoginTmp.boolValue != !disableNoPwLoginUD {
                    _canDisablePasswordLogin = NSNumber(value: !disableNoPwLoginUD)
                }
            } else {
                _canDisablePasswordLogin = NSNumber(value: !disableNoPwLoginUD)
            }

            if isPwdDisabled, disableNoPwLoginUD {
                lockApp = true
                self.passwordOnStartEnabled = true
            }
        }

        if let lockApplicationDelayUD = mdmValues[PropInt.kMdmSimsLockApplicationDelay.rawValue] as? NSNumber {
            _lockApplicationDelay = lockApplicationDelayUD
        }

        if let passwordTriesUD = mdmValues[PropInt.kMdmSimsPasswordTries.rawValue] as? NSNumber {
            let currentTriesValue = self.passwordRetriesLeft

            if currentTriesValue > passwordTriesUD.intValue {
                self.passwordRetriesLeft = passwordTriesUD.intValue
            }

            if DPAGApplicationFacade.preferences.deleteData == false {
                DPAGApplicationFacade.preferences.deleteData = true
            }

            _passwordTries = passwordTriesUD
        }

        if let passwordMinLengthUD = mdmValues[PropInt.kMdmPasswordMinLength.rawValue] as? NSNumber {
            let preferencesPasswordMinLength = DPAGApplicationFacade.preferences.preferencesPasswordMinLength ?? 0

            if preferencesPasswordMinLength != passwordMinLengthUD.intValue {
                DPAGApplicationFacade.preferences.preferencesPasswordMinLength = passwordMinLengthUD.intValue
                _passwordMinLength = passwordMinLengthUD
                lockApp = true
            } else {
                _passwordMinLength = passwordMinLengthUD
            }
        }

        if let passwordMinSpecialCharUD = mdmValues[PropInt.kMdmPasswordMinSpecialChar.rawValue] as? NSNumber {
            let preferencesPasswordMinSpecialChar = DPAGApplicationFacade.preferences.preferencesPasswordMinSpecialChar ?? 0

            if preferencesPasswordMinSpecialChar != passwordMinSpecialCharUD.intValue {
                DPAGApplicationFacade.preferences.preferencesPasswordMinSpecialChar = passwordMinSpecialCharUD.intValue
                _passwordMinSpecialChar = passwordMinSpecialCharUD
                lockApp = true
            } else {
                _passwordMinSpecialChar = passwordMinSpecialCharUD
            }
        }

        if let passwordMinDigitUD = mdmValues[PropInt.kMdmPasswordMinDigit.rawValue] as? NSNumber {
            let preferencesPasswordMinDigitTmp = DPAGApplicationFacade.preferences.preferencesPasswordMinDigit ?? 0

            if preferencesPasswordMinDigitTmp != passwordMinDigitUD.intValue {
                DPAGApplicationFacade.preferences.preferencesPasswordMinDigit = passwordMinDigitUD as? Int
                _passwordMinDigit = passwordMinDigitUD
                lockApp = true
            } else {
                _passwordMinDigit = passwordMinDigitUD
            }
        }

        if let passwordMinLowercaseUD = mdmValues[PropInt.kMdmPasswordMinLowercase.rawValue] as? NSNumber {
            let preferencesPasswordMinLowercase = DPAGApplicationFacade.preferences.preferencesPasswordMinLowercase ?? 0

            if preferencesPasswordMinLowercase != passwordMinLowercaseUD.intValue {
                DPAGApplicationFacade.preferences.preferencesPasswordMinLowercase = passwordMinLowercaseUD.intValue
                _passwordMinLowercase = passwordMinLowercaseUD
                lockApp = true
            } else {
                _passwordMinLowercase = passwordMinLowercaseUD
            }
        }

        if let passwordMinUppercaseUD = mdmValues[PropInt.kMdmPasswordMinUppercase.rawValue] as? NSNumber {
            let preferencesPasswordMinUppercase = DPAGApplicationFacade.preferences.preferencesPasswordMinUppercase ?? 0

            if preferencesPasswordMinUppercase != passwordMinUppercaseUD.intValue {
                DPAGApplicationFacade.preferences.preferencesPasswordMinUppercase = passwordMinUppercaseUD.intValue
                _passwordMinUppercase = passwordMinUppercaseUD
                lockApp = true
            } else {
                _passwordMinUppercase = passwordMinUppercaseUD
            }
        }

        if let passwordMinClassesUD = mdmValues[PropInt.kMdmPasswordMinClasses.rawValue] as? NSNumber {
            let preferencesPasswordMinClasses = DPAGApplicationFacade.preferences.preferencesPasswordMinClasses ?? 0

            if preferencesPasswordMinClasses != passwordMinClassesUD.intValue {
                DPAGApplicationFacade.preferences.preferencesPasswordMinClasses = passwordMinClassesUD.intValue
                _passwordMinClasses = passwordMinClassesUD
                lockApp = true
            } else {
                _passwordMinClasses = passwordMinClassesUD
            }
        }

        if let passwordMaxDurationUD = mdmValues[PropInt.kMdmPasswordMaxDuration.rawValue] as? NSNumber {
            if let preferencesPasswordMaxDuration = DPAGApplicationFacade.preferences.preferencesPasswordMaxDuration {
                if preferencesPasswordMaxDuration != passwordMaxDurationUD.intValue {
                    // pruefen ob die duration schon abgelaufen ist
                    if let pwdSetDate = self.passwordSetAt {
                        let pwdExpireDate = pwdSetDate.addingDays(passwordMaxDurationUD.intValue)
                        if pwdExpireDate.isInFuture {
                            lockApp = true
                        }
                    }
                    DPAGApplicationFacade.preferences.preferencesPasswordMaxDuration = passwordMaxDurationUD.intValue
                    _passwordMaxDuration = passwordMaxDurationUD
                }
            } else {
                _passwordMaxDuration = passwordMaxDurationUD
            }
        }

        if let passwordReuseEntriesUD = mdmValues[PropInt.kMdmPasswordReuseEntries.rawValue] as? NSNumber {
            /* if let passwordReuseEntriesTmp: NSNumber = _passwordReuseEntries
             {
             if passwordReuseEntriesTmp.integerValue != passwordReuseEntriesUD.integerValue
             {
             _passwordReuseEntries = passwordReuseEntriesUD
             lockApp = true
             }
             }
             else
             { */
            _passwordReuseEntries = passwordReuseEntriesUD
            // }
        }

        if let lockApplicationDelayUD = mdmValues[PropInt.kMdmSimsLockApplicationDelay.rawValue] as? NSNumber {
            _lockApplicationDelay = lockApplicationDelayUD
        }
        _disableSendVCard = mdmValues[PropBool.kMdmDisableSendVCard.rawValue] as? Bool
        _disableCamera = mdmValues[PropBool.kMdmDisableCamera.rawValue] as? Bool
        _disableMicrophone = mdmValues[PropBool.kMdmDisableMicrophone.rawValue] as? Bool
        _disableLocation = mdmValues[PropBool.kMdmDisableLocation.rawValue] as? Bool
        _disableCopyPaste = mdmValues[PropBool.kMdmDisableCopyPaste.rawValue] as? Bool
        _disableSimsmeRecovery = mdmValues[PropBool.kMdmDisableSimsmeRecovery.rawValue] as? Bool
        _disableAllRecovery = mdmValues[PropBool.kMdmDisableAllRecovery.rawValue] as? Bool
        _disablePushPreview = mdmValues[PropBool.kMdmDisablePushPreview.rawValue] as? Bool
        _disableBackup = mdmValues[PropBool.kMdmDisableBackup.rawValue] as? Bool

        // Durch MDM ausgeschaltet, aber vorher eingeschaltet
        if self.isSimsmeRecoveryDisabled, self.simsmeRecoveryEnabled {
            self.simsmeRecoveryEnabled = false
        }

        if isPushPreviewDisabled {
            DPAGApplicationFacade.preferences.previewPushNotification = false
        }
        if _disableTouchId ?? false, touchIDEnabled {
            DPAGApplicationFacade.preferences.touchIDEnabled = false
        }

        // Durch MDM ausgeschaltet, aber vorher eingeschaltet
        if self.isRecoveryDisabled {
            if self.simsmeRecoveryEnabled {
                self.simsmeRecoveryEnabled = false
            }
            do {
                if try DPAGApplicationFacade.accountManager.hasCompanyRecoveryPasswordFile() {
                    _ = try CryptoHelper.sharedInstance?.deleteBackupPrivateKey(mode: .fullBackup)
                    self[.kSimsmeRecoveryAdmin] = nil
                }
            } catch {
                DPAGLog(error)
            }
        }

        if lockApp {
            _lockApplicationImmediately = true
        }

        self.companyColor = DPAGCompanyLayout()
    }

    override public var automaticMdmRegistrationValues: DPAGAutomaticRegistrationPreferences? {
        let userDefaults = UserDefaults.standard

        if let mdmValues = userDefaults.dictionary(forKey: DPAGMDMPreferences.kMdmConfigurationKey) {
            if let firstName = mdmValues["firstName"] as? String, let lastName = mdmValues["lastName"] as? String, let eMail = mdmValues["emailAddress"] as? String, let loginCode = mdmValues["loginCode"] as? String {
                return DPAGAutomaticRegistrationPreferences(firstName: firstName, lastName: lastName, eMailAddress: eMail.lowercased(), loginCode: loginCode)
            }
        }
        return nil
    }

    lazy var companyColor = DPAGCompanyLayout()

    private var companyColorsSending: DPAGSharedContainerSending.Colors {
        DPAGSharedContainerSending.Colors(companyColorMain: self.companyColorMain?.rgb, companyColorMainContrast: self.companyColorMainContrast?.rgb, companyColorAction: self.companyColorAction?.rgb, companyColorActionContrast: self.companyColorActionContrast?.rgb, companyColorSecLevelHigh: self.companyColorSecLevelHigh?.rgb, companyColorSecLevelHighContrast: self.companyColorSecLevelHighContrast?.rgb, companyColorSecLevelMed: self.companyColorSecLevelMed?.rgb, companyColorSecLevelMedContrast: self.companyColorSecLevelMedContrast?.rgb, companyColorSecLevelLow: self.companyColorSecLevelLow?.rgb, companyColorSecLevelLowContrast: self.companyColorSecLevelLowContrast?.rgb)
    }

    public var companyColorMain: UIColor? {
        self.companyColor.colorMain
    }

    public var companyColorMainContrast: UIColor? {
        self.companyColor.colorMainContrast
    }

    public var companyColorAction: UIColor? {
        self.companyColor.colorAction
    }

    public var companyColorActionContrast: UIColor? {
        self.companyColor.colorActionContrast
    }

    public var companyColorSecLevelHigh: UIColor? {
        self.companyColor.colorSecLevelHigh
    }

    public var companyColorSecLevelHighContrast: UIColor? {
        self.companyColor.colorSecLevelHighContrast
    }

    public var companyColorSecLevelMed: UIColor? {
        self.companyColor.colorSecLevelMed
    }

    public var companyColorSecLevelMedContrast: UIColor? {
        self.companyColor.colorSecLevelMedContrast
    }

    public var companyColorSecLevelLow: UIColor? {
        self.companyColor.colorSecLevelLow
    }

    public var companyColorSecLevelLowContrast: UIColor? {
        self.companyColor.colorSecLevelLowContrast
    }

    public func setCompanyLayout(_ dict: [AnyHashable: Any]) {
        if let colorStr = dict["mainColor"] as? String, let color = UIColor.scanColor(colorStr) {
            self.companyColor.colorMain = color
            self[.kCompanyColorMain] = colorStr
        }
        if let colorStr = dict["mainContrastColor"] as? String, let color = UIColor.scanColor(colorStr) {
            self.companyColor.colorMainContrast = color
            self[.kCompanyColorMainContrast] = colorStr
        }
        if let colorStr = dict["actionColor"] as? String, let color = UIColor.scanColor(colorStr) {
            self.companyColor.colorAction = color
            self[.kCompanyColorAction] = colorStr
        }
        if let colorStr = dict["actionContrastColor"] as? String, let color = UIColor.scanColor(colorStr) {
            self.companyColor.colorActionContrast = color
            self[.kCompanyColorActionContrast] = colorStr
        }
        if let colorStr = dict["mediumColor"] as? String, let color = UIColor.scanColor(colorStr) {
            self.companyColor.colorSecLevelMed = color
            self[.kCompanyColorSecLevelMed] = colorStr
        }
        if let colorStr = dict["mediumContrastColor"] as? String, let color = UIColor.scanColor(colorStr) {
            self.companyColor.colorSecLevelMedContrast = color
            self[.kCompanyColorSecLevelMedContrast] = colorStr
        }
        if let colorStr = dict["highColor"] as? String, let color = UIColor.scanColor(colorStr) {
            self.companyColor.colorSecLevelHigh = color
            self[.kCompanyColorSecLevelHigh] = colorStr
        }
        if let colorStr = dict["highContrastColor"] as? String, let color = UIColor.scanColor(colorStr) {
            self.companyColor.colorSecLevelHighContrast = color
            self[.kCompanyColorSecLevelHighContrast] = colorStr
        }
        if let colorStr = dict["lowColor"] as? String, let color = UIColor.scanColor(colorStr) {
            self.companyColor.colorSecLevelLow = color
            self[.kCompanyColorSecLevelLow] = colorStr
        }
        if let colorStr = dict["lowContrastColor"] as? String, let color = UIColor.scanColor(colorStr) {
            self.companyColor.colorSecLevelLowContrast = color
            self[.kCompanyColorSecLevelLowContrast] = colorStr
        }
    }

    public func companyLogo() -> String? {
        self[.kCompanyLogo]
    }

    public func companyLogoChecksum() -> String? {
        self[.kCompanyLogoChecksum]
    }

    public func setCompanyLogo(_ logo: String, checksum: String) {
        self[.kCompanyLogo] = logo
        self[.kCompanyLogoChecksum] = checksum
    }

    public func removeCompanyLogo() -> Bool {
        let returnValue = (self[.kCompanyLogo] != nil)

        if returnValue {
            self[.kCompanyLogo] = nil
            self[.kCompanyLogoChecksum] = nil
        }

        return returnValue
    }

    public func setLicenseValidDate(_ licenseValidDate: String) {
        self[.kLicenseValidDate] = licenseValidDate
    }

    public func licenseValidDate() -> String? {
        self[.kLicenseValidDate]
    }

    public func setTestLicenseDaysLeft(_ testLicenseDaysLeft: String) {
        self[.kTestLicenseDaysLeft] = testLicenseDaysLeft
        NotificationCenter.default.post(name: DPAGStrings.Notification.Application.TEST_APPLICATION_DAYS_CHANGED, object: nil)
    }

    public func testLicenseDaysLeft() -> String? {
        self[.kTestLicenseDaysLeft]
    }

    public var companyIndexName: String?

    private var mandantenSending: [DPAGSharedContainerSending.Mandant] {
        self.mandantenDict.values.compactMap { DPAGSharedContainerSending.Mandant(mandant: $0) }
    }

    func preferencesSendingExtension() -> DPAGSharedContainerSending.Preferences {
        DPAGSharedContainerSending.Preferences(isBaMandant: self.isBaMandant, isFCDPMandant: false, isWhiteLabelBuild: self.isWhiteLabelBuild, mandantIdent: self.mandantIdent, mandantLabel: self.mandantLabel, saltClient: self.saltClient, companyIndexName: self.companyIndexName, isCompanyManagedState: self.isCompanyManagedState, canSendMedia: self.canSendMedia, sendNickname: self.sendNickname, sharedContainerConfig: self.sharedContainerConfig, imageOptionsForSending: self.imageOptionsForSending, videoOptionsForSending: self.videoOptionsForSending, maxLengthForSentVideos: self.maxLengthForSentVideos, maxFileSize: self.maxFileSize, contactsPrivateCount: self.contactsPrivateCount, contactsCompanyCount: self.contactsCompanyCount, contactsDomainCount: self.contactsDomainCount, contactsPrivateFullTextSearchEnabled: self.contactsPrivateFullTextSearchEnabled, contactsCompanyFullTextSearchEnabled: self.contactsCompanyFullTextSearchEnabled, contactsDomainFullTextSearchEnabled: self.contactsDomainFullTextSearchEnabled, lastRecentlyUsedContactsPrivate: self.lastRecentlyUsedContactsPrivate, lastRecentlyUsedContactsCompany: self.lastRecentlyUsedContactsCompany, lastRecentlyUsedContactsDomain: self.lastRecentlyUsedContactsDomain, mandanten: self.mandantenSending, colors: self.companyColorsSending)
    }

    public func hasPasswordMDMSettings() -> Bool {
        if let pwdMinLength = DPAGApplicationFacade.preferences.passwordMinLength, pwdMinLength > -1 {
            return true
        }

        if let pwdMinDigit = DPAGApplicationFacade.preferences.passwordMinDigit, pwdMinDigit > -1 {
            return true
        }

        if let pwdMinUpperCase = DPAGApplicationFacade.preferences.passwordMinUppercase, pwdMinUpperCase > -1 {
            return true
        }

        if let pwdMinLowercase = DPAGApplicationFacade.preferences.passwordMinLowercase, pwdMinLowercase > -1 {
            return true
        }

        if let pwdMinSpecialChar = DPAGApplicationFacade.preferences.passwordMinSpecialChar, pwdMinSpecialChar > -1 {
            return true
        }

        if let pwdMinClasses = DPAGApplicationFacade.preferences.passwordMinClasses, pwdMinClasses > -1 {
            return true
        }

        return false
    }

    public func verifyPassword(_ paswword: String?, checkSimplePinUsage: Bool) -> DPAGPasswordViewControllerVerifyState {
        if !self.isBaMandant {
            return .PwdOk
        }

        guard let enteredPassword = paswword, enteredPassword.isEmpty == false
        else {
            return .PwdFailsMinLength
        }

        let pwdCount = enteredPassword.count
        var states = DPAGPasswordViewControllerVerifyState(rawValue: 0)

        if checkSimplePinUsage, !self.canUseSimplePin, passwordType != .complex {
            return .PwdFailsNoPin
        }

        if let pwdMinLength = DPAGApplicationFacade.preferences.passwordMinLength {
            if pwdCount < pwdMinLength {
                states.insert(.PwdFailsMinLength)
            }
        }

        var classCount = 0

        if let pwdMinDigit = DPAGApplicationFacade.preferences.passwordMinDigit {
            if pwdMinDigit > -1 {
                if self.hasPasswordCharactersForSet(.decimalDigits, minCharCount: pwdMinDigit, password: enteredPassword) {
                    classCount += 1
                } else {
                    states.insert(.PwdFailsMinDigits)
                }
            }
        }

        if let pwdMinUpperCase = DPAGApplicationFacade.preferences.passwordMinUppercase {
            if pwdMinUpperCase > -1 {
                if self.hasPasswordCharactersForSet(.uppercaseLetters, minCharCount: pwdMinUpperCase, password: enteredPassword) {
                    classCount += 1
                } else {
                    states.insert(.PwdFailsMinUppercase)
                }
            }
        }

        if let pwdMinLowercase = DPAGApplicationFacade.preferences.passwordMinLowercase {
            if pwdMinLowercase > -1 {
                if self.hasPasswordCharactersForSet(.lowercaseLetters, minCharCount: pwdMinLowercase, password: enteredPassword) {
                    classCount += 1
                } else {
                    states.insert(.PwdFailsMinLowercase)
                }
            }
        }

        if let pwdMinSpecialChar = DPAGApplicationFacade.preferences.passwordMinSpecialChar {
            if pwdMinSpecialChar > -1 {
                if self.hasPasswordCharactersForSet(CharacterSet.alphanumerics.inverted, minCharCount: pwdMinSpecialChar, password: enteredPassword) {
                    classCount += 1
                } else {
                    states.insert(.PwdFailsMinSpecialChars)
                }
            }
        }

        if let pwdMinClasses = DPAGApplicationFacade.preferences.passwordMinClasses {
            if pwdMinClasses > -1 {
                if classCount < pwdMinClasses {
                    classCount = 0
                    if self.hasPasswordCharactersForSet(.decimalDigits, minCharCount: 1, password: enteredPassword) {
                        classCount += 1
                    }

                    if self.hasPasswordCharactersForSet(.uppercaseLetters, minCharCount: 1, password: enteredPassword) {
                        classCount += 1
                    }

                    if self.hasPasswordCharactersForSet(.lowercaseLetters, minCharCount: 1, password: enteredPassword) {
                        classCount += 1
                    }

                    if self.hasPasswordCharactersForSet(CharacterSet.alphanumerics.inverted, minCharCount: 1, password: enteredPassword) {
                        classCount += 1
                    }

                    if classCount < pwdMinClasses {
                        states.insert(.PwdFailsMinClasses)
                    }
                }
            }
        }

        if states.rawValue == 0 {
            states.insert(.PwdOk)
        }

        return states
    }

    private func hasPasswordCharactersForSet(_ charSet: CharacterSet, minCharCount: Int, password: String) -> Bool {
        if minCharCount < 1 {
            return true
        }

        let pwdWithoutCharSet = password.components(separatedBy: charSet).joined()

        if password.count - pwdWithoutCharSet.count < minCharCount {
            return false
        }

        return true
    }

    public func storePasswordType(_ passwordType: DPAGPasswordType, password: String) throws {
        self.passwordType = passwordType
        _ = self.savePasswordToUsedPasswords(password)

        let crypto = CryptoHelper.sharedInstance

        try crypto?.encryptPrivateKey(password: password)

        self.passwordSetAt = Date()
        try self.updateRecoveryBlobs()
        self.hasSystemGeneratedPassword = false
    }

    public func createSimsmeRecoveryInfos() {
        if self.simsmePublicKey == nil {
            self.performBlockInBackground {
                DPAGApplicationFacade.server.getSimsmeRecoveryPublicKey { responseObject, _, errorMessage in

                    if errorMessage == nil, let rc = (responseObject as? [String]), let publicKey = rc.first {
                        self.simsmePublicKey = publicKey
                        self.simsmeRecoveryEnabled = true
                    }
                }
            }
        } else {
            self.simsmeRecoveryEnabled = true
        }
    }
}

struct DPAGCompanyLayout {
    var colorMain: UIColor?
    var colorMainContrast: UIColor?
    var colorAction: UIColor?
    var colorActionContrast: UIColor?

    var colorSecLevelHigh: UIColor?
    var colorSecLevelHighContrast: UIColor?
    var colorSecLevelMed: UIColor?
    var colorSecLevelMedContrast: UIColor?
    var colorSecLevelLow: UIColor?
    var colorSecLevelLowContrast: UIColor?

    init() {
        if let colorStr = DPAGApplicationFacade.preferences[.kCompanyColorMain], let color = UIColor.scanColor(colorStr) {
            self.colorMain = color
        }
        if let colorStr = DPAGApplicationFacade.preferences[.kCompanyColorMainContrast], let color = UIColor.scanColor(colorStr) {
            self.colorMainContrast = color
        }
        if let colorStr = DPAGApplicationFacade.preferences[.kCompanyColorAction], let color = UIColor.scanColor(colorStr) {
            self.colorAction = color
        }
        if let colorStr = DPAGApplicationFacade.preferences[.kCompanyColorActionContrast], let color = UIColor.scanColor(colorStr) {
            self.colorActionContrast = color
        }

        if let colorStr = DPAGApplicationFacade.preferences[.kCompanyColorSecLevelHigh], let color = UIColor.scanColor(colorStr) {
            self.colorSecLevelHigh = color
        }
        if let colorStr = DPAGApplicationFacade.preferences[.kCompanyColorSecLevelHighContrast], let color = UIColor.scanColor(colorStr) {
            self.colorSecLevelHighContrast = color
        }
        if let colorStr = DPAGApplicationFacade.preferences[.kCompanyColorSecLevelMed], let color = UIColor.scanColor(colorStr) {
            self.colorSecLevelMed = color
        }
        if let colorStr = DPAGApplicationFacade.preferences[.kCompanyColorSecLevelMedContrast], let color = UIColor.scanColor(colorStr) {
            self.colorSecLevelMedContrast = color
        }
        if let colorStr = DPAGApplicationFacade.preferences[.kCompanyColorSecLevelLow], let color = UIColor.scanColor(colorStr) {
            self.colorSecLevelLow = color
        }
        if let colorStr = DPAGApplicationFacade.preferences[.kCompanyColorSecLevelLowContrast], let color = UIColor.scanColor(colorStr) {
            self.colorSecLevelLowContrast = color
        }
    }
}
