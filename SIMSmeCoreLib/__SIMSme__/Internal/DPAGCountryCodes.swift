//
//  DPAGCountryCodes.swift
//  SIMSme
//
//  Created by RBU on 12/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreTelephony
import UIKit

public class DPAGCountry: NSObject {
    public fileprivate(set) var name: String?
    public fileprivate(set) var iso: String?
    public fileprivate(set) var code: String?

    override init() {
        super.init()
    }

    init(JSONDictionary dic: [String: Any]) {
        super.init()
        self.parseJSONDictionary(dic)
    }

    fileprivate func parseJSONDictionary(_ dic: [String: Any]) {
        var countryName: String?

        if let iso = dic["iso"] as? String {
            self.iso = iso
            let devicePreferredlanguage = Locale.preferredLanguages.first
            let appCurrentlanguage = Bundle.main.preferredLocalizations.first ?? "de"
            if devicePreferredlanguage != appCurrentlanguage {
                countryName = Locale(identifier: appCurrentlanguage).localizedString(forRegionCode: iso)
            } else {
                countryName = Locale.current.localizedString(forRegionCode: iso)
            }
            self.name = countryName
        }
        self.code = dic["code"] as? String
    }
}

public class DPAGCountryCodes: NSObject {
    @objc public static let sharedInstance = DPAGCountryCodes()

    public var countries: [DPAGCountry] = []
    var countryCodes: [String] = []
    var cachedPhoneNumbers: [String: String] = [:]
    var mobileCountryCode: String?

    override init() {
        super.init()
        if let path = Bundle(for: DPAGCountryCodes.self).url(forResource: "countries", withExtension: "json"), let json = try? Data(contentsOf: path) {
            do {
                if let dict = try JSONSerialization.jsonObject(with: json, options: []) as? [String: Any] {
                    self.parseJSONDictionary(dict)
                }
            } catch {
                DPAGLog(error)
            }
        }
        let carrier = CTCarrier()
        self.mobileCountryCode = carrier.mobileCountryCode
    }

    fileprivate func parseJSONDictionary(_ dic: [String: Any]) {
        if let countries = dic["countries"] as? [[String: Any]] {
            var array = [DPAGCountry]()
            var arrayCodes = [String]()
            switch AppConfig.buildConfigurationMode {
                case .RELEASE:
                    break
                case .ADHOC, .BETA, .DEBUG, .TEST:
                    let dummy = DPAGCountry()
                    dummy.name = "- Test -"
                    dummy.code = "+999"
                    array.append(dummy)
                    arrayCodes.append("+999")
            }

            for itemDic in countries {
                let item = DPAGCountry(JSONDictionary: itemDic)
                array.append(item)
                if let itemCode = item.code, arrayCodes.contains(itemCode) == false {
                    arrayCodes.append(itemCode)
                }
            }
            self.countryCodes = arrayCodes
            self.countries = array
        }
    }

    public func indexForIso(_ iso: String?) -> Int {
        if let retVal = self.countries.firstIndex(where: { (country) -> Bool in
            country.iso == iso
        }) {
            return retVal
        } else {
            return self.countries.firstIndex { (country) -> Bool in
                country.iso == "DE"
            } ?? -1
        }
    }

    public func indexForCode(_ code: String?) -> Int {
        if let retVal = self.countries.firstIndex(where: { (country) -> Bool in
            country.code == code
        }) {
            return retVal
        } else {
            return self.countries.firstIndex { (country) -> Bool in
                country.code == "+49"
            } ?? -1
        }
    }

    fileprivate func removeLeadingZeroes(_ input: String) -> String {
        let nonzeroNumberCharacterSet = CharacterSet(charactersIn: "123456789")
        if let idx = input.rangeOfCharacter(from: nonzeroNumberCharacterSet) {
            return String(input[idx.lowerBound...])
        }
        return ""
    }

    @objc
    public func normalizePhoneNumber(_ phone: String, countryCodeAccount: String?, useCountryCode countryCode: String? = nil) -> String {
        var phoneNormCard: String?
        
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        if let phoneNormCached = self.cachedPhoneNumbers[phone], phoneNormCached.hasPrefix(countryCode ?? "") {
            phoneNormCard = phoneNormCached
        }
        if let pnc = phoneNormCard {
            return pnc
        }
        var phoneNorm = phone.stripUnrecognizedPhoneNumberCharacters()
        if phoneNorm.hasPrefix("00") {
            phoneNorm = String(format: "+%@", self.removeLeadingZeroes(phoneNorm))
        }
        if phoneNorm.hasPrefix("+") {
            if let countryCodeNew = self.countryCodeByPhone(phoneNorm), let range = phoneNorm.range(of: countryCodeNew) {
                let phonePre = String(phoneNorm[range.upperBound...])
                let phoneCheck = self.removeLeadingZeroes(phonePre)
                phoneNorm = self.addCountryCode(countryCodeNew, toPhone: phoneCheck, countryCodeAccount: countryCodeAccount)
            } else if let range = phoneNorm.range(of: "+") {
                let phonePre = String(phoneNorm[range.upperBound...])
                let phoneCheck = self.removeLeadingZeroes(phonePre)
                phoneNorm = self.addCountryCode(countryCode, toPhone: phoneCheck, countryCodeAccount: countryCodeAccount)
            }
        } else {
            phoneNorm = self.addCountryCode(countryCode, toPhone: self.removeLeadingZeroes(phoneNorm), countryCodeAccount: countryCodeAccount)
        }
        self.cachedPhoneNumbers[phone] = phoneNorm
        return phoneNorm
    }

    public func countryCodeByPhone(_ phone: String?) -> String? {
        guard let phone = phone else { return nil }
        for countryCode in self.countryCodes {
            if phone.hasPrefix(countryCode) {
                return countryCode
            }
        }
        // back door n-s-a :-)
        if phone.hasPrefix("+999") {
            return "+999"
        }
        return nil
    }

    fileprivate func addCountryCode(_ countryCode: String?, toPhone phone: String, countryCodeAccount: String?) -> String {
        if let countryCode = countryCode {
            return countryCode + phone
        } else if let countryCodeAccount = countryCodeAccount {
            return countryCodeAccount + phone
        } else if let mobileCountryCode = self.mobileCountryCode {
            return mobileCountryCode + phone
        }

        return phone
    }
}
